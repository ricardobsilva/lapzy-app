import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/screens/race_screen.dart';
import 'package:lapzy/services/lap_detector.dart';

void _mockWakelock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => StandardMessageCodec().encodeMessage([null]),
  );
}

void _mockForegroundService() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('lapzy/foreground_service'),
    (_) async => null,
  );
}

class _TestClock {
  DateTime _now;
  _TestClock([DateTime? initial]) : _now = initial ?? DateTime(2026);
  DateTime call() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

class _FakeDetector extends LapDetector {
  final DateTime Function() _clock;
  final StreamController<LapEvent> _ctrl =
      StreamController<LapEvent>.broadcast();

  _FakeDetector({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(
          track: const Track(id: 'test', name: 'Test'),
          positionStreamFactory: () => const Stream.empty(),
        );

  @override
  Stream<LapEvent> get events => _ctrl.stream;

  @override
  void start() {}

  @override
  void stop() {}

  @override
  void dispose() {
    _ctrl.close();
    super.dispose();
  }

  void fireLap() => _ctrl.add(LapCrossedEvent(_clock()));
  void fireSector(int idx) =>
      _ctrl.add(SectorCrossedEvent(idx, _clock()));
}

const _trackWithSectors = Track(
  id: 'test-s',
  name: 'Test Track Sectors',
  sectorBoundaries: [
    TrackLine(a: GeoPoint(-23.50, -46.63), b: GeoPoint(-23.50, -46.62)),
    TrackLine(a: GeoPoint(-23.49, -46.63), b: GeoPoint(-23.49, -46.62)),
    TrackLine(a: GeoPoint(-23.48, -46.63), b: GeoPoint(-23.48, -46.62)),
  ],
);

Widget _buildScreen({
  required _FakeDetector detector,
  int? prThresholdMs,
  Track track = const Track(id: 'test', name: 'Test Track'),
  DateTime Function()? clock,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RaceScreen(
      track: track,
      prThresholdMs: prThresholdMs,
      detectorFactory: (_) => detector,
      clockFactory: clock,
    ),
  );
}

void _setLandscape(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// pump(1ms) após fire — necessário para o stream async entregar o evento ao listener.
const _k1ms = Duration(milliseconds: 1);

void main() {
  setUp(() {
    _mockWakelock();
    _mockForegroundService();
  });

  group('evidências — bordas por volta', () {
    testWidgets('borda_melhor_volta — roxo (1ª volta concluída)', (tester) async {
      _setLandscape(tester);
      final clock = _TestClock();
      final d = _FakeDetector(clock: clock.call);
      await tester.pumpWidget(_buildScreen(detector: d, clock: clock.call));
      d.fireLap(); // largada
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1)); // ~1s de volta
      d.fireLap(); // completa 1ª volta → melhorVolta (roxo)
      await tester.pump(_k1ms);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/borda_melhor_volta.png'),
      );
    });

    testWidgets('borda_volta_melhor — verde (2ª volta mais rápida)', (tester) async {
      _setLandscape(tester);
      final clock = _TestClock();
      final d = _FakeDetector(clock: clock.call);
      await tester.pumpWidget(_buildScreen(detector: d, clock: clock.call));
      d.fireLap(); // largada
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2)); // 1ª volta = 2s
      d.fireLap();
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1)); // 2ª volta = 1s (mais rápida)
      d.fireLap(); // completa 2ª volta → voltaMelhor (verde)
      await tester.pump(_k1ms);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/borda_volta_melhor.png'),
      );
    });

    testWidgets('borda_volta_pior — vermelho (2ª volta mais lenta)', (tester) async {
      _setLandscape(tester);
      final clock = _TestClock();
      final d = _FakeDetector(clock: clock.call);
      await tester.pumpWidget(_buildScreen(detector: d, clock: clock.call));
      d.fireLap(); // largada
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1)); // 1ª volta = 1s
      d.fireLap();
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2)); // 2ª volta = 2s (mais lenta)
      d.fireLap(); // completa 2ª volta → voltaPior (vermelho)
      await tester.pump(_k1ms);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/borda_volta_pior.png'),
      );
    });

    testWidgets('borda_personal_record — verde pulsante com banner PR', (tester) async {
      _setLandscape(tester);
      final clock = _TestClock();
      final d = _FakeDetector(clock: clock.call);
      await tester.pumpWidget(_buildScreen(
        detector: d,
        clock: clock.call,
        prThresholdMs: 30000, // threshold 30s
      ));
      d.fireLap(); // largada
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2)); // 1ª volta = 2s
      d.fireLap();
      await tester.pump(_k1ms);
      clock.advance(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 900)); // 2ª volta = 0.9s < 30s threshold
      d.fireLap(); // completa → personalRecord (verde pulsante + banner PR)
      await tester.pump(const Duration(milliseconds: 350)); // captura durante pulso
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/borda_personal_record.png'),
      );
    });
  });

  group('evidências — setores durante a volta', () {
    testWidgets('setor_vazio — S1 S2 S3 antes de cruzar', (tester) async {
      _setLandscape(tester);
      final clock = _TestClock();
      final d = _FakeDetector(clock: clock.call);
      await tester.pumpWidget(_buildScreen(detector: d, clock: clock.call, track: _trackWithSectors));
      d.fireLap(); // largada
      await tester.pump(_k1ms);
      clock.advance(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/setor_vazio.png'),
      );
    });

    testWidgets('setor_s1_preenchido — 1ª volta sem feedback de comparação', (tester) async {
      _setLandscape(tester);
      final clock = _TestClock();
      final d = _FakeDetector(clock: clock.call);
      await tester.pumpWidget(_buildScreen(detector: d, clock: clock.call, track: _trackWithSectors));
      d.fireLap(); // largada
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1)); // ~1s até S1
      d.fireSector(0); // S1 cruzado
      await tester.pump(_k1ms);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/setor_s1_preenchido.png'),
      );
    });

    testWidgets('setor_feedback_verde — S1 mais rápido que volta anterior', (tester) async {
      _setLandscape(tester);
      final clock = _TestClock();
      final d = _FakeDetector(clock: clock.call);
      await tester.pumpWidget(_buildScreen(detector: d, clock: clock.call, track: _trackWithSectors));
      // 1ª volta completa: S1=2s, S2=1s, S3=1s, total=5s
      d.fireLap(); // largada
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      d.fireSector(0); // S1 1ª volta = 2s
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      d.fireSector(1);
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      d.fireSector(2);
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      d.fireLap(); // completa 1ª volta
      await tester.pump(_k1ms);
      // 2ª volta: S1 em 1s (< 2s da 1ª volta) → feedback verde
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      d.fireSector(0);
      await tester.pump(_k1ms);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/setor_feedback_verde.png'),
      );
    });

    testWidgets('setor_feedback_vermelho — S1 mais lento que volta anterior', (tester) async {
      _setLandscape(tester);
      final clock = _TestClock();
      final d = _FakeDetector(clock: clock.call);
      await tester.pumpWidget(_buildScreen(detector: d, clock: clock.call, track: _trackWithSectors));
      // 1ª volta completa: S1=1s, S2=1s, S3=1s, total=4s
      d.fireLap(); // largada
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      d.fireSector(0); // S1 1ª volta = 1s
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      d.fireSector(1);
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      d.fireSector(2);
      await tester.pump(_k1ms);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      d.fireLap(); // completa 1ª volta
      await tester.pump(_k1ms);
      // 2ª volta: S1 em 2s (> 1s da 1ª volta) → feedback vermelho
      clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      d.fireSector(0);
      await tester.pump(_k1ms);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/setor_feedback_vermelho.png'),
      );
    });
  });
}
