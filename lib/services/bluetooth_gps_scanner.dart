import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bluetooth_gps_channel.dart';
import 'external_gps_service.dart';
import 'gps_source.dart';
import 'nmea_parser.dart';

/// Escaneia dispositivos Bluetooth pareados e os expõe como [ExternalGpsService].
///
/// Usa o protocolo SPP (Serial Port Profile / RFCOMM) — padrão de todos os
/// receptores GPS Bluetooth dedicados (Garmin GLO, Bad Elf, QStarz, etc.).
///
/// O scan lista apenas dispositivos **já pareados** pelo usuário nas
/// configurações do Android — não faz scan ativo de novos dispositivos.
///
/// A conexão real (RFCOMM) só é estabelecida quando o usuário confirma
/// "USAR ESTE GPS" e o [GpsSourceManager] chama [GpsSource.positionStream].
class BluetoothGpsScanner {
  final BluetoothGpsChannel _channel;

  BluetoothGpsScanner({BluetoothGpsChannel? channel})
      : _channel = channel ?? BluetoothGpsChannel();

  /// Lista os dispositivos BT pareados.
  ///
  /// O stream emite exatamente um evento com a lista completa e fecha.
  /// Em caso de erro (BT desligado, permissão negada), emite lista vazia
  /// silenciosamente.
  Stream<List<ExternalGpsService>> scan() async* {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.bluetoothConnect.request();
        if (!status.isGranted) {
          yield [];
          return;
        }
      }
      final devices = await _channel.getPairedDevices();
      yield devices
          .map(
            (d) => ExternalGpsService(
              info: GpsSourceInfo(
                name: d.name,
                connectionType: GpsConnectionType.bluetooth,
              ),
              streamFactory: () => _streamFromDevice(d.address),
            ),
          )
          .toList();
    } catch (_) {
      yield [];
    }
  }

  Stream<Position> _streamFromDevice(String address) async* {
    final lines = _channel.nmeaLines(address);
    final parser = NmeaParser();
    yield* parser.transformLines(lines);
  }
}
