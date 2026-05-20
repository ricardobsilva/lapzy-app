import 'package:geolocator/geolocator.dart';
import 'gps_source.dart';

/// Fonte GPS interna do celular.
///
/// Encapsula toda a lógica de suavização, correção de drift e otimização
/// específicas do GPS interno. Nenhuma dessas regras deve vazar para o
/// [ExternalGpsService].
///
/// Usa [LocationAccuracy.best] e [distanceFilter] = 0 para máxima resolução
/// temporal — essencial para a interpolação de timestamps do [LapDetector].
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
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    );
  }
}
