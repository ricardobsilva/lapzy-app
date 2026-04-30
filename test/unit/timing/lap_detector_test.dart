import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/services/lap_detector.dart';

// ── HELPERS ───────────────────────────────────────────────────────────────────

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 1, 1),
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

Position _posAt(double lat, double lng, DateTime timestamp) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: timestamp,
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

/// Cria um LapDetector com stream de posições controlado por [controller].
LapDetector _detectorWithStream(
  Track track,
  StreamController<Position> controller,
) {
  return LapDetector(
    track: track,
    positionStreamFactory: () => controller.stream,
  );
}

/// Pista mínima: linha S/C horizontal em lat=-23.5, lng de -46.63 até -46.62.
/// Largura de detecção: 50m. Posições de teste usam ±0.0004 lat (~44m).
Track _trackWithLine() {
  return const Track(
    id: 'test',
    name: 'Test Track',
    startFinishLine: TrackLine(
      a: GeoPoint(-23.5, -46.63),
      b: GeoPoint(-23.5, -46.62),
      widthMeters: 50.0,
    ),
  );
}

/// Pista com S/C + 2 setores.
Track _trackWithSectors() {
  return const Track(
    id: 'test',
    name: 'Test Track',
    startFinishLine: TrackLine(
      a: GeoPoint(-23.500, -46.630),
      b: GeoPoint(-23.500, -46.620),
      widthMeters: 50.0,
    ),
    sectorBoundaries: [
      TrackLine(
        a: GeoPoint(-23.490, -46.630),
        b: GeoPoint(-23.490, -46.620),
        widthMeters: 50.0,
      ),
      TrackLine(
        a: GeoPoint(-23.480, -46.630),
        b: GeoPoint(-23.480, -46.620),
        widthMeters: 50.0,
      ),
    ],
  );
}

// ── TESTES ────────────────────────────────────────────────────────────────────

