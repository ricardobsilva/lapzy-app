import 'dart:math' as math;
import '../models/track.dart';

// ── TIPO AUXILIAR ─────────────────────────────────────────────────────────────

/// Vetor 2D para cálculos geométricos (pixels ou metros projetados).
class Vec2 {
  final double x, y;

  const Vec2(this.x, this.y);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);

  double get length => math.sqrt(x * x + y * y);

  Vec2 get normalized {
    final l = length;
    return l < 1e-9 ? const Vec2(0, 0) : Vec2(x / l, y / l);
  }

  /// Perpendicular (rotação 90° anti-horário).
  Vec2 get perp => Vec2(-y, x);

  double dot(Vec2 o) => x * o.x + y * o.y;

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}

// ── TIPOS DE RESULTADO ────────────────────────────────────────────────────────

typedef SnapResult = ({double d, double distFromPath});
typedef SectorInterval = ({double dStart, double dEnd});

// ── SERVIÇO ───────────────────────────────────────────────────────────────────

/// Algoritmos de geometria para pistas de kart.
///
/// Todos os métodos são estáticos e puros — sem estado, sem Flutter.
/// Referência: docs/lapzy_criacao_pista_setores.md
class TrackGeometry {
  TrackGeometry._();

  // ── DISTÂNCIAS ──────────────────────────────────────────────────────────────

