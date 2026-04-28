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

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory GeoPoint.fromJson(Map<String, dynamic> json) =>
      GeoPoint(json['lat'] as double, json['lng'] as double);
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

  Map<String, dynamic> toJson() => {
        'a': a.toJson(),
        'b': b.toJson(),
        'middlePoints': middlePoints.map((p) => p.toJson()).toList(),
        'widthMeters': widthMeters,
      };

  factory TrackLine.fromJson(Map<String, dynamic> json) => TrackLine(
        a: GeoPoint.fromJson(json['a'] as Map<String, dynamic>),
        b: GeoPoint.fromJson(json['b'] as Map<String, dynamic>),
        middlePoints: (json['middlePoints'] as List<dynamic>)
            .map((p) => GeoPoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        widthMeters: json['widthMeters'] as double,
      );
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

  /// Timestamp de criação — obrigatório para reconciliação de sync futuro.
  final DateTime? createdAt;

  /// Timestamp da última atualização — obrigatório para reconciliação de sync futuro.
  final DateTime? updatedAt;

  const Track({
    required this.id,
    required this.name,
    this.lastSession,
    this.startFinishLine,
    this.sectorBoundaries = const [],
    this.createdAt,
    this.updatedAt,
  });

  Track copyWith({
    String? id,
    String? name,
    DateTime? lastSession,
    TrackLine? startFinishLine,
    List<TrackLine>? sectorBoundaries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Track(
        id: id ?? this.id,
        name: name ?? this.name,
        lastSession: lastSession ?? this.lastSession,
        startFinishLine: startFinishLine ?? this.startFinishLine,
        sectorBoundaries: sectorBoundaries ?? this.sectorBoundaries,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lastSession': lastSession?.toIso8601String(),
        'startFinishLine': startFinishLine?.toJson(),
        'sectorBoundaries':
            sectorBoundaries.map((l) => l.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        name: json['name'] as String,
        lastSession: json['lastSession'] != null
            ? DateTime.parse(json['lastSession'] as String)
            : null,
        startFinishLine: json['startFinishLine'] != null
            ? TrackLine.fromJson(
                json['startFinishLine'] as Map<String, dynamic>)
            : null,
        sectorBoundaries: (json['sectorBoundaries'] as List<dynamic>)
            .map((l) => TrackLine.fromJson(l as Map<String, dynamic>))
            .toList(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
}
