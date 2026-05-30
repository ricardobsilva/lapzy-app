import 'package:flutter/services.dart';

/// Wrapper do MethodChannel + EventChannel para comunicação com o GPS Bluetooth.
///
/// O lado nativo (Kotlin) em [LapzyGpsChannels] é a contraparte obrigatória.
/// Em testes unitários e de widget, injete [BluetoothGpsScanner] com factory
/// simulada — esta classe nunca precisa ser instanciada em testes.
class BluetoothGpsChannel {
  static const _method = MethodChannel('lapzy/bluetooth');
  static const _data = EventChannel('lapzy/bluetooth_data');

  /// Lista os dispositivos Bluetooth pareados (já emparelhados pelo usuário
  /// nas configurações do Android). Retorna lista vazia se BT estiver
  /// desligado, permissão negada ou erro de plataforma.
  Future<List<BluetoothDeviceInfo>> getPairedDevices() async {
    try {
      final raw = await _method.invokeListMethod<Object?>('getPairedDevices');
      if (raw == null) return [];
      return raw
          .whereType<Map>()
          .map((m) => BluetoothDeviceInfo(
                name: m['name'] as String? ?? 'GPS Bluetooth',
                address: m['address'] as String? ?? '',
              ))
          .where((d) => d.address.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream de linhas NMEA brutas do dispositivo com [address].
  ///
  /// O Kotlin conecta via RFCOMM/SPP, lê bytes e emite cada linha completa.
  /// O stream fecha quando a conexão é perdida — o [GpsSourceManager] detecta
  /// isso e faz fallback automático para o GPS interno.
  Stream<String> nmeaLines(String address) {
    return _data.receiveBroadcastStream(address).map((e) => e.toString());
  }

  /// Encerra a conexão BT ativa. Chamado ao trocar de fonte GPS ou fechar o app.
  Future<void> disconnect() async {
    try {
      await _method.invokeMethod<void>('disconnect');
    } catch (_) {}
  }
}

class BluetoothDeviceInfo {
  final String name;
  final String address;

  const BluetoothDeviceInfo({required this.name, required this.address});
}