void main() {
  group('LapDetector', () {
    group('cruzamento da linha S/C', () {
      test('emite LapCrossedEvent ao cruzar de sul para norte', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Sul da linha → norte da linha (cruza lat=-23.5); ±0.0004 ≈ 44m < 50m
        ctrl.add(_pos(-23.5004, -46.625)); // antes
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625)); // depois
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<LapCrossedEvent>());

        detector.dispose();
        await ctrl.close();
      });

      test('emite LapCrossedEvent ao cruzar de norte para sul', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<LapCrossedEvent>());

        detector.dispose();
        await ctrl.close();
      });

      test('não emite evento quando cruzamento ocorre fora dos limites do segmento', () async {
        final ctrl = StreamController<Position>();
        // Segmento entre lng -46.63 e -46.62. O cruzamento ocorre em lng -46.700,
        // que está fora dos limites do segmento — não deve disparar evento.
        const trackFarAway = Track(
          id: 'far',
          name: 'Far Track',
          startFinishLine: TrackLine(
            a: GeoPoint(-23.5, -46.63),
            b: GeoPoint(-23.5, -46.62),
            widthMeters: 6.0,
          ),
        );
        final detector = _detectorWithStream(trackFarAway, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza em lng=-46.700, muito além do segmento [-46.63, -46.62]
        ctrl.add(_pos(-23.5004, -46.700));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.700));
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });

      test('não emite evento sem linha S/C definida', () async {
        final ctrl = StreamController<Position>();
        const trackNoLine = Track(id: 'no-line', name: 'No Line');
        final detector = _detectorWithStream(trackNoLine, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });

      test('primeira posição não emite evento (sem posição anterior)', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.4996, -46.625)); // apenas uma posição
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });
    });

    group('cruzamento de setores', () {
      test('emite SectorCrossedEvent(0) ao cruzar boundary S1', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithSectors();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza boundary do S1 em lat=-23.490; ±0.0004 ≈ 44m < 50m
        ctrl.add(_pos(-23.4904, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4896, -46.625));
        await Future.delayed(Duration.zero);

        final sectorEvents = events.whereType<SectorCrossedEvent>().toList();
        expect(sectorEvents, hasLength(1));
        expect(sectorEvents.first.sectorIndex, 0);

        detector.dispose();
        await ctrl.close();
      });

      test('emite SectorCrossedEvent(1) ao cruzar boundary S2', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithSectors();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza boundary do S2 em lat=-23.480; ±0.0004 ≈ 44m < 50m
        ctrl.add(_pos(-23.4804, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4796, -46.625));
        await Future.delayed(Duration.zero);

        final sectorEvents = events.whereType<SectorCrossedEvent>().toList();
        expect(sectorEvents, hasLength(1));
        expect(sectorEvents.first.sectorIndex, 1);

        detector.dispose();
        await ctrl.close();
      });
    });

    group('polilinha (middlePoints)', () {
      test('detecta cruzamento no sub-segmento intermediário da polilinha', () async {
        final ctrl = StreamController<Position>();
        // Polilinha em L: segmento 1 = norte-sul em lng=-46.630,
        //                 segmento 2 = leste-oeste em lat=-23.495.
        // Movimento cruza lat=-23.495 dentro do segmento 2 (lng∈[-46.630, -46.620]).
        const track = Track(
          id: 'poly',
          name: 'Poly Track',
          startFinishLine: TrackLine(
            a: GeoPoint(-23.500, -46.630),
            b: GeoPoint(-23.495, -46.620),
            middlePoints: [GeoPoint(-23.495, -46.630)],
            widthMeters: 50.0,
          ),
        );
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza o sub-segmento horizontal em lat=-23.495 no lng=-46.625
        ctrl.add(_pos(-23.4954, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4946, -46.625));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<LapCrossedEvent>());

        detector.dispose();
        await ctrl.close();
      });

      test('não detecta cruzamento fora dos sub-segmentos da polilinha', () async {
        final ctrl = StreamController<Position>();
        // Mesma polilinha em L, mas o movimento ocorre em lng=-46.700
        // (fora do segmento 2 que vai até lng=-46.620).
        const track = Track(
          id: 'poly-outside',
          name: 'Poly Outside Track',
          startFinishLine: TrackLine(
            a: GeoPoint(-23.500, -46.630),
            b: GeoPoint(-23.495, -46.620),
            middlePoints: [GeoPoint(-23.495, -46.630)],
            widthMeters: 6.0,
          ),
        );
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.4954, -46.700));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4946, -46.700));
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });

      test('não dispara dois eventos ao cruzar linha reta sem middlePoints (regressão)', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);

        // Linha reta sem middlePoints: exatamente 1 evento
        expect(events, hasLength(1));

        detector.dispose();
        await ctrl.close();
      });
    });

    group('timestamp interpolado', () {
      test('timestamp do evento está entre os timestamps das duas posições GPS', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final t0 = DateTime(2026, 1, 1, 12, 0, 0);
        final t1 = DateTime(2026, 1, 1, 12, 0, 1); // 1s depois

        // Cruzamento exato em lat=-23.500: metade entre -23.5004 e -23.4996
        ctrl.add(_posAt(-23.5004, -46.625, t0));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t1));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        final event = events.first as LapCrossedEvent;
        // t ≈ 0.5 → crossingTime ≈ t0 + 500ms
        expect(event.timestamp.isAfter(t0), isTrue);
        expect(event.timestamp.isBefore(t1), isTrue);
        // Tolerância de ±50ms ao redor de 500ms
        final delta = event.timestamp.difference(t0).inMilliseconds;
        expect(delta, greaterThan(450));
        expect(delta, lessThan(550));

        detector.dispose();
        await ctrl.close();
      });

      test('timestamp igual a prevTime quando cruzamento ocorre no início do vetor', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final t0 = DateTime(2026, 1, 1, 12, 0, 0);
        final t1 = DateTime(2026, 1, 1, 12, 0, 1);

        // Prev muito próximo da linha (t ≈ 0): crossing quase em t0
        ctrl.add(_posAt(-23.50001, -46.625, t0));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t1));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        final event = events.first as LapCrossedEvent;
        // t muito pequeno → timestamp próximo de t0
        expect(event.timestamp.isAfter(t0) || event.timestamp == t0, isTrue);
        expect(event.timestamp.isBefore(t1), isTrue);

        detector.dispose();
        await ctrl.close();
      });
    });

    group('stop e dispose', () {
      test('stop cancela a stream — sem novos eventos após stop', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        detector.stop();

        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });

      test('stop reseta posição anterior — primeiro evento após restart não dispara', () async {
        // Broadcast necessário para permitir re-listen após stop/start.
        final ctrl = StreamController<Position>.broadcast();
        final track = _trackWithLine();
        final detector = LapDetector(
          track: track,
          positionStreamFactory: () => ctrl.stream,
        );
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza a linha
        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));

        // Restart — posição anterior é zerada
        detector.stop();
        detector.start();

        // Primeira posição após restart não deve disparar evento (sem prev)
        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);
        expect(events, hasLength(1)); // ainda 1, sem novo evento

        detector.dispose();
        await ctrl.close();
      });
    });
  });
}