  /// Distância Haversine entre dois pontos GPS, em metros.
  static double haversine(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final dLat = (b.lat - a.lat) * math.pi / 180;
    final dLng = (b.lng - a.lng) * math.pi / 180;
    final sinHalfLat = math.sin(dLat / 2);
    final sinHalfLng = math.sin(dLng / 2);
    final h = sinHalfLat * sinHalfLat +
        math.cos(a.lat * math.pi / 180) *
            math.cos(b.lat * math.pi / 180) *
            sinHalfLng * sinHalfLng;
    return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  /// Distâncias acumuladas (em metros) ao longo do path via Haversine.
  /// cumDist[0] == 0, cumDist[i] == soma das distâncias de 0 a i.
  static List<double> buildCumDist(List<GeoPoint> path) {
    if (path.isEmpty) return [];
    final cumDist = <double>[0.0];
    for (var i = 1; i < path.length; i++) {
      cumDist.add(cumDist[i - 1] + haversine(path[i - 1], path[i]));
    }
    return cumDist;
  }

  // ── PROJEÇÃO LOCAL ───────────────────────────────────────────────────────────

  /// Projeta [p] para coordenadas locais em metros relativas a [ref].
  /// Usa projeção equiretangular (válida para distâncias < 5 km).
  static Vec2 projectToLocal(GeoPoint p, GeoPoint ref) {
    const r = 6371000.0;
    final y = (p.lat - ref.lat) * math.pi / 180 * r;
    final x = (p.lng - ref.lng) *
        math.pi /
        180 *
        r *
        math.cos(ref.lat * math.pi / 180);
    return Vec2(x, y);
  }

  // ── SNAP ─────────────────────────────────────────────────────────────────────

  /// Projeta o ponto [P] para o segmento mais próximo de [projPath].
  ///
  /// [projPath] pode estar em pixels (tela) ou metros (local) — desde que
  /// [cumDist] esteja na mesma unidade ou em metros reais.
  /// Retorna a distância acumulada correspondente e a distância ortogonal ao path.
  static SnapResult snapToDist(
    Vec2 P,
    List<Vec2> projPath,
    List<double> cumDist,
  ) {
    double bestDist = double.infinity;
    double bestD = 0;

    for (var i = 0; i < projPath.length - 1; i++) {
      final a = projPath[i];
      final b = projPath[i + 1];
      final ab = b - a;
      final ap = P - a;
      final abDotAb = ab.dot(ab);
      if (abDotAb < 1e-12) continue;
      final t = (ap.dot(ab) / abDotAb).clamp(0.0, 1.0);
      final proj = a + ab * t;
      final dist = (P - proj).length;
      if (dist < bestDist) {
        bestDist = dist;
        bestD = cumDist[i] + t * (cumDist[i + 1] - cumDist[i]);
      }
    }

    return (d: bestD, distFromPath: bestDist);
  }

  // ── SUAVIZAÇÃO ───────────────────────────────────────────────────────────────

  /// Suavização por mediana móvel — robusta a outliers.
  static List<double> smoothByMedian(List<double> dists, {int window = 9}) {
    if (dists.isEmpty) return [];
    final half = window ~/ 2;
    return List.generate(dists.length, (i) {
      final slice = List<double>.from(
        dists.sublist(
          math.max(0, i - half),
          math.min(dists.length, i + half + 1),
        ),
      )..sort();
      return slice[slice.length ~/ 2];
    });
  }

  // ── DIREÇÃO ──────────────────────────────────────────────────────────────────

  /// Detecta se o gesto foi feito no sentido da corrida (crescente).
  /// Ignora deltas de wrap-around (> 40% do circuito).
  static bool isForwardDirection(List<double> dists, double totalLen) {
    int growing = 0, shrinking = 0;
    for (var i = 1; i < dists.length; i++) {
      final delta = dists[i] - dists[i - 1];
      if (delta.abs() < totalLen * 0.4) {
        if (delta > 0) {
          growing++;
        } else {
          shrinking++;
        }
      }
    }
    return growing >= shrinking;
  }

  // ── SETOR ────────────────────────────────────────────────────────────────────

  /// Extrai o intervalo [dStart, dEnd] a partir das distâncias brutas do gesto.
  ///
  /// Retorna null se:
  /// - Menos de 2 amostras
  /// - Comprimento resultante < 20 m
  static SectorInterval? extractSectorInterval(
    List<double> rawDists,
    double totalLen,
  ) {
    if (rawDists.length < 2) return null;

    final smoothed = smoothByMedian(rawDists);
    final forward = isForwardDirection(smoothed, totalLen);

    var dStart = smoothed.first;
    var dEnd = smoothed.last;

    if (!forward) {
      final tmp = dStart;
      dStart = dEnd;
      dEnd = tmp;
    }

    final len = ((dEnd - dStart) + totalLen) % totalLen;
    if (len < 20.0) return null;

    return (dStart: dStart, dEnd: dEnd);
  }

  // ── PONTO NO PATH ────────────────────────────────────────────────────────────

  /// Ponto GPS na distância acumulada [d] ao longo do path.
  static GeoPoint pointAtDist(
    double d,
    List<GeoPoint> path,
    List<double> cumDist,
    double totalLen,
  ) {
    if (path.isEmpty) return const GeoPoint(0, 0);
    if (totalLen <= 0) return path.first;

    d = ((d % totalLen) + totalLen) % totalLen;

    for (var i = 1; i < cumDist.length; i++) {
      if (cumDist[i] >= d) {
        final span = cumDist[i] - cumDist[i - 1];
        final t = span > 0 ? (d - cumDist[i - 1]) / span : 0.0;
        return GeoPoint(
          path[i - 1].lat + t * (path[i].lat - path[i - 1].lat),
          path[i - 1].lng + t * (path[i].lng - path[i - 1].lng),
        );
      }
    }

    return path.last;
  }

  // ── TANGENTE ─────────────────────────────────────────────────────────────────

  /// Tangente normalizada no ponto [d] (lookahead de ±[deltaMeters] m).
  /// Retorna vetor no espaço de projeção local (metros).
  static Vec2 tangentAtDist(
    double d,
    List<GeoPoint> path,
    List<double> cumDist,
    double totalLen, {
    double deltaMeters = 5.0,
  }) {
    final pA = pointAtDist(d - deltaMeters, path, cumDist, totalLen);
    final pB = pointAtDist(d + deltaMeters, path, cumDist, totalLen);
    final ref = GeoPoint((pA.lat + pB.lat) / 2, (pA.lng + pB.lng) / 2);
    final vA = projectToLocal(pA, ref);
    final vB = projectToLocal(pB, ref);
    return (vB - vA).normalized;
  }

  // ── LINHA DE CORTE ───────────────────────────────────────────────────────────

  /// Par de GeoPoints que formam a linha de corte perpendicular em [d].
  ///
  /// A linha tem comprimento total de 2 × ([halfWidthMeters] + 2) metros.
  static (GeoPoint, GeoPoint) cutLinePoints(
    double d,
    List<GeoPoint> path,
    List<double> cumDist,
    double totalLen, {
    double halfWidthMeters = 6.0,
  }) {
    final center = pointAtDist(d, path, cumDist, totalLen);
    final tangent = tangentAtDist(d, path, cumDist, totalLen);
    final normal = tangent.perp; // perpendicular ao sentido da pista

    // Converte offset em metros → graus (lat/lng)
    const r = 6371000.0;
    final dLatDeg = normal.y / r * (180 / math.pi);
    final dLngDeg =
        normal.x / r * (180 / math.pi) / math.cos(center.lat * math.pi / 180);

    final halfW = halfWidthMeters + 2;
    final pA = GeoPoint(
      center.lat + dLatDeg * halfW,
      center.lng + dLngDeg * halfW,
    );
    final pB = GeoPoint(
      center.lat - dLatDeg * halfW,
      center.lng - dLngDeg * halfW,
    );

    return (pA, pB);
  }

  // ── SUBPATH ──────────────────────────────────────────────────────────────────

  /// Lista de GeoPoints ao longo do trecho de [dStart] a [dEnd].
  /// Usado para destacar visualmente o setor selecionado.
  static List<GeoPoint> subpathPoints(
    double dStart,
    double dEnd,
    List<GeoPoint> path,
    List<double> cumDist,
    double totalLen, {
    double stepMeters = 5.0,
  }) {
    if (path.isEmpty || totalLen <= 0) return [];

    final pts = <GeoPoint>[];
    var d = dStart;
    const maxIterations = 20000;
    var iterations = 0;

    while (iterations < maxIterations) {
      pts.add(pointAtDist(d, path, cumDist, totalLen));
      final remaining = ((dEnd - d) + totalLen) % totalLen;
      if (remaining < stepMeters) {
        pts.add(pointAtDist(dEnd, path, cumDist, totalLen));
        break;
      }
      d = (d + stepMeters) % totalLen;
      iterations++;
    }

    return pts;
  }
}
