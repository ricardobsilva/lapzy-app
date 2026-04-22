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

/// Linha transversal na pista — largada/chegada ou fronteira de setor.
///
/// Pode ser uma linha reta (apenas [a] e [b]) ou uma linha curva
/// (com [middlePoints] contendo os pontos intermediários do gesto).
///
/// [widthMeters] é a largura de detecção GPS em metros (3–30 m, padrão 6 m).
class TrackLine {
  final GeoPoint a;
  final GeoPoint b;

  /// Pontos intermediários do traçado — vazio para linhas retas.
  final List<GeoPoint> middlePoints;

  /// Largura da zona de detecção GPS em metros.
  final double widthMeters;

  const TrackLine({
    required this.a,
    required this.b,
    this.middlePoints = const [],
    this.widthMeters = 6.0,
  });

  /// Todos os pontos da linha em ordem: [a] + middlePoints + [b].
  List<GeoPoint> get allPoints => [a, ...middlePoints, b];

  /// Centroide geográfico da linha (média de todos os pontos).
  GeoPoint get midpoint {
    final pts = allPoints;
    final lat = pts.map((p) => p.lat).reduce((x, y) => x + y) / pts.length;
    final lng = pts.map((p) => p.lng).reduce((x, y) => x + y) / pts.length;
    return GeoPoint(lat, lng);
  }
}

class Track {
  final String id;
  final String name;
  final DateTime? lastSession;

  /// Linha de largada/chegada — define o início/fim de cada volta.
  final TrackLine? startFinishLine;

  /// Fronteiras de setor em ordem de adição pelo usuário.
  /// N boundaries → N setores (S1 vai de S/C até boundary[0], etc.).
  final List<TrackLine> sectorBoundaries;

  const Track({
    required this.id,
    required this.name,
    this.lastSession,
    this.startFinishLine,
    this.sectorBoundaries = const [],
  });
}
