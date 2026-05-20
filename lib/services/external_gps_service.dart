import 'package:geolocator/geolocator.dart';
import 'gps_source.dart';

/// Fonte GPS externa — dispositivo dedicado conectado via Bluetooth ou USB-C.
///
/// Regra fundamental: nenhuma otimização ou correção é aplicada aos dados.
/// O dispositivo externo é tratado como fonte de verdade — seus valores de
/// velocidade, posição e timestamp são repassados exatamente como chegam.
///
/// Esta classe e [InternalGpsService] são completamente independentes —
/// podem ser instanciadas e testadas em isolamento, sem dependência mútua.
class ExternalGpsService implements GpsSource {
  final GpsSourceInfo _info;

  /// Stream bruta do dispositivo externo — injetável para testes.
  ///
  /// Em produção, esta fábrica deve prover o parser NMEA via BT/USB-C.
  /// Em v1, nenhum parser está implementado — a stream padrão é vazia.
  final Stream<Position> Function()? streamFactory;

  const ExternalGpsService({
    required GpsSourceInfo info,
    this.streamFactory,
  }) : _info = info;

  @override
  GpsSourceInfo get info => _info;

  /// Repassa posições do dispositivo externo exatamente como chegam —
  /// sem suavização, sem correção de drift, sem interpolação adicional.
  @override
  Stream<Position> get positionStream {
    if (streamFactory != null) return streamFactory!();
    // Stub de produção: stream vazia até o parser BT/USB-C ser implementado.
    return const Stream.empty();
  }
}
