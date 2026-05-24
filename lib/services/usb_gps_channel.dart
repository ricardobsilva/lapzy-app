import 'package:flutter/services.dart';

/// Wrapper dos canais nativos para comunicação com GPS USB-C.
///
/// O lado nativo (Kotlin) em [LapzyGpsChannels] é a contraparte obrigatória.
/// Em testes, injete [UsbGpsDetector] com factory simulada.
class UsbGpsChannel {
  static const _method = MethodChannel('lapzy/usb');
  static const _data = EventChannel('lapzy/usb_data');
  static const _status = EventChannel('lapzy/usb_status');
  static const _diag = EventChannel('lapzy/usb_diag');

  /// Retorna as informações do dispositivo USB GPS atualmente conectado,
  /// ou `null` se nenhum cabo estiver plugado.
  Future<UsbDeviceInfo?> getConnectedDevice() async {
    try {
      final raw = await _method.invokeMapMethod<String, Object?>('getConnectedDevice');
      if (raw == null) return null;
      final name = raw['name'] as String?;
      if (name == null) return null;
      return UsbDeviceInfo(name: name);
    } catch (_) {
      return null;
    }
  }

  /// Stream de linhas NMEA brutas do dispositivo USB conectado.
  ///
  /// O Kotlin abre a porta USB CDC-ACM, lê bytes e emite cada linha completa.
  /// O stream fecha quando o cabo é desplugado.
  Stream<String> nmeaLines() {
    return _data.receiveBroadcastStream().map((e) => e.toString());
  }

  /// Stream de eventos de conexão/desconexão de dispositivo USB.
  ///
  /// Emite [UsbStatusEvent] quando um cabo é plugado ou desplugado.
  Stream<UsbStatusEvent> statusStream() {
    return _status.receiveBroadcastStream().map((raw) {
      final m = Map<String, Object?>.from(raw as Map);
      return UsbStatusEvent(
        attached: (m['event'] as String?) == 'attached',
        deviceName: m['name'] as String?,
      );
    });
  }

  /// Encerra a conexão USB ativa.
  Future<void> disconnect() async {
    try {
      await _method.invokeMethod<void>('disconnect');
    } catch (_) {}
  }

  /// Stream de diagnóstico serial USB — emite estado do thread de leitura,
  /// contagem de bytes e informações do endpoint.
  Stream<UsbSerialDiag> diagStream() {
    return _diag.receiveBroadcastStream().map((raw) {
      final m = Map<String, Object?>.from(raw as Map);
      return UsbSerialDiag(
        state: (m['state'] as String?) ?? 'idle',
        bytesTotal: (m['bytesTotal'] as int?) ?? 0,
        bytesPerSec: (m['bytesPerSec'] as double?) ?? 0.0,
        threadAlive: (m['threadAlive'] as bool?) ?? false,
        baudRate: (m['baudRate'] as int?) ?? 9600,
        endpoint: (m['endpoint'] as String?) ?? '—',
        lastError: m['lastError'] as String?,
      );
    });
  }

  /// Altera o baud rate do receptor USB em tempo real.
  Future<void> setBaudRate(int baud) async {
    try {
      await _method.invokeMethod<void>('setBaudRate', {'baud': baud});
    } catch (_) {}
  }
}

class UsbSerialDiag {
  final String state;
  final int bytesTotal;
  final double bytesPerSec;
  final bool threadAlive;
  final int baudRate;
  final String endpoint;
  final String? lastError;

  const UsbSerialDiag({
    required this.state,
    required this.bytesTotal,
    required this.bytesPerSec,
    required this.threadAlive,
    required this.baudRate,
    required this.endpoint,
    this.lastError,
  });
}

class UsbDeviceInfo {
  final String name;

  const UsbDeviceInfo({required this.name});
}

class UsbStatusEvent {
  final bool attached;
  final String? deviceName;

  const UsbStatusEvent({required this.attached, this.deviceName});
}
