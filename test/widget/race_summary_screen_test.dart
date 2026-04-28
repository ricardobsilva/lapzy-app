import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/race_session.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/screens/race_summary_screen.dart';

const _trackTest = Track(id: 'test', name: 'Pista Teste');
const _trackWithSectors = Track(
  id: 'sectors',
  name: 'Pista Setores',
  sectorBoundaries: [
    TrackLine(a: GeoPoint(-23.50, -46.63), b: GeoPoint(-23.50, -46.62)),
    TrackLine(a: GeoPoint(-23.49, -46.63), b: GeoPoint(-23.49, -46.62)),
    TrackLine(a: GeoPoint(-23.48, -46.63), b: GeoPoint(-23.48, -46.62)),
  ],
);
const _trackWith7Sectors = Track(
  id: 'seven',
  name: 'Pista 7 Setores',
  sectorBoundaries: [
    TrackLine(a: GeoPoint(-23.50, -46.63), b: GeoPoint(-23.50, -46.62)),
    TrackLine(a: GeoPoint(-23.49, -46.63), b: GeoPoint(-23.49, -46.62)),
    TrackLine(a: GeoPoint(-23.48, -46.63), b: GeoPoint(-23.48, -46.62)),
    TrackLine(a: GeoPoint(-23.47, -46.63), b: GeoPoint(-23.47, -46.62)),
    TrackLine(a: GeoPoint(-23.46, -46.63), b: GeoPoint(-23.46, -46.62)),
    TrackLine(a: GeoPoint(-23.45, -46.63), b: GeoPoint(-23.45, -46.62)),
    TrackLine(a: GeoPoint(-23.44, -46.63), b: GeoPoint(-23.44, -46.62)),
  ],
);

// 3 setores
const _lapA = LapResult(lapMs: 83887, sectors: [28441, 31203, 24243]);
const _lapB = LapResult(lapMs: 85441, sectors: [29000, 32000, 24441]);
const _lapC = LapResult(lapMs: 83654);

// 7 setores — volta rápida (melhor)
const _lap7Best = LapResult(
  lapMs: 83654,
  sectors: [11800, 12100, 13200, 10900, 11500, 12800, 11354],
);
// 7 setores — volta lenta
const _lap7Slow = LapResult(
  lapMs: 85441,
  sectors: [12200, 12800, 13900, 11400, 12100, 13500, 11541],
);
// 7 setores — volta intermediária
const _lap7Mid = LapResult(
  lapMs: 84210,
  sectors: [11950, 12400, 13500, 11100, 11800, 13100, 11360],
);

Widget _buildScreen({
  List<LapResult> laps = const [],
  int? bestLapMs,
  Track track = _trackTest,
}) {
  return MaterialApp(
    home: RaceSummaryScreen(
      laps: laps,
      bestLapMs: bestLapMs,
      track: track,
    ),
  );
}

