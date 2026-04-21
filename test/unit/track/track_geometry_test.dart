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

    group('buildCumDist', () {
      group('quando o path está vazio', () {
        test('retorna lista vazia', () {
          expect(TrackGeometry.buildCumDist([]), isEmpty);
        });
      });

      group('quando o path tem um único ponto', () {
        test('retorna [0.0]', () {
          expect(TrackGeometry.buildCumDist([const GeoPoint(0, 0)]),
              equals([0.0]));
        });
      });

      group('quando o path tem múltiplos pontos', () {
        test('começa em zero', () {
          final path = [
            const GeoPoint(-23.55, -46.63),
            const GeoPoint(-23.56, -46.63),
            const GeoPoint(-23.57, -46.63),
          ];

          expect(TrackGeometry.buildCumDist(path).first, equals(0.0));
        });

        test('é estritamente crescente', () {
          final path = [
            const GeoPoint(-23.55, -46.63),
            const GeoPoint(-23.56, -46.63),
            const GeoPoint(-23.57, -46.63),
          ];

          final cumDist = TrackGeometry.buildCumDist(path);

          for (var i = 1; i < cumDist.length; i++) {
            expect(cumDist[i], greaterThan(cumDist[i - 1]));
          }
        });

        test('tem o mesmo comprimento que o path', () {
          final path =
              List.generate(5, (i) => GeoPoint(-23.55 + i * 0.001, -46.63));

          expect(TrackGeometry.buildCumDist(path).length, equals(5));
        });
      });
    });

    group('projectToLocal', () {
      group('quando o ponto é igual à referência', () {
        test('retorna Vec2(0, 0)', () {
          const ref = GeoPoint(-23.5, -46.6);

          final v = TrackGeometry.projectToLocal(ref, ref);

          expect(v.x, closeTo(0.0, 1e-6));
          expect(v.y, closeTo(0.0, 1e-6));
        });
      });

      group('quando o ponto está ao norte da referência', () {
        test('y é positivo', () {
          const ref = GeoPoint(-23.5, -46.6);
          const north = GeoPoint(-23.4, -46.6);

          expect(TrackGeometry.projectToLocal(north, ref).y, greaterThan(0));
        });
      });

      group('quando o ponto está a leste da referência', () {
        test('x é positivo', () {
          const ref = GeoPoint(-23.5, -46.6);
          const east = GeoPoint(-23.5, -46.5);

          expect(TrackGeometry.projectToLocal(east, ref).x, greaterThan(0));
        });
      });
    });

    group('snapToDist', () {
      group('quando o ponto está exatamente sobre o path', () {
        test('retorna a distância acumulada correta e distância zero ao path', () {
          const projPath = [Vec2(0, 0), Vec2(100, 0), Vec2(200, 0)];
          final cumDist = [0.0, 100.0, 200.0];

          final snap =
              TrackGeometry.snapToDist(const Vec2(50, 0), projPath, cumDist);

          expect(snap.d, closeTo(50.0, 1e-6));
          expect(snap.distFromPath, closeTo(0.0, 1e-6));
        });
      });

      group('quando o ponto está perpendicular ao path', () {
        test('projeta para o ponto mais próximo com distância correta', () {
          const projPath = [Vec2(0, 0), Vec2(200, 0)];
          final cumDist = [0.0, 200.0];

          final snap =
              TrackGeometry.snapToDist(const Vec2(100, 30), projPath, cumDist);

          expect(snap.d, closeTo(100.0, 1e-6));
          expect(snap.distFromPath, closeTo(30.0, 1e-6));
        });
      });

      group('quando o ponto está antes do início do path', () {
        test('clipa em d=0', () {
          const projPath = [Vec2(0, 0), Vec2(100, 0)];
          final cumDist = [0.0, 100.0];

          final snap =
              TrackGeometry.snapToDist(const Vec2(-50, 0), projPath, cumDist);

          expect(snap.d, closeTo(0.0, 1e-6));
        });
      });

      group('quando o ponto está após o fim do path', () {
        test('clipa em d=totalLen do segmento', () {
          const projPath = [Vec2(0, 0), Vec2(100, 0)];
          final cumDist = [0.0, 100.0];

          final snap =
              TrackGeometry.snapToDist(const Vec2(150, 0), projPath, cumDist);

          expect(snap.d, closeTo(100.0, 1e-6));
        });
      });
    });

    group('smoothByMedian', () {
      group('quando a entrada está vazia', () {
        test('retorna lista vazia', () {
          expect(TrackGeometry.smoothByMedian([]), isEmpty);
        });
      });

      group('quando há um único valor', () {
        test('retorna o mesmo valor', () {
          expect(TrackGeometry.smoothByMedian([42.0]), equals([42.0]));
        });
      });

      group('quando há um outlier isolado no meio da sequência', () {
        test('suprime o spike', () {
          final dists = [10.0, 20.0, 30.0, 9999.0, 50.0, 60.0, 70.0];

          final result = TrackGeometry.smoothByMedian(dists, window: 3);

          expect(result[3], lessThan(200.0));
        });
      });

      group('quando a sequência é monotonicamente crescente', () {
        test('mantém o comprimento original', () {
          final dists = List.generate(20, (i) => i * 10.0);

          expect(TrackGeometry.smoothByMedian(dists).length, equals(20));
        });

        test('preserva a tendência crescente', () {
          final dists = List.generate(15, (i) => i * 10.0);

          final result = TrackGeometry.smoothByMedian(dists);

          expect(result.last, greaterThan(result.first));
        });
      });
    });

    group('isForwardDirection', () {
      group('para sequência crescente', () {
        test('retorna true', () {
          final dists = [10.0, 20.0, 30.0, 40.0, 50.0];

          expect(TrackGeometry.isForwardDirection(dists, 1000.0), isTrue);
        });
      });

      group('para sequência decrescente', () {
        test('retorna false', () {
          final dists = [50.0, 40.0, 30.0, 20.0, 10.0];

          expect(TrackGeometry.isForwardDirection(dists, 1000.0), isFalse);
        });
      });

      group('com apenas um elemento', () {
        test('retorna true (growing == shrinking == 0)', () {
          expect(TrackGeometry.isForwardDirection([42.0], 1000.0), isTrue);
        });
      });

      group('quando há salto de wrap-around (> 40% do circuito)', () {
        test('ignora o delta de wrap e decide pela tendência real', () {
          // 50→100 é growing, salto 100→900 é ignorado (>40%), 900→950 é growing
          final dists = [50.0, 100.0, 900.0, 950.0];

          expect(TrackGeometry.isForwardDirection(dists, 1000.0), isTrue);
        });
      });
    });

    group('extractSectorInterval', () {
      group('quando há menos de 2 amostras', () {
        test('retorna null para lista vazia', () {
          expect(TrackGeometry.extractSectorInterval([], 1000.0), isNull);
        });

        test('retorna null para lista com um elemento', () {
          expect(TrackGeometry.extractSectorInterval([50.0], 1000.0), isNull);
        });
      });

      group('quando o comprimento resultante é menor que 20 m', () {
        test('retorna null', () {
          final dists = List.generate(10, (i) => 100.0 + i.toDouble());

          expect(TrackGeometry.extractSectorInterval(dists, 1000.0), isNull);
        });
      });

      group('quando o gesto é crescente e longo o suficiente', () {
        test('retorna intervalo com dStart < dEnd', () {
          final dists = List.generate(20, (i) => 100.0 + i * 5.0);

          final interval =
              TrackGeometry.extractSectorInterval(dists, 1000.0);

          expect(interval, isNotNull);
          expect(interval!.dStart, lessThan(interval.dEnd));
        });
      });

      group('quando o gesto é decrescente (sentido inverso)', () {
        test('inverte dStart e dEnd para que dStart < dEnd', () {
          final dists = List.generate(20, (i) => 300.0 - i * 10.0);

          final interval =
              TrackGeometry.extractSectorInterval(dists, 1000.0);

          expect(interval, isNotNull);
          expect(interval!.dStart, lessThan(interval.dEnd));
        });
      });
    });

    group('pointAtDist', () {
      group('quando d = 0', () {
        test('retorna o primeiro ponto do path', () {
          final path = [
            const GeoPoint(-23.55, -46.63),
            const GeoPoint(-23.56, -46.63),
          ];
          final cumDist = TrackGeometry.buildCumDist(path);

          final p = TrackGeometry.pointAtDist(0, path, cumDist, cumDist.last);

          expect(p.lat, closeTo(path.first.lat, 1e-10));
          expect(p.lng, closeTo(path.first.lng, 1e-10));
        });
      });

      group('quando d = totalLen (wrap-around)', () {
        test('retorna o primeiro ponto (módulo)', () {
          final path = [
            const GeoPoint(-23.55, -46.63),
            const GeoPoint(-23.56, -46.63),
          ];
          final cumDist = TrackGeometry.buildCumDist(path);
          final totalLen = cumDist.last;

          final p =
              TrackGeometry.pointAtDist(totalLen, path, cumDist, totalLen);

          expect(p.lat, closeTo(path.first.lat, 1e-6));
        });
      });

      group('quando d está no meio de um segmento', () {
        test('retorna ponto interpolado linearmente', () {
          final path = [
            const GeoPoint(-23.55, -46.63),
            const GeoPoint(-23.57, -46.63),
          ];
          final cumDist = TrackGeometry.buildCumDist(path);
          final totalLen = cumDist.last;

          final p = TrackGeometry.pointAtDist(
              totalLen / 2, path, cumDist, totalLen);

          expect(p.lat, closeTo(-23.56, 1e-6));
          expect(p.lng, closeTo(-46.63, 1e-6));
        });
      });

      group('quando o path está vazio', () {
        test('retorna GeoPoint(0, 0)', () {
          final p = TrackGeometry.pointAtDist(0, [], [], 100.0);

          expect(p.lat, equals(0.0));
          expect(p.lng, equals(0.0));
        });
      });
    });

    group('cutLinePoints', () {
      group('para ponto no meio de um path com curvatura', () {
        test('retorna dois pontos distintos', () {
          final path = [
            const GeoPoint(-23.55, -46.63),
            const GeoPoint(-23.56, -46.64),
            const GeoPoint(-23.57, -46.63),
          ];
          final cumDist = TrackGeometry.buildCumDist(path);
          final totalLen = cumDist.last;

          final (pA, pB) = TrackGeometry.cutLinePoints(
              totalLen / 2, path, cumDist, totalLen);

          expect(pA, isNot(equals(pB)));
        });

        test('ponto médio da linha de corte coincide com o ponto no centerline', () {
          final path = [
            const GeoPoint(-23.55, -46.63),
            const GeoPoint(-23.56, -46.63),
            const GeoPoint(-23.57, -46.63),
          ];
          final cumDist = TrackGeometry.buildCumDist(path);
          final totalLen = cumDist.last;
          final d = totalLen / 2;

          final (pA, pB) =
              TrackGeometry.cutLinePoints(d, path, cumDist, totalLen);
          final midLat = (pA.lat + pB.lat) / 2;
          final midLng = (pA.lng + pB.lng) / 2;
          final onPath =
              TrackGeometry.pointAtDist(d, path, cumDist, totalLen);

          expect(midLat, closeTo(onPath.lat, 0.001));
          expect(midLng, closeTo(onPath.lng, 0.001));
        });
      });
    });

    group('subpathPoints', () {
      group('quando o path está vazio', () {
        test('retorna lista vazia', () {
          expect(TrackGeometry.subpathPoints(0, 100, [], [], 0), isEmpty);
        });
      });

      group('para subpath dentro de um path válido', () {
        test('primeiro ponto está próximo de dStart', () {
          final path = [
            const GeoPoint(-23.55, -46.63),
            const GeoPoint(-23.56, -46.63),
            const GeoPoint(-23.57, -46.63),
          ];
          final cumDist = TrackGeometry.buildCumDist(path);
          final totalLen = cumDist.last;
          final dStart = totalLen * 0.2;
          final dEnd = totalLen * 0.8;

          final pts = TrackGeometry.subpathPoints(
              dStart, dEnd, path, cumDist, totalLen);
          final expected =
              TrackGeometry.pointAtDist(dStart, path, cumDist, totalLen);

          expect(pts, isNotEmpty);
          expect(pts.first.lat, closeTo(expected.lat, 0.001));
        });

        test('último ponto está próximo de dEnd', () {
          final path = [
            const GeoPoint(-23.55, -46.63),
            const GeoPoint(-23.56, -46.63),
            const GeoPoint(-23.57, -46.63),
          ];
          final cumDist = TrackGeometry.buildCumDist(path);
          final totalLen = cumDist.last;
          final dEnd = totalLen * 0.8;

          final pts = TrackGeometry.subpathPoints(
              totalLen * 0.2, dEnd, path, cumDist, totalLen);
          final expected =
              TrackGeometry.pointAtDist(dEnd, path, cumDist, totalLen);

          expect(pts.last.lat, closeTo(expected.lat, 0.001));
        });
      });
    });

    group('Vec2', () {
      group('operações aritméticas', () {
        test('soma dois vetores corretamente', () {
          expect(const Vec2(1, 2) + const Vec2(3, 4), equals(const Vec2(4, 6)));
        });

        test('subtrai dois vetores corretamente', () {
          expect(const Vec2(5, 7) - const Vec2(2, 3), equals(const Vec2(3, 4)));
        });

        test('multiplica por escalar corretamente', () {
          expect(const Vec2(3, 4) * 2, equals(const Vec2(6, 8)));
        });
      });

      group('length', () {
        test('retorna comprimento correto para tripla 3-4-5', () {
          expect(const Vec2(3, 4).length, closeTo(5.0, 1e-9));
        });

        test('retorna 0 para o vetor nulo', () {
          expect(const Vec2(0, 0).length, equals(0.0));
        });
      });

      group('normalized', () {
        test('vetor normalizado tem length 1', () {
          expect(const Vec2(3, 4).normalized.length, closeTo(1.0, 1e-9));
        });

        test('vetor nulo normalizado retorna Vec2(0,0)', () {
          final result = const Vec2(0, 0).normalized;

          expect(result.x, equals(0));
          expect(result.y, equals(0));
        });
      });

      group('perp', () {
        test('é perpendicular ao vetor original (dot product = 0)', () {
          const v = Vec2(3, 4);

          expect(v.dot(v.perp), closeTo(0.0, 1e-9));
        });
      });

      group('dot', () {
        test('calcula produto escalar corretamente', () {
          expect(const Vec2(1, 2).dot(const Vec2(3, 4)), equals(11));
        });
      });
    });
  });
}
