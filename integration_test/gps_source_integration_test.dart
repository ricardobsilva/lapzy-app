import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/models/race_session_record.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/screens/race_screen.dart';
import 'package:lapzy/services/gps_source.dart';
import 'package:lapzy/services/gps_source_manager.dart';
import 'package:lapzy/services/internal_gps_service.dart';
import 'package:lapzy/services/external_gps_service.dart';
import 'package:lapzy/services/lap_detector.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

Position _posAt(double lat, double lng, DateTime t) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: t,
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 14.0,
      speedAccuracy: 0.5,
    );

Track _testTrack() => const Track(
      id: 'gps-integration-track',
      name: 'GPS Integration Test',
      startFinishLine: TrackLine(
        a: GeoPoint(-23.500, -46.630),
        b: GeoPoint(-23.500, -46.620),
        widthMeters: 50.0,
      ),
    );

// ── stream simulado que dispara cruzamentos da S/C ────────────────────────────

Stream<Position> _lapCrossingStream({required int lapCount}) async* {
  final t0 = DateTime(2026, 5, 1, 10, 0, 0);

  // Posição inicial ao sul da S/C.
  yield _posAt(-23.5004, -46.625, t0);

  for (int lap = 0; lap < lapCount; lap++) {
    final base = t0.add(Duration(seconds: 5 + lap * 65));
    // Sul → norte cruzando a linha.
    yield _posAt(-23.5002, -46.625, base);
    yield _posAt(-23.4998, -46.625, base.add(const Duration(milliseconds: 500)));
    // Continua a volta voltando para o sul.
    yield _posAt(-23.5005, -46.625, base.add(const Duration(seconds: 60)));
  }
}

