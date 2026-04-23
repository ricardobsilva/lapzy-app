import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/services/lap_detector.dart';

// ── HELPERS ───────────────────────────────────────────────────────────────────

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
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

      test('não emite evento quando posição está longe da linha', () async {
        final ctrl = StreamController<Position>();
        const trackFarAway = Track(
          id: 'far',
          name: 'Far Track',
          startFinishLine: TrackLine(
            a: GeoPoint(-23.5, -46.63),
            b: GeoPoint(-23.5, -46.62),
            widthMeters: 1.0, // corredor muito estreito
          ),
        );
        final detector = _detectorWithStream(trackFarAway, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza em lng muito diferente da linha — fora do corredor
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
    });
  });
}