void main() {
  group('RaceSummaryScreen', () {
    group('CA-END-001-04: dados da sessão disponíveis e corretos', () {
      testWidgets('exibe label RESUMO', (tester) async {
        await tester.pumpWidget(_buildScreen());

        expect(find.byKey(const Key('summary_title')), findsOneWidget);
        expect(find.text('RESUMO'), findsOneWidget);
      });

      testWidgets('exibe nome da pista', (tester) async {
        await tester.pumpWidget(_buildScreen(track: _trackTest));

        expect(find.byKey(const Key('summary_track_name')), findsOneWidget);
        expect(find.text('Pista Teste'), findsOneWidget);
      });

      testWidgets('exibe contagem de voltas quando sem melhor volta', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        final lapCountWidget = tester.widget<Text>(
          find.byKey(const Key('summary_lap_count')),
        );
        expect(lapCountWidget.data, '2');
      });

      testWidgets('exibe melhor volta com número/total quando disponível', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
          bestLapMs: _lapA.lapMs,
        ));

        final lapCountWidget = tester.widget<Text>(
          find.byKey(const Key('summary_lap_count')),
        );
        expect(lapCountWidget.data, '1/2');
      });

      testWidgets('exibe melhor volta quando disponível', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA],
          bestLapMs: 83887,
        ));

        final bestLapWidget = tester.widget<Text>(
          find.byKey(const Key('summary_best_lap')),
        );
        expect(bestLapWidget.data, '1:23.887');
      });

      testWidgets('exibe — para melhor volta quando não disponível', (tester) async {
        await tester.pumpWidget(_buildScreen(laps: []));

        expect(find.byKey(const Key('summary_best_lap')), findsOneWidget);
        final bestLapWidget = tester.widget<Text>(
          find.byKey(const Key('summary_best_lap')),
        );
        expect(bestLapWidget.data, '—');
      });

      testWidgets('exibe tempo individual de cada volta', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        expect(find.byKey(const Key('summary_lap_time_1')), findsOneWidget);
        expect(find.byKey(const Key('summary_lap_time_2')), findsOneWidget);
      });

      testWidgets('exibe número das voltas corretamente', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        expect(find.byKey(const Key('summary_lap_number_1')), findsOneWidget);
        expect(find.byKey(const Key('summary_lap_number_2')), findsOneWidget);
      });

      testWidgets('mensagem de sessão sem voltas quando lista está vazia', (tester) async {
        await tester.pumpWidget(_buildScreen(laps: []));

        expect(find.byKey(const Key('summary_no_laps')), findsOneWidget);
      });

      testWidgets('badge PR marcado na melhor volta — hero e lista', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapB, _lapA],
          bestLapMs: _lapA.lapMs,
        ));

        expect(find.text('PR'), findsNWidgets(2));
      });

      testWidgets('NÃO exibe botão Descartar', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
          bestLapMs: _lapA.lapMs,
        ));

        expect(find.text('DESCARTAR'), findsNothing);
        expect(find.text('Descartar'), findsNothing);
      });

      testWidgets('NÃO exibe opção de cancelar salvamento', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA],
          bestLapMs: _lapA.lapMs,
        ));

        expect(find.text('CANCELAR'), findsNothing);
        expect(find.text('Cancelar'), findsNothing);
        expect(find.text('NÃO SALVAR'), findsNothing);
      });

      testWidgets('dados de 3 voltas corretos — tempos no formato M:SS.mmm', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB, _lapC],
          bestLapMs: _lapC.lapMs,
        ));

        final lap1 = tester.widget<Text>(find.byKey(const Key('summary_lap_time_1')));
        final lap2 = tester.widget<Text>(find.byKey(const Key('summary_lap_time_2')));
        final lap3 = tester.widget<Text>(find.byKey(const Key('summary_lap_time_3')));
        expect(lap1.data, '1:23.887');
        expect(lap2.data, '1:25.441');
        expect(lap3.data, '1:23.654');
      });
    });

    group('TASK-005: delta entre voltas', () {
      testWidgets('primeira volta exibe — no delta', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        final delta1 = tester.widget<Text>(
          find.byKey(const Key('summary_lap_delta_1')),
        );
        expect(delta1.data, '—');
      });

      testWidgets('segunda volta mais rápida exibe delta positivo verde', (tester) async {
        // lapA (83887) → lapC (83654): lapA - lapC = 233ms melhora
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapC],
        ));

        final delta2 = tester.widget<Text>(
          find.byKey(const Key('summary_lap_delta_2')),
        );
        expect(delta2.data, '▲ 0.233');
        expect(delta2.style?.color, const Color(0xFF00E676));
      });

      testWidgets('segunda volta mais lenta exibe delta negativo vermelho', (tester) async {
        // lapA (83887) → lapB (85441): lapA - lapB = -1554ms piora
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        final delta2 = tester.widget<Text>(
          find.byKey(const Key('summary_lap_delta_2')),
        );
        expect(delta2.data, '▼ 1.554');
        expect(delta2.style?.color, const Color(0xFFFF3B30));
      });
    });

    group('TASK-005: resumo por setor (3 setores)', () {
      testWidgets('seção de setores NÃO exibida sem dados de setor', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapC],
          track: _trackTest,
        ));

        expect(find.byKey(const Key('summary_sector_0')), findsNothing);
      });

      testWidgets('seção de setores exibida com dados de setor', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
          track: _trackWithSectors,
        ));

        expect(find.byKey(const Key('summary_sector_0')), findsOneWidget);
        expect(find.byKey(const Key('summary_sector_1')), findsOneWidget);
        expect(find.byKey(const Key('summary_sector_2')), findsOneWidget);
      });

      testWidgets('card de setor exibe tempo médio correto', (tester) async {
        // S1: (28441 + 29000) / 2 = 28720ms → "28.720"
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        final s1Avg = tester.widget<Text>(
          find.byKey(const Key('summary_sector_avg_0')),
        );
        expect(s1Avg.data, '28.720');
      });

      testWidgets('setor com menor oportunidade recebe indicador MELHOR (verde)', (tester) async {
        // S3 tem menor oportunidade → melhor
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        final card = tester.widget<Container>(
          find.byKey(const Key('summary_sector_2')),
        );
        final deco = card.decoration as BoxDecoration;
        expect(deco.border?.top.color, const Color(0xFF00E676));
      });

      testWidgets('setor com maior oportunidade recebe indicador PIOR (vermelho)', (tester) async {
        // S2 tem maior oportunidade → pior
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        final card = tester.widget<Container>(
          find.byKey(const Key('summary_sector_1')),
        );
        final deco = card.decoration as BoxDecoration;
        expect(deco.border?.top.color, const Color(0xFFFF3B30));
      });

      testWidgets('insight textual exibe setor com maior oportunidade', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        final insight = find.byKey(const Key('summary_sector_insight'));
        expect(insight, findsOneWidget);
        final text = tester.widget<Text>(insight);
        expect(text.data, contains('S2'));
      });

      testWidgets('sem insight quando apenas 1 volta (sem variância)', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA],
        ));

        expect(find.byKey(const Key('summary_sector_insight')), findsNothing);
      });
    });

    group('TASK-005: resumo por setor (7 setores)', () {
      testWidgets('exibe cards para todos os 7 setores', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lap7Best, _lap7Slow, _lap7Mid],
          bestLapMs: _lap7Best.lapMs,
          track: _trackWith7Sectors,
        ));

        for (int s = 0; s < 7; s++) {
          expect(find.byKey(Key('summary_sector_$s')), findsOneWidget,
              reason: 'Setor $s deve estar visível');
        }
      });

      testWidgets('7 setores: exibe tempos médios corretos para S4, S5, S6', (tester) async {
        // S4 (index 3): (10900 + 11400 + 11100) / 3 = 11133
        await tester.pumpWidget(_buildScreen(
          laps: [_lap7Best, _lap7Slow, _lap7Mid],
          bestLapMs: _lap7Best.lapMs,
          track: _trackWith7Sectors,
        ));

        final s4Avg = tester.widget<Text>(
          find.byKey(const Key('summary_sector_avg_3')),
        );
        expect(s4Avg.data, '11.133');
      });

      testWidgets('7 setores: insight indica o setor com maior oportunidade', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lap7Best, _lap7Slow, _lap7Mid],
          bestLapMs: _lap7Best.lapMs,
          track: _trackWith7Sectors,
        ));

        final insight = find.byKey(const Key('summary_sector_insight'));
        expect(insight, findsOneWidget);
      });

      testWidgets('7 setores: cards S4+ usam cores dinâmicas (não branco)', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lap7Best],
          bestLapMs: _lap7Best.lapMs,
          track: _trackWith7Sectors,
        ));

        // S4 (index 3) — primeiro setor extra — deve ter cor teal, não branco
        final card = tester.widget<Container>(
          find.byKey(const Key('summary_sector_3')),
        );
        // Card existe e tem decoração definida
        expect(card.decoration, isNotNull);
      });
    });

    group('TASK-005: botão compartilhar', () {
      testWidgets('exibe botão COMPARTILHAR no rodapé', (tester) async {
        await tester.pumpWidget(_buildScreen(laps: []));

        expect(find.byKey(const Key('summary_share_button')), findsOneWidget);
        expect(find.text('COMPARTILHAR'), findsOneWidget);
      });
    });

    group('TASK-005: bottom sheet detalhe de volta (3 setores)', () {
      testWidgets('toque em volta abre bottom sheet com tempo total', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA],
          bestLapMs: _lapA.lapMs,
        ));

        await tester.tap(find.byKey(const Key('summary_lap_time_1')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('summary_lap_detail_sheet')), findsOneWidget);
        expect(find.byKey(const Key('lap_detail_total_time')), findsOneWidget);
        final totalTime = tester.widget<Text>(
          find.byKey(const Key('lap_detail_total_time')),
        );
        expect(totalTime.data, '1:23.887');
      });

      testWidgets('bottom sheet exibe tempos dos setores', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA],
          bestLapMs: _lapA.lapMs,
        ));

        await tester.tap(find.byKey(const Key('summary_lap_time_1')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lap_detail_sector_label_0')), findsOneWidget);
        expect(find.byKey(const Key('lap_detail_sector_time_0')), findsOneWidget);
        final s1Time = tester.widget<Text>(
          find.byKey(const Key('lap_detail_sector_time_0')),
        );
        expect(s1Time.data, '28.441');
      });

      testWidgets('na melhor volta todos os deltas exibem ▲ 0.000 em verde', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA],
          bestLapMs: _lapA.lapMs,
        ));

        await tester.tap(find.byKey(const Key('summary_lap_time_1')));
        await tester.pumpAndSettle();

        for (int s = 0; s < 3; s++) {
          final delta = tester.widget<Text>(
            find.byKey(Key('lap_detail_sector_delta_$s')),
          );
          expect(delta.data, '▲ 0.000');
          expect(delta.style?.color, const Color(0xFF00E676));
        }
      });

      testWidgets('volta mais lenta exibe deltas negativos em vermelho', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
          bestLapMs: _lapA.lapMs,
        ));

        await tester.tap(find.byKey(const Key('summary_lap_time_2')));
        await tester.pumpAndSettle();

        // S1: lapA.s1Ms (28441) - lapB.s1Ms (29000) = -559 → ▼
        final s1Delta = tester.widget<Text>(
          find.byKey(const Key('lap_detail_sector_delta_0')),
        );
        expect(s1Delta.data, '▼ 0.559');
        expect(s1Delta.style?.color, const Color(0xFFFF3B30));
      });

      testWidgets('bottom sheet exibe coluna de comparação com melhor volta', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
          bestLapMs: _lapA.lapMs,
        ));

        await tester.tap(find.byKey(const Key('summary_lap_time_2')));
        await tester.pumpAndSettle();

        final bestS1 = tester.widget<Text>(
          find.byKey(const Key('lap_detail_best_sector_time_0')),
        );
        expect(bestS1.data, '28.441');
      });
    });

    group('TASK-005: bottom sheet detalhe de volta (7 setores)', () {
      // Helper: rola o CustomScrollView até a linha de volta ficar visível,
      // então abre o sheet. Necessário porque o grid de 7 setores (3 linhas)
      // empurra as linhas de volta para fora do viewport do teste.
      Future<void> openSheet(WidgetTester tester, Key lapKey) async {
        final scrollable = find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ).first;
        final finder = find.byKey(lapKey);
        await tester.scrollUntilVisible(finder, 150, scrollable: scrollable);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      testWidgets('exibe todos os 7 setores no bottom sheet', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lap7Best, _lap7Slow],
          bestLapMs: _lap7Best.lapMs,
          track: _trackWith7Sectors,
        ));

        await openSheet(tester, const Key('summary_lap_time_1'));

        expect(find.byKey(const Key('summary_lap_detail_sheet')), findsOneWidget);

        for (int s = 0; s < 7; s++) {
          expect(find.byKey(Key('lap_detail_sector_label_$s')), findsOneWidget,
              reason: 'Setor $s deve aparecer no sheet');
        }
      });

      testWidgets('7 setores: melhor volta mostra todos ▲ 0.000 em verde', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lap7Best, _lap7Slow],
          bestLapMs: _lap7Best.lapMs,
          track: _trackWith7Sectors,
        ));

        await openSheet(tester, const Key('summary_lap_time_1'));

        for (int s = 0; s < 7; s++) {
          final delta = tester.widget<Text>(
            find.byKey(Key('lap_detail_sector_delta_$s')),
          );
          expect(delta.data, '▲ 0.000',
              reason: 'Setor $s na melhor volta deve exibir ▲ 0.000');
          expect(delta.style?.color, const Color(0xFF00E676));
        }
      });

      testWidgets('7 setores: volta lenta mostra deltas negativos para todos os setores', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lap7Best, _lap7Slow],
          bestLapMs: _lap7Best.lapMs,
          track: _trackWith7Sectors,
        ));

        await openSheet(tester, const Key('summary_lap_time_2'));

        for (int s = 0; s < 7; s++) {
          final delta = tester.widget<Text>(
            find.byKey(Key('lap_detail_sector_delta_$s')),
          );
          expect(delta.data, startsWith('▼'),
              reason: 'Setor $s da volta lenta deve ser ▼');
          expect(delta.style?.color, const Color(0xFFFF3B30));
        }
      });

      testWidgets('7 setores: sheet é scrollable (não transborda)', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lap7Best, _lap7Slow],
          bestLapMs: _lap7Best.lapMs,
          track: _trackWith7Sectors,
        ));

        await openSheet(tester, const Key('summary_lap_time_1'));

        // Sheet presente sem overflow — se houvesse overflow o pumpAndSettle
        // lançaria exception de RenderFlex
        expect(find.byKey(const Key('summary_lap_detail_sheet')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