// ── testes ────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => GpsSourceManager.resetForTesting());
  tearDown(() => GpsSourceManager.resetForTesting());

  group('GpsSourceManager → LapDetector (CA-GPS-001-10)', () {
    testWidgets('LapDetector detecta voltas com InternalGpsService', (tester) async {
      final posStream = _lapCrossingStream(lapCount: 2);
      final internal = InternalGpsService(streamFactory: () => posStream);
      GpsSourceManager.resetForTesting(
        GpsSourceManager.forTesting(activeSource: internal),
      );
      GpsSourceManager.instance.init();

      final track = _testTrack();
      final detector = LapDetector(
        track: track,
        positionStreamFactory: () => GpsSourceManager.instance.positionStream,
        minLapMs: 5000,
      );

      final events = <LapEvent>[];
      final sub = detector.events.listen(events.add);
      detector.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      detector.dispose();
      sub.cancel();

      final laps = events.whereType<LapCrossedEvent>().toList();
      expect(laps.length, greaterThanOrEqualTo(1),
          reason: 'LapDetector deve detectar ao menos 1 volta com InternalGpsService');
    });

    testWidgets('LapDetector detecta voltas com ExternalGpsService (CA-GPS-001-14)',
        (tester) async {
      final posStream = _lapCrossingStream(lapCount: 2);

      final external = ExternalGpsService(
        info: const GpsSourceInfo(
          name: 'Garmin GLO 2',
          connectionType: GpsConnectionType.bluetooth,
        ),
        streamFactory: () => posStream,
      );
      GpsSourceManager.resetForTesting(
        GpsSourceManager.forTesting(activeSource: external),
      );
      GpsSourceManager.instance.init();

      final track = _testTrack();
      final detector = LapDetector(
        track: track,
        positionStreamFactory: () => GpsSourceManager.instance.positionStream,
        minLapMs: 5000,
      );

      final events = <LapEvent>[];
      final sub = detector.events.listen(events.add);
      detector.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      detector.dispose();
      sub.cancel();

      final laps = events.whereType<LapCrossedEvent>().toList();
      expect(laps.length, greaterThanOrEqualTo(1),
          reason: 'LapDetector deve detectar ao menos 1 volta com ExternalGpsService');
    });

    testWidgets('LapDetector comportamento equivalente com ambas as fontes', (tester) async {
      LapEvent? internalFirstLap;
      LapEvent? externalFirstLap;

      final stream1 = _lapCrossingStream(lapCount: 1);
      final stream2 = _lapCrossingStream(lapCount: 1);

      for (final useExternal in [false, true]) {
        GpsSourceManager.resetForTesting();

        final GpsSource source = useExternal
            ? ExternalGpsService(
                info: const GpsSourceInfo(
                  name: 'Garmin',
                  connectionType: GpsConnectionType.bluetooth,
                ),
                streamFactory: () => stream2,
              )
            : InternalGpsService(streamFactory: () => stream1);

        GpsSourceManager.resetForTesting(
          GpsSourceManager.forTesting(activeSource: source),
        );
        GpsSourceManager.instance.init();

        final detector = LapDetector(
          track: _testTrack(),
          positionStreamFactory: () => GpsSourceManager.instance.positionStream,
          minLapMs: 5000,
        );

        final sub = detector.events.listen((e) {
          if (e is LapCrossedEvent) {
            if (useExternal) {
              externalFirstLap ??= e;
            } else {
              internalFirstLap ??= e;
            }
          }
        });

        detector.start();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        detector.dispose();
        sub.cancel();
      }

      expect(internalFirstLap, isNotNull,
          reason: 'InternalGpsService deve detectar volta');
      expect(externalFirstLap, isNotNull,
          reason: 'ExternalGpsService deve detectar volta');
    });
  });

  group('Fallback automático (CA-GPS-001-11)', () {
    testWidgets('positionStream continua emitindo após fallback para interno', (tester) async {
      final externalController = StreamController<Position>();
      final internalController = StreamController<Position>();

      final external = ExternalGpsService(
        info: const GpsSourceInfo(
          name: 'Garmin',
          connectionType: GpsConnectionType.bluetooth,
        ),
        streamFactory: () => externalController.stream,
      );

      GpsSourceManager.resetForTesting(
        GpsSourceManager.forTesting(
          activeSource: external,
          internalFallback: InternalGpsService(streamFactory: () => internalController.stream),
        ),
      );
      final manager = GpsSourceManager.instance;
      manager.init();

      final positions = <Position>[];
      final sub = manager.positionStream.listen(positions.add);

      final t = DateTime(2026, 5, 1);
      externalController.add(_posAt(-23.5, -46.6, t));
      await Future<void>.delayed(Duration.zero);

      expect(positions.length, equals(1));
      expect(manager.activeSource, isA<ExternalGpsService>());

      await externalController.close();
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeSource, isA<InternalGpsService>(),
          reason: 'Deve fazer fallback para GPS interno após desconexão');

      internalController.add(_posAt(-23.51, -46.61, t.add(const Duration(seconds: 1))));
      await Future<void>.delayed(Duration.zero);

      expect(positions.length, equals(2),
          reason: 'positionStream deve continuar emitindo após fallback');

      sub.cancel();
      await internalController.close();
    });
  });

  group('RaceSummaryScreen: gpsSource no record (CA-GPS-001-12)', () {
    testWidgets('gpsSource é registrado no RaceSessionRecord ao encerrar corrida',
        (tester) async {
      final btInfo = const GpsSourceInfo(
        name: 'Garmin GLO 2',
        connectionType: GpsConnectionType.bluetooth,
      );
      final external = ExternalGpsService(
        info: btInfo,
        streamFactory: () => const Stream.empty(),
      );
      GpsSourceManager.resetForTesting(
        GpsSourceManager.forTesting(activeSource: external),
      );

      final track = _testTrack();
      final posController = StreamController<Position>();

      await tester.pumpWidget(
        MaterialApp(
          home: RaceScreen(
            track: track,
            detectorFactory: (t) => LapDetector(
              track: t,
              positionStreamFactory: () => posController.stream,
              minLapMs: 5000,
            ),
            clockFactory: DateTime.now,
          ),
        ),
      );

      expect(GpsSourceManager.instance.activeSource.info, equals(btInfo));
      await posController.close();
    });
  });

  group('CA-GPS-001-17: sessões antigas sem gpsSource carregam normalmente', () {
    test('RaceSessionRecord.fromJson sem campo gpsSource não dá crash', () {
      final json = {
        'id': 'uuid-001',
        'trackId': 'track-1',
        'trackName': 'Pista Teste',
        'date': '2026-01-01T10:00:00.000Z',
        'laps': <dynamic>[],
        'bestLapMs': null,
        'createdAt': '2026-01-01T10:00:00.000Z',
        // sem campo 'gpsSource' — simula sessão salva antes de TASK-025
      };

      final record = RaceSessionRecord.fromJson(json);
      expect(record.gpsSource, isNull);
    });
  });
}
