import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'gps_source.dart';

/// Fonte GPS interna do celular.
///
/// Usa [AndroidSettings] com [intervalDuration] = 0 para solicitar a maior
/// frequência disponível ao FusedLocationProvider. Sem [intervalDuration],
/// o padrão do Android é 5000ms — o que limitaria o app a 0.2 Hz.
///
/// A frequência real entregue depende do hardware (geralmente 1 Hz no chip
/// GNSS puro; até 5 Hz com fusão por sensores). O app não limita
/// artificialmente — processa cada posição recebida.
class InternalGpsService implements GpsSource {
  static const GpsSourceInfo _kInfo = GpsSourceInfo(
    name: 'GPS interno',
    connectionType: GpsConnectionType.internal,
  );

  /// Fábrica injetável do stream de posição — facilita testes unitários.
  final Stream<Position> Function()? streamFactory;

  const InternalGpsService({this.streamFactory});

  @override
  GpsSourceInfo get info => _kInfo;

  @override
  Stream<Position> get positionStream {
    if (streamFactory != null) return streamFactory!();
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      // Duration.zero → "deliver as fast as the provider can".
      // Sem isso, o FusedLocationProvider usa o padrão de 5000ms (0.2 Hz).
      intervalDuration: Duration.zero,
    );
    debugPrint(
      '[LAPZY/GPS] InternalGpsService — solicitando: '
      'accuracy=best distanceFilter=0 intervalDuration=0ms (máxima frequência)',
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}
