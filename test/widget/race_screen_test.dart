import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:lapzy/screens/race_screen.dart';
import 'package:lapzy/services/lap_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      testWidgets('exibe label TOTAL', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('TOTAL'), findsOneWidget);
      });

      testWidgets('total exibe — antes de iniciar a corrida', (tester) async {
        await tester.pumpWidget(_buildScreen());

        final totalTime = tester.widget<Text>(
          find.byKey(const Key('race_total_time')),
        );
        expect(totalTime.data, '—');
      });
    });

    group('tempo total de corrida', () {
      testWidgets('total acumula soma das voltas completadas', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        // Volta 1: 200ms
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2: 100ms
        await tester.pump(const Duration(milliseconds: 100));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Total esperado: 200 + 100 + 0 (lapMs reset imediato) = 300ms
        final totalTime = tester.widget<Text>(
          find.byKey(const Key('race_total_time')),
        );
        expect(totalTime.data, '0:00.300');
      });

      testWidgets('total exibe tempo corrente após 1º cruzamento', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 100));

        final totalTime = tester.widget<Text>(
          find.byKey(const Key('race_total_time')),
        );
        expect(totalTime.data, isNot('—'));
        expect(totalTime.data, '0:00.100');
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
        // Verifica via key do lap timer (não via texto, pois o total também exibe o mesmo valor)
        final lapTimer = tester.widget<Text>(find.byKey(const Key('race_lap_time')));
        expect(lapTimer.data, '0:00.100');
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

    group('CA-RACE-003: feedback de borda de setor vs volta anterior', () {
      testWidgets('borda de S1 fica verde quando setor atual é mais rápido que o anterior', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector, track: _trackWithSectors));

        // Volta 1: S1 cruzado com _lapMs ~300ms
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap(); // completa volta 1
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2: S1 cruzado com _lapMs ~100ms (mais rápido)
        await tester.pump(const Duration(milliseconds: 100));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

        final cell = tester.widget<Container>(find.byKey(const Key('sector_cell_s1')));
        final deco = cell.decoration as BoxDecoration;
        expect(deco.border!.top.color, const Color(0xFF00E676));
      });

      testWidgets('borda de S1 fica vermelha quando setor atual é mais lento que o anterior', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector, track: _trackWithSectors));

        // Volta 1: S1 em ~100ms
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 100));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2: S1 em ~300ms (mais lento)
        await tester.pump(const Duration(milliseconds: 300));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

        final cell = tester.widget<Container>(find.byKey(const Key('sector_cell_s1')));
        final deco = cell.decoration as BoxDecoration;
        expect(deco.border!.top.color, const Color(0xFFFF3B30));
      });

      testWidgets('borda de feedback desaparece após 5s', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector, track: _trackWithSectors));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        await tester.pump(const Duration(milliseconds: 100));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

        // Borda verde ativa imediatamente
        final cellBefore = tester.widget<Container>(find.byKey(const Key('sector_cell_s1')));
        expect((cellBefore.decoration as BoxDecoration).border!.top.color, const Color(0xFF00E676));

        // Após 5s a borda volta ao estado normal do setor
        await tester.pump(const Duration(seconds: 5));

        final cellAfter = tester.widget<Container>(find.byKey(const Key('sector_cell_s1')));
        final borderColor = (cellAfter.decoration as BoxDecoration).border!.top.color;
        expect(borderColor, isNot(const Color(0xFF00E676)));
        expect(borderColor, isNot(const Color(0xFFFF3B30)));
      });

      testWidgets('sem volta anterior não exibe borda de feedback', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector, track: _trackWithSectors));

        // Apenas a 1ª volta, sem volta anterior para comparar
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

        final cell = tester.widget<Container>(find.byKey(const Key('sector_cell_s1')));
        final borderColor = (cell.decoration as BoxDecoration).border!.top.color;
        expect(borderColor, isNot(const Color(0xFF00E676)));
        expect(borderColor, isNot(const Color(0xFFFF3B30)));
      });

      testWidgets('feedback é limpo ao completar nova volta', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector, track: _trackWithSectors));

        // Volta 1: S1 em ~300ms
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Volta 2: S1 em ~100ms → borda verde ativa
        await tester.pump(const Duration(milliseconds: 100));
        detector.fireSector(0);
        await tester.pump(const Duration(milliseconds: 1));

        // Completa volta 2 → feedback deve ser limpo
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final cell = tester.widget<Container>(find.byKey(const Key('sector_cell_s1')));
        final borderColor = (cell.decoration as BoxDecoration).border!.top.color;
        expect(borderColor, isNot(const Color(0xFF00E676)));
        expect(borderColor, isNot(const Color(0xFFFF3B30)));
      });

      testWidgets('CA-RACE-003-04: pista sem setores não exibe badges de setor', (tester) async {
        await tester.pumpWidget(_buildScreen(track: _trackNoSectors));

        expect(find.text('S1'), findsNothing);
        expect(find.text('S2'), findsNothing);
        expect(find.text('S3'), findsNothing);
      });
    });

    group('CA-RACE-004-01: borda vermelha com stroke-width >= 8 quando volta é pior', () {
      testWidgets('borda tem stroke-width >= 8', (tester) async {
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

        final container = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border!.top.width, greaterThanOrEqualTo(8.0));
      });

      testWidgets('borda tem cor #FF3B30 quando volta é pior', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final container = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border!.top.color, const Color(0xFFFF3B30));
      });
    });

    group('CA-RACE-004-02: melhor volta da sessão exibe borda roxa e texto MELHOR', () {
      testWidgets('borda tem cor #BF5AF2 após 1ª volta completada', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final container = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border!.top.color, const Color(0xFFBF5AF2));
      });

      testWidgets('DeltaDisplay exibe texto MELHOR', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.text('MELHOR'), findsOneWidget);
      });
    });

    group('CA-RACE-004-03: Personal Record exibe borda verde com pulso e banner PR', () {
      testWidgets('borda tem cor #00E676 ao bater PR', (tester) async {
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

        final container = tester.widget<Container>(
          find.byKey(const Key('race_event_border')),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.border!.top.color, const Color(0xFF00E676));
      });

      testWidgets('borda tem animação de pulso (Opacity) ao bater PR', (tester) async {
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

        // Opacity widget deve envolver a borda no estado PR
        final opacityFinder = find.ancestor(
          of: find.byKey(const Key('race_event_border')),
          matching: find.byType(Opacity),
        );
        expect(opacityFinder, findsOneWidget);
      });

      testWidgets('borda NÃO tem Opacity para estado voltaPior', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        final opacityFinder = find.ancestor(
          of: find.byKey(const Key('race_event_border')),
          matching: find.byType(Opacity),
        );
        expect(opacityFinder, findsNothing);
      });

      testWidgets('banner PERSONAL RECORD visível ao bater PR', (tester) async {
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

        expect(find.text('PERSONAL RECORD'), findsOneWidget);
      });

      testWidgets('DeltaDisplay exibe ▲ ao bater PR', (tester) async {
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

    group('CA-RACE-004-04: borda retorna ao estado neutro após 3s', () {
      testWidgets('borda desaparece após 3s sem novo evento', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap(); // completa volta 1 → melhorVolta
        await tester.pump(const Duration(milliseconds: 1));

        // Borda visível logo após o evento
        expect(find.byKey(const Key('race_event_border')), findsOneWidget);

        // Avança 3s → timer dispara → borda some
        await tester.pump(const Duration(seconds: 3));

        expect(find.byKey(const Key('race_event_border')), findsNothing);
      });

      testWidgets('borda ainda visível antes de 3s', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Avança apenas 2s
        await tester.pump(const Duration(seconds: 2));

        expect(find.byKey(const Key('race_event_border')), findsOneWidget);
      });

      testWidgets('nova volta reinicia o timer de 3s', (tester) async {
        final detector = _FakeDetector();
        await tester.pumpWidget(_buildScreen(detector: detector));

        // Volta 1 lenta
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 200));
        detector.fireLap(); // completa volta 1
        await tester.pump(const Duration(milliseconds: 1));

        // Espera 2s (menos de 3s desde volta 1)
        await tester.pump(const Duration(seconds: 2));

        // Completa volta 2 — reinicia o timer de 3s
        detector.fireLap();
        await tester.pump(const Duration(milliseconds: 1));

        // Avança mais 2s desde volta 2 (4s desde volta 1, mas apenas 2s desde volta 2)
        await tester.pump(const Duration(seconds: 2));

        // Borda ainda visível pois o timer foi reiniciado
        expect(find.byKey(const Key('race_event_border')), findsOneWidget);

        // Avança mais 1s (3s desde volta 2)
        await tester.pump(const Duration(seconds: 1));

        // Agora a borda desapareceu
        expect(find.byKey(const Key('race_event_border')), findsNothing);
      });
    });

    group('CA-END-001-01: pressionar e segurar 3s o botão FINALIZAR encerra a corrida', () {
      testWidgets('botão FINALIZAR existe na tela no estado inicial', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.text('FINALIZAR'), findsOneWidget);
      });

      testWidgets('pressionar inicia o fill do botão', (tester) async {
        await tester.pumpWidget(_buildScreen());

        final buttonFinder = find.byKey(const Key('end_button'));
        final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
        await tester.pump(); // registra o primeiro tick do AnimationController
        await tester.pump(const Duration(seconds: 1));

        final fractionBox = tester.widget<FractionallySizedBox>(
          find.descendant(of: buttonFinder, matching: find.byType(FractionallySizedBox)),
        );
        expect(fractionBox.widthFactor, greaterThan(0.0));
        expect(fractionBox.widthFactor, lessThan(1.0));

        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('segurar 3s encerra a corrida sem exibir dialog', (tester) async {
        SharedPreferences.setMockInitialValues({});
        RaceSessionRepository().clearForTesting();

        await tester.pumpWidget(_buildScreen());

        final buttonFinder = find.byKey(const Key('end_button'));
        final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        expect(find.byType(RaceScreen), findsNothing);
        expect(find.text('FINALIZAR CORRIDA?'), findsNothing);
        await gesture.up();
        RaceSessionRepository().clearForTesting();
      });

      testWidgets('soltar antes de 3s não encerra a corrida', (tester) async {
        SharedPreferences.setMockInitialValues({});
        RaceSessionRepository().clearForTesting();

        await tester.pumpWidget(_buildScreen());

        final buttonFinder = find.byKey(const Key('end_button'));
        final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
        await tester.pump(const Duration(seconds: 1));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.byType(RaceScreen), findsOneWidget);
        RaceSessionRepository().clearForTesting();
      });

      testWidgets('soltar antes de 3s reverte o fill para zero', (tester) async {
        await tester.pumpWidget(_buildScreen());

        final buttonFinder = find.byKey(const Key('end_button'));
        final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
        await tester.pump(const Duration(seconds: 1));
        await gesture.up();
        await tester.pumpAndSettle();

        final fractionBox = tester.widget<FractionallySizedBox>(
          find.descendant(of: buttonFinder, matching: find.byType(FractionallySizedBox)),
        );
        expect(fractionBox.widthFactor, 0.0);
      });
    });
  });
}
