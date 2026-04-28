import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';

void main() {
  group('GeoPoint', () {
    test('dois pontos com mesmos valores são iguais', () {
      const a = GeoPoint(-23.55, -46.63);
      const b = GeoPoint(-23.55, -46.63);

      expect(a, equals(b));
    });

    test('dois pontos com valores diferentes não são iguais', () {
      const a = GeoPoint(-23.55, -46.63);
      const b = GeoPoint(-23.56, -46.63);

      expect(a, isNot(equals(b)));
    });
  });

  group('TrackLine', () {
    const a = GeoPoint(-23.55, -46.63);
    const b = GeoPoint(-23.57, -46.61);

    test('armazena os dois pontos corretamente', () {
      const line = TrackLine(a: a, b: b);

      expect(line.a, equals(a));
      expect(line.b, equals(b));
    });

    test('midpoint é o ponto médio geográfico para linha de 2 pontos', () {
      const line = TrackLine(a: a, b: b);

      expect(line.midpoint.lat, closeTo((a.lat + b.lat) / 2, 1e-10));
      expect(line.midpoint.lng, closeTo((a.lng + b.lng) / 2, 1e-10));
    });

    test('midpoint de linha com pontos iguais é o próprio ponto', () {
      const p = GeoPoint(0.0, 0.0);
      const line = TrackLine(a: p, b: p);

      expect(line.midpoint, equals(p));
    });

    group('allPoints', () {
      test('linha sem middlePoints retorna apenas a e b', () {
        const line = TrackLine(a: a, b: b);

        expect(line.allPoints, equals([a, b]));
      });

      test('linha com middlePoints retorna a + middle + b em ordem', () {
        const m = GeoPoint(-23.56, -46.62);
        const line = TrackLine(a: a, b: b, middlePoints: [m]);

        expect(line.allPoints, equals([a, m, b]));
      });

      test('linha reta tem allPoints com 2 elementos', () {
        const line = TrackLine(a: a, b: b);

        expect(line.allPoints.length, equals(2));
      });
    });

    group('middlePoints', () {
      test('padrão é lista vazia', () {
        const line = TrackLine(a: a, b: b);

        expect(line.middlePoints, isEmpty);
      });

      test('midpoint de linha curva é a média de todos os pontos', () {
        const m = GeoPoint(-23.56, -46.62);
        const line = TrackLine(a: a, b: b, middlePoints: [m]);
        final expectedLat = (a.lat + m.lat + b.lat) / 3;
        final expectedLng = (a.lng + m.lng + b.lng) / 3;

        expect(line.midpoint.lat, closeTo(expectedLat, 1e-10));
        expect(line.midpoint.lng, closeTo(expectedLng, 1e-10));
      });
    });

    group('widthMeters', () {
      test('padrão é 6.0 metros', () {
        const line = TrackLine(a: a, b: b);

        expect(line.widthMeters, equals(6.0));
      });

      test('armazena widthMeters personalizado', () {
        const line = TrackLine(a: a, b: b, widthMeters: 12.0);

        expect(line.widthMeters, equals(12.0));
      });

      test('aceita valor mínimo de 3 metros', () {
        const line = TrackLine(a: a, b: b, widthMeters: 3.0);

        expect(line.widthMeters, equals(3.0));
      });

      test('aceita valor máximo de 30 metros', () {
        const line = TrackLine(a: a, b: b, widthMeters: 30.0);

        expect(line.widthMeters, equals(30.0));
      });
    });
  });

  group('Track', () {
    test('armazena id e nome obrigatórios', () {
      const track = Track(id: '1', name: 'Interlagos');

      expect(track.id, equals('1'));
      expect(track.name, equals('Interlagos'));
    });

    test('lastSession é nulo por padrão', () {
      const track = Track(id: '1', name: 'Interlagos');

      expect(track.lastSession, isNull);
    });

    test('armazena lastSession quando fornecido', () {
      final date = DateTime(2026, 4, 10);
      final track = Track(id: '2', name: 'Granja Viana', lastSession: date);

      expect(track.lastSession, equals(date));
    });

    test('startFinishLine é nulo por padrão', () {
      const track = Track(id: '1', name: 'Pista A');

      expect(track.startFinishLine, isNull);
    });

    test('armazena startFinishLine quando fornecida', () {
      const line = TrackLine(
        a: GeoPoint(-23.55, -46.63),
        b: GeoPoint(-23.57, -46.61),
      );
      const track = Track(id: '1', name: 'Pista A', startFinishLine: line);

      expect(track.startFinishLine, equals(line));
    });

    test('sectorBoundaries é lista vazia por padrão', () {
      const track = Track(id: '1', name: 'Pista A');

      expect(track.sectorBoundaries, isEmpty);
    });

    test('armazena sectorBoundaries quando fornecidas', () {
      const boundaries = [
        TrackLine(a: GeoPoint(-23.55, -46.63), b: GeoPoint(-23.56, -46.62)),
        TrackLine(a: GeoPoint(-23.56, -46.62), b: GeoPoint(-23.57, -46.61)),
      ];
      const track =
          Track(id: '1', name: 'Pista A', sectorBoundaries: boundaries);

      expect(track.sectorBoundaries.length, equals(2));
    });

    test('tracks com ids diferentes são pistas distintas', () {
      const t1 = Track(id: 'a', name: 'Pista A');
      const t2 = Track(id: 'b', name: 'Pista A');

      expect(t1.id, isNot(equals(t2.id)));
    });

    test('aceita nome com caracteres especiais e acentos', () {
      const track = Track(id: '3', name: 'Kartódromo São Paulo');

      expect(track.name, equals('Kartódromo São Paulo'));
    });

    test('createdAt é nulo por padrão', () {
      const track = Track(id: '1', name: 'Pista');

      expect(track.createdAt, isNull);
    });

    test('updatedAt é nulo por padrão', () {
      const track = Track(id: '1', name: 'Pista');

      expect(track.updatedAt, isNull);
    });

    test('armazena createdAt quando fornecido', () {
      final date = DateTime(2026, 4, 28, 10, 0);
      final track = Track(id: '1', name: 'Pista', createdAt: date);

      expect(track.createdAt, equals(date));
    });
  });

  group('GeoPoint serialização', () {
    test('toJson serializa lat e lng corretamente', () {
      const p = GeoPoint(-23.55, -46.63);

      expect(p.toJson(), equals({'lat': -23.55, 'lng': -46.63}));
    });

    test('fromJson reconstrói o ponto original', () {
      const original = GeoPoint(-23.55, -46.63);
      final restored = GeoPoint.fromJson(original.toJson());

      expect(restored, equals(original));
    });

    test('fromJson com coordenadas positivas', () {
      const p = GeoPoint(48.858, 2.294);
      final restored = GeoPoint.fromJson(p.toJson());

      expect(restored.lat, equals(48.858));
      expect(restored.lng, equals(2.294));
    });
  });

  group('TrackLine serialização', () {
    const a = GeoPoint(-23.55, -46.63);
    const b = GeoPoint(-23.57, -46.61);

    test('toJson inclui a, b, middlePoints vazio e widthMeters padrão', () {
      const line = TrackLine(a: a, b: b);
      final json = line.toJson();

      expect(json['a'], equals({'lat': -23.55, 'lng': -46.63}));
      expect(json['b'], equals({'lat': -23.57, 'lng': -46.61}));
      expect(json['middlePoints'], equals([]));
      expect(json['widthMeters'], equals(6.0));
    });

    test('fromJson reconstrói linha reta', () {
      const original = TrackLine(a: a, b: b);
      final restored = TrackLine.fromJson(original.toJson());

      expect(restored.a, equals(a));
      expect(restored.b, equals(b));
      expect(restored.middlePoints, isEmpty);
      expect(restored.widthMeters, equals(6.0));
    });

    test('fromJson reconstrói linha curva com middlePoints', () {
      const m = GeoPoint(-23.56, -46.62);
      const original = TrackLine(a: a, b: b, middlePoints: [m]);
      final restored = TrackLine.fromJson(original.toJson());

      expect(restored.middlePoints.length, equals(1));
      expect(restored.middlePoints.first, equals(m));
    });

    test('fromJson reconstrói widthMeters personalizado', () {
      const original = TrackLine(a: a, b: b, widthMeters: 12.0);
      final restored = TrackLine.fromJson(original.toJson());

      expect(restored.widthMeters, equals(12.0));
    });
  });

  group('Track serialização', () {
    const a = GeoPoint(-23.55, -46.63);
    const b = GeoPoint(-23.57, -46.61);

    test('toJson/fromJson preserva id e nome', () {
      const original = Track(id: 'abc-123', name: 'Interlagos');
      final restored = Track.fromJson(original.toJson());

      expect(restored.id, equals('abc-123'));
      expect(restored.name, equals('Interlagos'));
    });

    test('toJson/fromJson preserva startFinishLine', () {
      const line = TrackLine(a: a, b: b);
      const original = Track(id: '1', name: 'P', startFinishLine: line);
      final restored = Track.fromJson(original.toJson());

      expect(restored.startFinishLine, isNotNull);
      expect(restored.startFinishLine!.a, equals(a));
      expect(restored.startFinishLine!.b, equals(b));
    });

    test('toJson/fromJson com startFinishLine nula', () {
      const original = Track(id: '1', name: 'P');
      final restored = Track.fromJson(original.toJson());

      expect(restored.startFinishLine, isNull);
    });

    test('toJson/fromJson preserva sectorBoundaries', () {
      const boundaries = [
        TrackLine(a: a, b: b),
        TrackLine(
          a: GeoPoint(-23.56, -46.62),
          b: GeoPoint(-23.58, -46.60),
        ),
      ];
      const original =
          Track(id: '1', name: 'P', sectorBoundaries: boundaries);
      final restored = Track.fromJson(original.toJson());

      expect(restored.sectorBoundaries.length, equals(2));
      expect(restored.sectorBoundaries[0].a, equals(a));
    });

    test('toJson/fromJson preserva lastSession', () {
      final date = DateTime.utc(2026, 4, 28);
      final original = Track(id: '1', name: 'P', lastSession: date);
      final restored = Track.fromJson(original.toJson());

      expect(restored.lastSession, equals(date));
    });

    test('toJson/fromJson preserva createdAt e updatedAt', () {
      final now = DateTime.utc(2026, 4, 28, 10, 30);
      final original =
          Track(id: '1', name: 'P', createdAt: now, updatedAt: now);
      final restored = Track.fromJson(original.toJson());

      expect(restored.createdAt, equals(now));
      expect(restored.updatedAt, equals(now));
    });

    test('toJson/fromJson com campos opcionais nulos', () {
      const original = Track(id: '1', name: 'P');
      final restored = Track.fromJson(original.toJson());

      expect(restored.lastSession, isNull);
      expect(restored.createdAt, isNull);
      expect(restored.updatedAt, isNull);
      expect(restored.sectorBoundaries, isEmpty);
    });
  });
}
