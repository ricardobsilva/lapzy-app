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
import android.util.Log
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
 *   - MethodChannel "lapzy/usb": getConnectedDevice, disconnect, setBaudRate
 *   - EventChannel  "lapzy/usb_data": stream de linhas NMEA
 *   - EventChannel  "lapzy/usb_status": eventos de attach/detach
 *   - EventChannel  "lapzy/usb_diag": diagnóstico serial em tempo real
 */
class LapzyGpsChannels(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val TAG = "LAPZY/USB"

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

    // ── USB diagnostic state ──────────────────────────────────────────────────

    @Volatile private var rawBytesTotal: Long = 0
    @Volatile private var rawBytesInWindow: Long = 0
    @Volatile private var windowStartMs: Long = System.currentTimeMillis()
    private var currentBaud: Int = 9600
    private var endpointInfo: String = "—"
    @Volatile private var lastUsbError: String? = null
    private var usbSerialState: String = "idle"
    private var usbDiagSink: EventChannel.EventSink? = null
    private var permissionTimeoutRunnable: Runnable? = null

    // ── USB rate control ──────────────────────────────────────────────────────

    /** Endpoint bulk-OUT da interface USB ativa — usado para enviar comandos UBX. */
    @Volatile private var usbOutEndpoint: UsbEndpoint? = null

    /** Hz configurado via UBX-CFG-RATE. 1 = padrão do receptor. */
    private var configuredHz: Int = 1

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
                    "setBaudRate" -> {
                        val baud = call.argument<Int>("baud") ?: 9600
                        currentBaud = baud
                        Log.d(TAG, "setBaudRate → $baud")
                        result.success(null)
                    }
                    "setRate" -> {
                        val hz = call.argument<Int>("hz") ?: 1
                        sendUbxCfgRate(hz)
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
                }

                override fun onCancel(arguments: Any?) {
                    usbStatusSink = null
                }
            })

        EventChannel(engine.dartExecutor.binaryMessenger, "lapzy/usb_diag")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    usbDiagSink = events
                }

                override fun onCancel(arguments: Any?) {
                    usbDiagSink = null
                }
            })

        registerUsbReceiver()
    }

    private fun getUsbGpsInfo(): Map<String, String>? {
        val manager = context.getSystemService(Context.USB_SERVICE) as? UsbManager ?: return null
        val device = manager.deviceList.values.firstOrNull() ?: return null
        Log.d(TAG, "Dispositivo detectado: '${device.productName}' VID=0x${"%04X".format(device.vendorId)} PID=0x${"%04X".format(device.productId)} interfaces=${device.interfaceCount}")
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            Log.d(TAG, "  intf[$i] class=0x${"%02X".format(intf.interfaceClass)} sub=0x${"%02X".format(intf.interfaceSubclass)} proto=0x${"%02X".format(intf.interfaceProtocol)} endpoints=${intf.endpointCount}")
            for (j in 0 until intf.endpointCount) {
                val ep = intf.getEndpoint(j)
                Log.d(TAG, "    ep[$j] dir=${if (ep.direction == UsbConstants.USB_DIR_IN) "IN" else "OUT"} type=${ep.type} addr=0x${"%02X".format(ep.address)} maxPkt=${ep.maxPacketSize}")
            }
        }
        return mapOf("name" to (device.productName ?: device.manufacturerName ?: "USB GPS"))
    }

    private fun startUsbStream(sink: EventChannel.EventSink?) {
        stopUsb()
        emitDiag("detecting")
        val manager = context.getSystemService(Context.USB_SERVICE) as? UsbManager ?: run {
            Log.e(TAG, "UsbManager indisponível — stream encerrado")
            lastUsbError = "UsbManager indisponível"
            emitDiag("failed_no_manager")
            mainHandler.post { sink?.endOfStream() }
            return
        }
        val device = manager.deviceList.values.firstOrNull() ?: run {
            Log.e(TAG, "Nenhum dispositivo USB — stream encerrado")
            lastUsbError = "nenhum dispositivo USB"
            emitDiag("failed_no_device")
            mainHandler.post { sink?.endOfStream() }
            return
        }

        val hasPermission = manager.hasPermission(device)
        Log.d(TAG, "startUsbStream: device='${device.productName}' VID=0x${"%04X".format(device.vendorId)} hasPermission=$hasPermission")
        emitDiag("device_detected")

        if (!hasPermission) {
            Log.d(TAG, "Sem permissão USB — solicitando ao usuário")
            emitDiag("requesting_permission")
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

        // FLAG_MUTABLE is required: UsbManager calls pi.send(context, 0, intent) to attach
        // EXTRA_PERMISSION_GRANTED to the Intent. With FLAG_IMMUTABLE (Android 12+), the system
        // rejects that send() call silently — the receiver never fires and the app hangs forever.
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        Log.d(TAG, "requestUsbPermission: device='${device.productName}' SDK=${Build.VERSION.SDK_INT} flags=0x${"%08X".format(flags)}")
        val pi = PendingIntent.getBroadcast(context, 0, Intent(action).setPackage(context.packageName), flags)
        Log.d(TAG, "PendingIntent criado: $pi")

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                Log.d(TAG, "BroadcastReceiver.onReceive: action=${intent.action} extras=${intent.extras?.keySet()}")
                permissionTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                permissionTimeoutRunnable = null
                try {
                    context.unregisterReceiver(this)
                } catch (e: Exception) {
                    Log.w(TAG, "unregisterReceiver falhou (já removido?): ${e.message}")
                }

                val deviceFromIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                }
                Log.d(TAG, "Device no intent: '${deviceFromIntent?.productName}' VID=0x${"%04X".format(deviceFromIntent?.vendorId ?: 0)}")
                Log.d(TAG, "Device esperado:  '${device.productName}' VID=0x${"%04X".format(device.vendorId)}")

                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                Log.d(TAG, "EXTRA_PERMISSION_GRANTED=$granted")

                if (!granted) {
                    Log.e(TAG, "Permissão USB NEGADA pelo usuário (ou sistema)")
                    lastUsbError = "permissão negada"
                    emitDiag("failed_permission_denied")
                    mainHandler.post { sink?.endOfStream() }
                    return
                }

                // Double-check: mesmo com granted=true, o device precisa ter permissão agora
                val hasPermissionNow = manager.hasPermission(device)
                Log.d(TAG, "hasPermission após granted: $hasPermissionNow")
                if (!hasPermissionNow) {
                    Log.e(TAG, "granted=true mas manager.hasPermission()=false — device mudou?")
                    lastUsbError = "inconsistência de permissão"
                    emitDiag("failed_permission_denied")
                    mainHandler.post { sink?.endOfStream() }
                    return
                }

                emitDiag("permission_granted")
                openAndStream(manager, device, sink)
            }
        }

        Log.d(TAG, "Registrando BroadcastReceiver para action=$action SDK=${Build.VERSION.SDK_INT}")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
            Log.d(TAG, "Receiver registrado com RECEIVER_NOT_EXPORTED")
        } else {
            context.registerReceiver(receiver, IntentFilter(action))
            Log.d(TAG, "Receiver registrado sem flag de exportação")
        }

        Log.d(TAG, "Chamando manager.requestPermission() — aguardando diálogo do usuário")
        manager.requestPermission(device, pi)
        Log.d(TAG, "requestPermission() retornou — dialog deve estar visível")

        // Timeout: se o usuário não responder em 60s (ou dialog não aparecer), cancela
        permissionTimeoutRunnable = Runnable {
            Log.e(TAG, "TIMEOUT: permissão USB não chegou em 60s — receiver nunca disparou?")
            try { context.unregisterReceiver(receiver) } catch (_: Exception) {}
            lastUsbError = "timeout aguardando permissão (60s)"
            emitDiag("failed_permission_timeout")
            mainHandler.post { sink?.endOfStream() }
        }.also { mainHandler.postDelayed(it, 60_000) }
    }

    private fun openAndStream(
        manager: UsbManager,
        device: UsbDevice,
        sink: EventChannel.EventSink?,
    ) {
        Log.d(TAG, "openAndStream: device='${device.productName}' VID=0x${"%04X".format(device.vendorId)} PID=0x${"%04X".format(device.productId)}")
        emitDiag("opening_port")

        val connection = manager.openDevice(device)
        if (connection == null) {
            Log.e(TAG, "openDevice() retornou null — sem permissão ou driver exclusivo?")
            lastUsbError = "openDevice=null"
            emitDiag("failed_open")
            mainHandler.post { sink?.endOfStream() }
            return
        }
        Log.d(TAG, "openDevice() OK")
        usbConnection = connection
        usbDataSink = sink

        rawBytesTotal = 0
        rawBytesInWindow = 0
        windowStartMs = System.currentTimeMillis()
        lastUsbError = null

        emitDiag("configuring_serial")
        val found = findBulkInEndpoint(device, connection)
        if (found == null) {
            Log.e(TAG, "Nenhum endpoint bulk-IN encontrado em ${device.interfaceCount} interface(s) — stream encerrado")
            lastUsbError = "sem endpoint bulk-IN"
            emitDiag("failed_endpoint")
            connection.close()
            mainHandler.post { sink?.endOfStream() }
            return
        }

        val (endpoint, ifaceIndex) = found
        endpointInfo = "intf=$ifaceIndex addr=0x${"%02X".format(endpoint.address)} maxPkt=${endpoint.maxPacketSize}"
        Log.d(TAG, "Endpoint selecionado: $endpointInfo baud=$currentBaud")

        // Configura 5 Hz por padrão — mínimo útil para kart
        // UBX-CFG-RATE via bulk-OUT (u-blox USB nativo, throughput não é limitado por baud)
        sendUbxCfgRate(5)

        emitDiag("starting_reader")

        usbRunning = true
        usbDataThread = Thread {
            val bufSize = maxOf(endpoint.maxPacketSize, 256)
            val buffer = ByteArray(bufSize)
            val lineBuffer = StringBuilder()
            var consecutiveErrors = 0
            var diagIntervalMs = System.currentTimeMillis()

            Log.d(TAG, "Thread de leitura iniciada — bufSize=$bufSize baud=$currentBaud endpoint=$endpointInfo")
            emitDiag("reading")

            try {
                while (usbRunning) {
                    val n = connection.bulkTransfer(endpoint, buffer, bufSize, 1000)
                    val now = System.currentTimeMillis()

                    if (n > 0) {
                        if (rawBytesTotal == 0L) {
                            val hex = buffer.take(minOf(n, 32)).joinToString(" ") { "%02X".format(it) }
                            val ascii = buffer.take(minOf(n, 32)).map { b ->
                                val c = b.toInt().and(0xFF).toChar()
                                if (c.code in 32..126) c else '.'
                            }.joinToString("")
                            Log.d(TAG, "!!! PRIMEIRO BYTE RECEBIDO !!! n=$n")
                            Log.d(TAG, "  hex: $hex")
                            Log.d(TAG, "  ascii: $ascii")
                        }
                        rawBytesTotal += n
                        rawBytesInWindow += n
                        consecutiveErrors = 0

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
                    } else if (n < 0) {
                        consecutiveErrors++
                        if (consecutiveErrors == 1 || consecutiveErrors % 30 == 0) {
                            Log.w(TAG, "bulkTransfer=$n (erro #$consecutiveErrors) totalBytes=$rawBytesTotal")
                            lastUsbError = "bulkTransfer=$n err#$consecutiveErrors"
                        }
                    }
                    // n == 0: timeout sem dados — normal

                    if (now - diagIntervalMs >= 1000) {
                        val windowMs = now - windowStartMs
                        Log.d(TAG, "DIAG: totalBytes=$rawBytesTotal windowBytes=$rawBytesInWindow windowMs=$windowMs threadAlive=true")
                        emitDiag("reading")
                        diagIntervalMs = now
                    }
                    if (now - windowStartMs >= 2000) {
                        rawBytesInWindow = 0
                        windowStartMs = now
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Exceção na thread de leitura: ${e::class.simpleName}: ${e.message}")
                lastUsbError = "exception: ${e.message}"
            } finally {
                Log.d(TAG, "Thread encerrada — totalBytes=$rawBytesTotal")
                emitDiag("done")
                mainHandler.post { sink?.endOfStream() }
                connection.close()
                usbConnection = null
            }
        }.also { it.start() }
    }

    private fun findBulkInEndpoint(device: UsbDevice, connection: UsbDeviceConnection): Pair<UsbEndpoint, Int>? {
        data class Candidate(val endpoint: UsbEndpoint, val ifaceIndex: Int, val priority: Int)
        val candidates = mutableListOf<Candidate>()

        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            Log.d(TAG, "Verificando intf[$i] class=0x${"%02X".format(intf.interfaceClass)}")
            for (j in 0 until intf.endpointCount) {
                val ep = intf.getEndpoint(j)
                if (ep.direction == UsbConstants.USB_DIR_IN && ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    val priority = when (intf.interfaceClass) {
                        0x0A -> 10  // CDC Data — melhor opção
                        0xFF -> 5   // Vendor-specific — fallback
                        else -> 1   // Qualquer outra
                    }
                    Log.d(TAG, "  Bulk-IN encontrado em intf[$i] ep[$j] class=0x${"%02X".format(intf.interfaceClass)} priority=$priority")
                    candidates.add(Candidate(ep, i, priority))
                }
            }
        }

        if (candidates.isEmpty()) {
            Log.e(TAG, "Nenhum endpoint bulk-IN em nenhuma das ${device.interfaceCount} interfaces")
            return null
        }

        val best = candidates.maxByOrNull { it.priority }!!
        val intf = device.getInterface(best.ifaceIndex)
        val claimed = connection.claimInterface(intf, true)
        Log.d(TAG, "claimInterface(${best.ifaceIndex}, force=true) → $claimed")
        if (!claimed) {
            Log.e(TAG, "Falhou claimInterface — kernel pode estar segurando a interface")
        }

        // Encontrar endpoint bulk-OUT na mesma interface (necessário para envio de comandos UBX)
        usbOutEndpoint = null
        for (j in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(j)
            if (ep.direction == UsbConstants.USB_DIR_OUT && ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                usbOutEndpoint = ep
                Log.d(TAG, "  Bulk-OUT encontrado em intf[${best.ifaceIndex}] ep[$j] addr=0x${"%02X".format(ep.address)} maxPkt=${ep.maxPacketSize}")
                break
            }
        }
        if (usbOutEndpoint == null) {
            Log.w(TAG, "Nenhum endpoint bulk-OUT — envio de comandos UBX indisponível")
        }

        configureCdcAcm(connection, best.ifaceIndex)
        return Pair(best.endpoint, best.ifaceIndex)
    }

    private fun configureCdcAcm(connection: UsbDeviceConnection, ifaceIndex: Int) {
        val baud = currentBaud
        val lc = ByteArray(7).apply {
            this[0] = (baud and 0xFF).toByte()
            this[1] = ((baud shr 8) and 0xFF).toByte()
            this[2] = ((baud shr 16) and 0xFF).toByte()
            this[3] = ((baud shr 24) and 0xFF).toByte()
            this[4] = 0x00  // 1 stop bit
            this[5] = 0x00  // no parity
            this[6] = 0x08  // 8 data bits
        }
        val r1 = connection.controlTransfer(0x21, 0x20, 0, ifaceIndex, lc, 7, 1000)
        Log.d(TAG, "SET_LINE_CODING ($baud baud 8N1) → resultado=$r1 (>=0=OK, <0=erro)")

        val r2 = connection.controlTransfer(0x21, 0x22, 0x03, ifaceIndex, null, 0, 1000)
        Log.d(TAG, "SET_CONTROL_LINE_STATE (DTR+RTS) → resultado=$r2")
    }

    /**
     * Envia comando UBX-CFG-RATE para configurar o measurement rate do u-blox.
     *
     * O u-blox responde com UBX-ACK-ACK (binário), que o parser ignora por não
     * começar com '$'. Para USB CDC nativo, o throughput é USB full speed
     * (~12 Mbit/s) — o baud rate CDC-ACM é irrelevante e não limita a taxa.
     *
     * Suporte de taxa pelo módulo u-blox M8/M9:
     *   1 Hz  → measRate=1000ms (padrão de fábrica)
     *   5 Hz  → measRate=200ms (recomendado para kart)
     *   10 Hz → measRate=100ms (u-blox M8 suporta)
     *   20 Hz → measRate=50ms (apenas u-blox M9 e superior)
     */
    private fun sendUbxCfgRate(hz: Int) {
        val outEp = usbOutEndpoint
        val conn = usbConnection
        if (outEp == null || conn == null) {
            Log.w(TAG, "sendUbxCfgRate($hz Hz): sem endpoint OUT ou conexão ativa — ignorado")
            return
        }
        val measRateMs = (1000.0 / hz.coerceIn(1, 20)).toInt()
        val payload = byteArrayOf(
            (measRateMs and 0xFF).toByte(),           // measRate LSB
            ((measRateMs shr 8) and 0xFF).toByte(),   // measRate MSB
            0x01, 0x00,                                // navRate = 1 (navigation per measurement)
            0x00, 0x00,                                // timeRef = 0 (UTC)
        )
        val cmd = buildUbx(0x06.toByte(), 0x08.toByte(), payload)
        val n = conn.bulkTransfer(outEp, cmd, cmd.size, 1000)
        configuredHz = hz
        Log.d(TAG, "UBX-CFG-RATE: hz=$hz measRate=${measRateMs}ms cmd=${cmd.size}B → bulkTransfer=$n (>=0=OK)")
        emitDiag(usbSerialState)
    }

    /**
     * Constrói um frame UBX binário com checksum Fletcher.
     *
     * Formato: 0xB5 0x62 [cls] [id] [lenLo] [lenHi] [payload] [CK_A] [CK_B]
     * Checksum calculado sobre: cls + id + lenLo + lenHi + payload
     */
    private fun buildUbx(cls: Byte, id: Byte, payload: ByteArray): ByteArray {
        val lenLo = (payload.size and 0xFF).toByte()
        val lenHi = ((payload.size shr 8) and 0xFF).toByte()
        var ckA = 0
        var ckB = 0
        for (b in listOf(cls, id, lenLo, lenHi) + payload.toList()) {
            ckA = (ckA + (b.toInt() and 0xFF)) and 0xFF
            ckB = (ckB + ckA) and 0xFF
        }
        return byteArrayOf(0xB5.toByte(), 0x62.toByte(), cls, id, lenLo, lenHi) +
            payload +
            byteArrayOf(ckA.toByte(), ckB.toByte())
    }

    private fun emitDiag(state: String) {
        usbSerialState = state
        val windowMs = System.currentTimeMillis() - windowStartMs
        val bps = if (windowMs > 0 && rawBytesInWindow > 0) rawBytesInWindow * 1000.0 / windowMs else 0.0
        val diag = mapOf(
            "state" to state,
            "bytesTotal" to rawBytesTotal,
            "bytesPerSec" to bps,
            "threadAlive" to (usbDataThread?.isAlive == true),
            "baudRate" to currentBaud,
            "endpoint" to endpointInfo,
            "lastError" to (lastUsbError ?: ""),
            "configuredHz" to configuredHz,
        )
        mainHandler.post { usbDiagSink?.success(diag) }
    }

    private fun stopUsb() {
        Log.d(TAG, "stopUsb() — totalBytes=$rawBytesTotal")
        permissionTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        permissionTimeoutRunnable = null
        usbSerialState = "idle"
        usbRunning = false
        usbDataSink?.endOfStream()
        usbDataSink = null
        usbConnection?.close()
        usbConnection = null
        usbDataThread?.interrupt()
        usbDataThread = null
        usbOutEndpoint = null
        configuredHz = 1
        rawBytesTotal = 0
        rawBytesInWindow = 0
        endpointInfo = "—"
        lastUsbError = null
        emitDiag("idle")
    }

    private fun registerUsbReceiver() {
        if (usbReceiver != null) return

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
