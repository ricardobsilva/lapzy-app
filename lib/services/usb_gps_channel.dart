import 'package:flutter/services.dart';

/// Wrapper dos canais nativos para comunicação com GPS USB-C.
///
/// O lado nativo (Kotlin) em [LapzyGpsChannels] é a contraparte obrigatória.
/// Em testes, injete [UsbGpsDetector] com factory simulada.
class UsbGpsChannel {
  static const _method = MethodChannel('lapzy/usb');
  static const _data = EventChannel('lapzy/usb_data');
  static const _status = EventChannel('lapzy/usb_status');

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
