import 'dart:math' as math;
import '../models/track.dart';

/// Algoritmos de geometria para pistas de kart.
///
/// Todos os métodos são estáticos e puros — sem estado, sem Flutter.
class TrackGeometry {
  TrackGeometry._();

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
}
