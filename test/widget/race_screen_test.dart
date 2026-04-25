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

/// Pista sem setores (pista mínima).
const _trackNoSectors = Track(id: 'test', name: 'Test Track');

/// Pista com 3 setores.
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
  _FakeDetector? detector,
  int? prThresholdMs,
  Track track = _trackNoSectors,
}) {
  final d = detector ?? _FakeDetector();
  return MaterialApp(
    home: RaceScreen(
      track: track,
      prThresholdMs: prThresholdMs,
      detectorFactory: (_) => d,
    ),
  );
}

// ── TESTES ────────────────────────────────────────────────────────────────────

void main() {
  group('RaceScreen', () {
    group('estado inicial (antes do 1º cruzamento)', () {
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

      testWidgets('timer exibe 0:00.000 ao abrir a tela', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('0:00.000'), findsOneWidget);
      });

      testWidgets('não exibe banner PERSONAL RECORD no início', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('PERSONAL RECORD'), findsNothing);
      });
    });

    group('CA-RACE-002-01: cronômetro inicia somente no 1º cruzamento', () {
      testWidgets('timer permanece em 0:00.000 antes do 1º cruzamento', (tester) async {
        await tester.pumpWidget(_buildScreen());

        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('0:00.000'), findsOneWidget);
      });

      testWidgets('timer avança após o 1º cruzamento', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap(); // 1º cruzamento → inicia cronômetro
        await tester.pump(const Duration(milliseconds: 1));

        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('0:00.000'), findsNothing);
      });

      testWidgets('timer atualiza a >= 10Hz (tick <= 100ms)', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Avança 100ms — deve ter exibido ao menos um valor diferente de 0:00.000
        await tester.pump(const Duration(milliseconds: 100));

        // Timer interno usa tick de 50ms (20Hz), logo 100ms já acumulou 100ms
        expect(find.text('0:00.100'), findsOneWidget);
      });
    });

    group('CA-RACE-002-03: 1ª volta sem delta, LapNumber = 1', () {
      testWidgets('não exibe delta antes do 1º cruzamento', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(
          find.byWidgetPredicate(
            (w) => w is Text && w.data != null &&
                (w.data!.startsWith('▲') || w.data!.startsWith('▼') || w.data == 'MELHOR'),
          ),
          findsNothing,
        );
      });

      testWidgets('LapNumber exibe 1 antes do 1º cruzamento', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('1'), findsOneWidget);
      });

      testWidgets('1º cruzamento inicia timer sem completar volta e sem exibir delta', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap(); // 1º cruzamento — apenas inicia
        await tester.pump(const Duration(milliseconds: 1));

        expect(
          find.byWidgetPredicate(
            (w) => w is Text && w.data != null &&
                (w.data!.startsWith('▲') || w.data!.startsWith('▼') || w.data == 'MELHOR'),
          ),
          findsNothing,
        );
      });

      testWidgets('LapNumber permanece 1 após o 1º cruzamento', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('1'), findsOneWidget);
      });
    });

    group('CA-RACE-002-02: delta a partir da 2ª volta', () {
      testWidgets('exibe MELHOR após 2º cruzamento (1ª volta completa)', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap(); // 1º — inicia
        await tester.pump(const Duration(milliseconds: 1));

        await tester.pump(const Duration(milliseconds: 100));
        detector.fireLap(); // 2º — completa volta 1
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('MELHOR'), findsOneWidget);
      });

      testWidgets('LapNumber avança para 2 após 2º cruzamento', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('exibe ▲ verde após 3º cruzamento quando volta melhora', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        // Volta 1 lenta: 200ms
        detector.fireLap(); // inicia
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap(); // completa volta 1 com 200ms
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2 rápida: quase 0ms
        detector.fireLap(); // completa volta 2 com ~0ms → session best
        await tester.pump(const Duration(milliseconds: 1));

        expect(
          find.byWidgetPredicate(
            (w) => w is Text && w.data != null && w.data!.startsWith('▲'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('exibe ▼ vermelho após 3º cruzamento quando volta piora', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        // Volta 1 rápida: ~0ms → session best
        detector.fireLap(); // inicia
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap(); // completa volta 1 com ~0ms
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2 lenta: 200ms > 0ms → voltaPior
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        expect(
          find.byWidgetPredicate(
            (w) => w is Text && w.data != null && w.data!.startsWith('▼'),
          ),
          findsOneWidget,
        );
      });
    });

    group('borda colorida', () {
      testWidgets('borda exibe cor roxa (#BF5AF2) após 1ª volta completada', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap(); // inicia
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap(); // completa volta 1
        await tester.pump(const Duration(milliseconds: 1));

        final eventBorder = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = eventBorder.decoration as BoxDecoration;
        expect(decoration.border!.top.color, const Color(0xFFBF5AF2));
      });

      testWidgets('borda exibe cor verde (#00E676) após nova session best', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        // Volta 1 lenta
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2 rápida → voltaMelhor
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final eventBorder = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = eventBorder.decoration as BoxDecoration;
        expect(decoration.border!.top.color, const Color(0xFF00E676));
      });

      testWidgets('borda exibe cor vermelha (#FF3B30) quando volta é pior', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        // Volta 1 rápida → session best
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2 lenta → voltaPior
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final eventBorder = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = eventBorder.decoration as BoxDecoration;
        expect(decoration.border!.top.color, const Color(0xFFFF3B30));
      });
    });

    group('personal record', () {
      testWidgets('exibe banner PERSONAL RECORD ao bater o PR', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(
          _buildScreen(detector: detector, prThresholdMs: 999999),
        );

        // Volta 1 lenta
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2 rápida → personalRecord
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('PERSONAL RECORD'), findsOneWidget);
      });

      testWidgets('exibe símbolo ▲ na delta pill ao bater PR', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(
          _buildScreen(detector: detector, prThresholdMs: 999999),
        );

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        expect(
          find.byWidgetPredicate(
            (w) => w is Text && w.data != null && w.data!.startsWith('▲'),
          ),
          findsOneWidget,
        );
      });
    });

    group('grid de setor', () {
      testWidgets('não exibe células de setor quando pista não tem setores', (tester) async {
        await tester.pumpWidget(_buildScreen(track: _trackNoSectors));

        expect(find.text('S1'), findsNothing);
        expect(find.text('S2'), findsNothing);
        expect(find.text('S3'), findsNothing);
      });

      testWidgets('exibe células S1, S2, S3 quando pista tem 3 setores', (tester) async {
        await tester.pumpWidget(_buildScreen(track: _trackWithSectors));

        expect(find.text('S1'), findsOneWidget);
        expect(find.text('S2'), findsOneWidget);
        expect(find.text('S3'), findsOneWidget);
      });

      testWidgets('setor S1 exibe tempo após 1º cruzamento e SectorCrossedEvent(0)', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(
          detector: detector,
          track: _trackWithSectors,
        ));

        detector.fireLap(); // 1º cruzamento: inicia
        await tester.pump(const Duration(milliseconds: 1));

        await tester.pump(const Duration(milliseconds: 300));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

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
        await tester.pumpWidget(_buildScreen(
          detector: detector,
          track: _trackWithSectors,
        ));

        detector.fireLap(); // inicia
        await tester.pump(const Duration(milliseconds: 1));

        await tester.pump(const Duration(milliseconds: 100));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

        detector.fireLap(); // completa volta 1
        await tester.pump(const Duration(milliseconds: 1));

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

      testWidgets('evento de setor antes do 1º cruzamento não registra tempo', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(
          detector: detector,
          track: _trackWithSectors,
        ));

        // Dispara setor SEM ter cruzado a linha antes
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

        // Nenhum tempo deve aparecer nos badges
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
