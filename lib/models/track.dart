/// Ponto geográfico — lat/lng em graus decimais.
/// Usado em vez de LatLng do google_maps_flutter para manter o modelo
/// sem dependência de plataforma (testável em unit tests puros).
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Setor da pista — intervalo contínuo do centerline em metros.
/// Nunca armazena polylines ou coordenadas brutas.
class Sector {
  final String id;
  final double dStart; // metros acumulados no centerline
  final double dEnd; // metros acumulados no centerline
  final int colorValue; // Color.value serializado

  const Sector({
    required this.id,
    required this.dStart,
    required this.dEnd,
    required this.colorValue,
  });
}

/// Linha de largada/chegada — ponto único no centerline.
class StartFinishLine {
  final double d; // metros acumulados

  const StartFinishLine({required this.d});
}

class Track {
  final String id;
  final String name;
  final DateTime? lastSession;
  final List<GeoPoint> centerline;
  final StartFinishLine? startFinishLine;
  final List<Sector> sectors;

  const Track({
    required this.id,
    required this.name,
    this.lastSession,
    this.centerline = const [],
    this.startFinishLine,
    this.sectors = const [],
  });
}
