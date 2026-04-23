import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/screens/race_screen.dart';
import 'package:lapzy/services/lap_detector.dart';

// ── HELPERS ───────────────────────────────────────────────────────────────────

/// LapDetector com stream controlado para injeção de eventos.
class _FakeDetector extends LapDetector {
  final StreamController<LapEvent> _ctrl = StreamController<LapEvent>.broadcast();

  _FakeDetector()
      : super(
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

  void fireLap() => _ctrl.add(LapCrossedEvent(DateTime.now()));
  void fireSector(int idx) => _ctrl.add(SectorCrossedEvent(idx, DateTime.now()));
}

Widget _buildScreen({
  _FakeDetector? detector,
  int? prThresholdMs,
}) {
  final d = detector ?? _FakeDetector();
  return MaterialApp(
    home: RaceScreen(
      track: const Track(id: 'test', name: 'Test Track'),
      prThresholdMs: prThresholdMs,
      detectorFactory: (_) => d,
    ),
  );
}

// ── TESTES ────────────────────────────────────────────────────────────────────

void main() {
  group('RaceScreen', () {
    group('estado inicial', () {
      testWidgets('exibe label TEMPO DA VOLTA', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('TEMPO DA VOLTA'), findsOneWidget);
      });

      testWidgets('exibe label VOLTA', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('VOLTA'), findsOneWidget);
      });

      testWidgets('exibe número de volta inicial como 1', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('1'), findsOneWidget);
      });

      testWidgets('exibe label MELHOR VOLTA', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('MELHOR VOLTA'), findsOneWidget);
      });

      testWidgets('exibe botão FINALIZAR', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('FINALIZAR'), findsOneWidget);
      });

      testWidgets('exibe labels de setores S1, S2, S3', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('S1'), findsOneWidget);
        expect(find.text('S2'), findsOneWidget);
        expect(find.text('S3'), findsOneWidget);
      });

      testWidgets('timer inicia em 0:00.000', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('0:00.000'), findsOneWidget);
      });

      testWidgets('não exibe banner PERSONAL RECORD no início', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('PERSONAL RECORD'), findsNothing);
      });
    });

    group('estado: melhor volta (primeira volta completada)', () {
      testWidgets('exibe texto MELHOR na delta pill após primeira volta', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('MELHOR'), findsOneWidget);
      });

      testWidgets('número de volta avança para 2 após primeira volta', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('borda exibe cor roxa (#BF5AF2) após primeira volta', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final eventBorder = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = eventBorder.decoration as BoxDecoration;
        expect(decoration.border!.top.color, const Color(0xFFBF5AF2));
      });
    });

    group('estado: volta melhor (nova session best após a primeira)', () {
      testWidgets('exibe símbolo ▲ na delta pill após nova session best', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        // Volta 1 — lenta: espera 200ms para lapMs > 0
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap(); // lapMs ≈ 200 → primeira session best
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2 — rápida: lapMs reseta para 0 após a volta
        // como o timer ainda não avançou, lapMs = 0 < bestLapMs → voltaMelhor
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final delta = find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.startsWith('▲'),
        );
        expect(delta, findsOneWidget);
      });

      testWidgets('borda exibe cor verde (#00E676) após nova session best', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final eventBorder = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = eventBorder.decoration as BoxDecoration;
        expect(decoration.border!.top.color, const Color(0xFF00E676));
      });
    });

    group('estado: volta pior', () {
      testWidgets('exibe símbolo ▼ na delta pill quando volta é pior que best', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        // Volta 1 — rápida: lapMs = 0 → primeira session best
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2 — lenta: espera 200ms para lapMs > 0 > bestLapMs(0) → voltaPior
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final delta = find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.startsWith('▼'),
        );
        expect(delta, findsOneWidget);
      });

      testWidgets('borda exibe cor vermelha (#FF3B30) quando volta é pior', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap(); // lapMs = 0, bestLapMs = 0
        await tester.pump(const Duration(milliseconds: 1));

        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap(); // lapMs = 200 > 0 → voltaPior
        await tester.pump(const Duration(milliseconds: 1));

        final eventBorder = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = eventBorder.decoration as BoxDecoration;
        expect(decoration.border!.top.color, const Color(0xFFFF3B30));
      });
    });

    group('estado: personal record', () {
      testWidgets('exibe banner PERSONAL RECORD ao bater o PR', (tester) async {
        final detector = _FakeDetector();
        // PR threshold alto: qualquer volta abaixo de 999999ms é PR
        await tester.pumpWidget(
          _buildScreen(detector: detector, prThresholdMs: 999999),
        );

        // Volta 1 — lenta: lapMs = 200, primeira session best
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2 — rápida: lapMs = 0 < 200 = bestLapMs E < 999999 = PR → personalRecord
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('PERSONAL RECORD'), findsOneWidget);
      });

      testWidgets('exibe símbolo ▲ na delta pill ao bater PR', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(
          _buildScreen(detector: detector, prThresholdMs: 999999),
        );

        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final delta = find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.startsWith('▲'),
        );
        expect(delta, findsOneWidget);
      });
    });

    group('setores', () {
      testWidgets('setor S1 exibe tempo após SectorCrossedEvent(0)', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        await tester.pump(const Duration(milliseconds: 300));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

        // Deve haver pelo menos um tempo no formato XX.XXX (setor S1 preenchido)
        final sectorTime = find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              RegExp(r'^\d+\.\d{3}$').hasMatch(w.data!),
        );
        expect(sectorTime, findsWidgets);
      });

      testWidgets('setores resetam para — após nova volta', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        await tester.pump(const Duration(milliseconds: 100));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Após cruzar S/C, todos os setores resetam para '—'
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != null &&
                RegExp(r'^\d+\.\d{3}$').hasMatch(w.data!),
          ),
          findsNothing,
        );
      });
    });

    group('botão FINALIZAR', () {
      testWidgets('toque em FINALIZAR exibe dialog de confirmação', (tester) async {
        await tester.pumpWidget(_buildScreen());

        await tester.tap(find.text('FINALIZAR'));
        await tester.pumpAndSettle();

        expect(find.text('FINALIZAR CORRIDA?'), findsOneWidget);
      });

      testWidgets('dialog exibe botões CONTINUAR e FINALIZAR', (tester) async {
        await tester.pumpWidget(_buildScreen());

        await tester.tap(find.text('FINALIZAR'));
        await tester.pumpAndSettle();

        expect(find.text('CONTINUAR'), findsOneWidget);
        expect(find.text('FINALIZAR'), findsWidgets);
      });

      testWidgets('toque em CONTINUAR fecha o dialog sem sair da tela', (tester) async {
        await tester.pumpWidget(_buildScreen());

        await tester.tap(find.text('FINALIZAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('CONTINUAR'));
        await tester.pumpAndSettle();

        expect(find.text('FINALIZAR CORRIDA?'), findsNothing);
        expect(find.text('TEMPO DA VOLTA'), findsOneWidget);
      });

      testWidgets('toque em FINALIZAR no dialog sai da tela', (tester) async {
        await tester.pumpWidget(_buildScreen());

        await tester.tap(find.text('FINALIZAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('FINALIZAR').last);
        await tester.pumpAndSettle();

        expect(find.text('TEMPO DA VOLTA'), findsNothing);
      });
    });
  });
}
