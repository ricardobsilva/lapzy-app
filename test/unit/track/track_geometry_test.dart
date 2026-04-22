import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/services/track_geometry.dart';

void main() {
  group('TrackGeometry', () {
    group('haversine', () {
      group('quando os dois pontos são iguais', () {
        test('retorna 0', () {
          const p = GeoPoint(-23.5, -46.6);

          expect(TrackGeometry.haversine(p, p), closeTo(0.0, 1e-6));
        });
      });

      group('quando os pontos estão separados por 1 grau de latitude', () {
        test('retorna aproximadamente 111 km', () {
          const a = GeoPoint(0.0, 0.0);
          const b = GeoPoint(1.0, 0.0);

          expect(TrackGeometry.haversine(a, b), closeTo(111194.0, 500.0));
        });
      });

      group('simetria', () {
        test('dist(a,b) é igual a dist(b,a)', () {
          const a = GeoPoint(-23.5505, -46.6333);
          const b = GeoPoint(-23.5600, -46.6500);

          expect(
            TrackGeometry.haversine(a, b),
            closeTo(TrackGeometry.haversine(b, a), 1e-6),
          );
        });
      });

      group('para trecho típico de pista de kart (~50 m)', () {
        test('retorna valor entre 30 m e 70 m', () {
          const a = GeoPoint(-23.5505, -46.6333);
          const b = GeoPoint(-23.5509, -46.6333);

          final d = TrackGeometry.haversine(a, b);

          expect(d, greaterThan(30.0));
          expect(d, lessThan(70.0));
        });
      });
    });
  });
}
