import 'package:geolocator/geolocator.dart';

import 'external_gps_service.dart';
import 'gps_diagnostics_service.dart';
import 'gps_source.dart';
import 'nmea_parser.dart';
import 'usb_gps_channel.dart';

/// Detecta receptores GPS USB-C e os expõe como [ExternalGpsService].
///
/// Emite o dispositivo conectado quando há um cabo GPS USB plugado,
/// e `null` quando nenhum cabo está conectado. Atualiza automaticamente
/// ao plugar ou desplugar o cabo — sem precisar reiniciar a tela.
///
/// Usa protocolo USB Serial CDC-ACM a 9600 baud (padrão NMEA 0183).
class UsbGpsDetector {
  final UsbGpsChannel _channel;

  UsbGpsDetector({UsbGpsChannel? channel})
      : _channel = channel ?? UsbGpsChannel();

  /// Stream que emite o dispositivo USB detectado, ou `null` quando desconectado.
  ///
  /// Emite um valor imediatamente com o estado atual (null se nada plugado),
  /// depois verifica a cada 2 segundos se o estado mudou.
  ///
  /// Nota: `ACTION_USB_DEVICE_ATTACHED` não é entregue a BroadcastReceivers
  /// dinâmicos no Android — polling é a única forma confiável de detectar
  /// um cabo plugado enquanto o app já está rodando.
  Stream<ExternalGpsService?> watch() async* {
    ExternalGpsService? last;
    try {
      last = await _buildCurrentDevice();
      yield last;
      await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
        final current = await _buildCurrentDevice();
        if (current?.info.name != last?.info.name) {
          last = current;
          yield current;
        }
      }
    } catch (_) {
      yield null;
    }
  }

  Future<ExternalGpsService?> _buildCurrentDevice() async {
    try {
      final info = await _channel.getConnectedDevice();
      if (info == null) return null;
      return _buildService(info.name);
    } catch (_) {
      return null;
    }
  }

  ExternalGpsService _buildService(String name) {
    return ExternalGpsService(
      info: GpsSourceInfo(
        name: name,
        connectionType: GpsConnectionType.usb,
      ),
      streamFactory: () => _streamFromUsb(),
    );
  }

  Stream<Position> _streamFromUsb() async* {
    final diagSub = _channel.diagStream().listen(
      (diag) => GpsDiagnosticsService.instance.onUsbSerialDiag(diag),
    );
    try {
      final lines = _channel.nmeaLines();
      final parser = NmeaParser();
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final now = DateTime.now();
        final result = parser.parseLineWithReason(trimmed);
        GpsDiagnosticsService.instance.onNmeaLine(
          raw: trimmed,
          receivedAt: now,
          parsedPosition: result.position,
          discardReason: result.discardReason,
          gga: result.gga,
          rmcStatus: result.rmcStatus,
        );
        if (result.position != null) yield result.position!;
      }
    } finally {
      await diagSub.cancel();
    }
  }
}
