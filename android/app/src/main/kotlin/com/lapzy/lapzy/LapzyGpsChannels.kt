package com.lapzy.lapzy

import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.UUID

/**
 * Registra os canais nativos para GPS Bluetooth e USB-C.
 *
 * Canais Bluetooth:
 *   - MethodChannel "lapzy/bluetooth": getPairedDevices, disconnect
 *   - EventChannel  "lapzy/bluetooth_data": stream de linhas NMEA
 *
 * Canais USB:
 *   - MethodChannel "lapzy/usb": getConnectedDevice, disconnect
 *   - EventChannel  "lapzy/usb_data": stream de linhas NMEA
 *   - EventChannel  "lapzy/usb_status": eventos de attach/detach
 */
class LapzyGpsChannels(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    // ── BT state ─────────────────────────────────────────────────────────────

    @Volatile private var btSocket: BluetoothSocket? = null
    @Volatile private var btRunning = false
    private var btThread: Thread? = null

    // ── USB state ─────────────────────────────────────────────────────────────

    @Volatile private var usbRunning = false
    private var usbDataThread: Thread? = null
    private var usbConnection: UsbDeviceConnection? = null

    /** Sink do canal de dados USB — salvo para permitir encerramento imediato no detach. */
    @Volatile private var usbDataSink: EventChannel.EventSink? = null

    private var usbStatusSink: EventChannel.EventSink? = null
    private var usbReceiver: BroadcastReceiver? = null

    // ── setup ─────────────────────────────────────────────────────────────────

    fun setup(engine: FlutterEngine) {
        setupBluetooth(engine)
        setupUsb(engine)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // BLUETOOTH
    // ══════════════════════════════════════════════════════════════════════════

    private fun setupBluetooth(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "lapzy/bluetooth")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPairedDevices" -> {
                        result.success(getBondedDevices())
                    }
                    "disconnect" -> {
                        stopBt()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, "lapzy/bluetooth_data")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val address = arguments as? String ?: return
                    startBtStream(address, events)
                }

                override fun onCancel(arguments: Any?) {
                    stopBt()
                }
            })
    }

    private fun getBondedDevices(): List<Map<String, String>> {
        return try {
            val adapter = BluetoothAdapter.getDefaultAdapter() ?: return emptyList()
            if (!adapter.isEnabled) return emptyList()
            adapter.bondedDevices
                .filter { it.name != null }
                .map { mapOf("name" to it.name, "address" to it.address) }
        } catch (_: SecurityException) {
            emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun startBtStream(address: String, sink: EventChannel.EventSink?) {
        stopBt()
        btRunning = true
        btThread = Thread {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter() ?: return@Thread
                adapter.cancelDiscovery()
                val device = adapter.getRemoteDevice(address)
                btSocket = device.createRfcommSocketToServiceRecord(sppUuid)
                btSocket!!.connect()
                val reader = BufferedReader(InputStreamReader(btSocket!!.inputStream))
                while (btRunning) {
                    val line = reader.readLine() ?: break
                    if (line.isNotBlank()) {
                        mainHandler.post { sink?.success(line) }
                    }
                }
            } catch (_: Exception) {
                // Conexão encerrada — stream fecha, GpsSourceManager faz fallback.
            } finally {
                mainHandler.post { sink?.endOfStream() }
                btSocket?.close()
                btSocket = null
            }
        }.also { it.start() }
    }

    private fun stopBt() {
        btRunning = false
        btSocket?.close()
        btSocket = null
        btThread?.interrupt()
        btThread = null
    }

    // ══════════════════════════════════════════════════════════════════════════
    // USB
    // ══════════════════════════════════════════════════════════════════════════

    private fun setupUsb(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "lapzy/usb")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getConnectedDevice" -> {
                        result.success(getUsbGpsInfo())
                    }
                    "disconnect" -> {
                        stopUsb()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, "lapzy/usb_data")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    startUsbStream(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopUsb()
                }
            })

        EventChannel(engine.dartExecutor.binaryMessenger, "lapzy/usb_status")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    usbStatusSink = events
                    // O receiver já é registrado em setupUsb() — não registra novamente.
                }

                override fun onCancel(arguments: Any?) {
                    usbStatusSink = null
                    // Não cancela o receiver — precisa permanecer ativo para detecção de desconexão.
                }
            })

        // Registra o receiver assim que o app inicia, independente de quem está
        // escutando lapzy/usb_status. Garante que ACTION_USB_DEVICE_DETACHED
        // seja sempre recebido enquanto o app estiver rodando.
        registerUsbReceiver()
    }

    private fun getUsbGpsInfo(): Map<String, String>? {
        val manager = context.getSystemService(Context.USB_SERVICE) as? UsbManager ?: return null
        val device = manager.deviceList.values.firstOrNull() ?: return null
        return mapOf("name" to (device.productName ?: device.manufacturerName ?: "USB GPS"))
    }

    private fun startUsbStream(sink: EventChannel.EventSink?) {
        stopUsb()
        val manager = context.getSystemService(Context.USB_SERVICE) as? UsbManager ?: run {
            mainHandler.post { sink?.endOfStream() }
            return
        }
        val device = manager.deviceList.values.firstOrNull() ?: run {
            // Nenhum dispositivo USB conectado — encerra o stream imediatamente
            // para que o GpsSourceManager faça fallback para o GPS interno.
            mainHandler.post { sink?.endOfStream() }
            return
        }

        if (!manager.hasPermission(device)) {
            requestUsbPermission(manager, device, sink)
            return
        }

        openAndStream(manager, device, sink)
    }

    private fun requestUsbPermission(
        manager: UsbManager,
        device: UsbDevice,
        sink: EventChannel.EventSink?,
    ) {
        val action = "com.lapzy.lapzy.USB_PERMISSION"
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        val pi = PendingIntent.getBroadcast(context, 0, Intent(action), flags)

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                context.unregisterReceiver(this)
                if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                    openAndStream(manager, device, sink)
                } else {
                    mainHandler.post { sink?.endOfStream() }
                }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, IntentFilter(action))
        }
        manager.requestPermission(device, pi)
    }

    private fun openAndStream(
        manager: UsbManager,
        device: UsbDevice,
        sink: EventChannel.EventSink?,
    ) {
        val connection = manager.openDevice(device) ?: run {
            mainHandler.post { sink?.endOfStream() }
            return
        }
        usbConnection = connection
        usbDataSink = sink

        val endpoint = findCdcBulkInEndpoint(device, connection) ?: run {
            connection.close()
            mainHandler.post { sink?.endOfStream() }
            return
        }

        usbRunning = true
        usbDataThread = Thread {
            val buffer = ByteArray(64)
            val lineBuffer = StringBuilder()
            try {
                while (usbRunning) {
                    val n = connection.bulkTransfer(endpoint, buffer, buffer.size, 1000)
                    if (n > 0) {
                        for (i in 0 until n) {
                            val c = buffer[i].toInt().and(0xFF).toChar()
                            if (c == '\n') {
                                val line = lineBuffer.toString().trim()
                                lineBuffer.clear()
                                if (line.isNotEmpty()) {
                                    mainHandler.post { sink?.success(line) }
                                }
                            } else if (c != '\r') {
                                lineBuffer.append(c)
                            }
                        }
                    }
                    // n < 0: erro de transferência ou timeout sem dados — o broadcast
                    // ACTION_USB_DEVICE_DETACHED é a fonte primária de detecção de
                    // desconexão; o loop continua até que stopUsb() seja chamado.
                }
            } catch (_: Exception) {
                // Conexão encerrada.
            } finally {
                mainHandler.post { sink?.endOfStream() }
                connection.close()
                usbConnection = null
            }
        }.also { it.start() }
    }

    /**
     * Encontra o endpoint bulk-IN de um dispositivo CDC-ACM e configura
     * a interface de dados (SET_LINE_CODING 9600 8N1, SET_CONTROL_LINE_STATE).
     *
     * Suporta CDC-ACM (classe 0x0A) — padrão da maioria dos receptores GPS USB.
     */
    private fun findCdcBulkInEndpoint(
        device: UsbDevice,
        connection: UsbDeviceConnection,
    ): UsbEndpoint? {
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            // Classe 0x0A = CDC Data
            if (intf.interfaceClass != 0x0A) continue
            var bulkIn: UsbEndpoint? = null
            for (j in 0 until intf.endpointCount) {
                val ep = intf.getEndpoint(j)
                if (ep.direction == UsbConstants.USB_DIR_IN &&
                    ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK
                ) {
                    bulkIn = ep
                }
            }
            if (bulkIn == null) continue
            connection.claimInterface(intf, true)
            // SET_LINE_CODING: 9600 baud, 1 stop bit, no parity, 8 data bits
            val lc = ByteArray(7).apply {
                this[0] = 0x80.toByte() // 9600 = 0x00002580, little-endian
                this[1] = 0x25.toByte()
                this[2] = 0x00
                this[3] = 0x00
                this[4] = 0x00 // 1 stop bit
                this[5] = 0x00 // no parity
                this[6] = 0x08 // 8 data bits
            }
            connection.controlTransfer(0x21, 0x20, 0, i, lc, 7, 0)
            // SET_CONTROL_LINE_STATE: DTR + RTS
            connection.controlTransfer(0x21, 0x22, 3, i, null, 0, 0)
            return bulkIn
        }
        return null
    }

    private fun stopUsb() {
        usbRunning = false
        // Encerra o stream Dart imediatamente — o GpsSourceManager recebe onDone
        // e faz fallback para o GPS interno sem esperar o thread terminar.
        usbDataSink?.endOfStream()
        usbDataSink = null
        usbConnection?.close()
        usbConnection = null
        usbDataThread?.interrupt()
        usbDataThread = null
    }

    private fun registerUsbReceiver() {
        if (usbReceiver != null) return // Já registrado — evita duplicata.

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                }
                when (intent.action) {
                    UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                        val name = device?.productName ?: device?.manufacturerName ?: "USB GPS"
                        usbStatusSink?.success(mapOf("event" to "attached", "name" to name))
                    }
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                        // Para o stream de dados imediatamente — o GpsSourceManager
                        // recebe onDone e assume o GPS interno sem atraso.
                        stopUsb()
                        usbStatusSink?.success(mapOf("event" to "detached", "name" to null))
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        usbReceiver = receiver
    }

    private fun unregisterUsbReceiver() {
        usbReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: Exception) {}
        }
        usbReceiver = null
    }
}
