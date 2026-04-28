import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/race_session.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/screens/race_summary_screen.dart';

const _trackTest = Track(id: 'test', name: 'Pista Teste');

const _lapA = LapResult(lapMs: 83887, s1Ms: 28441, s2Ms: 31203, s3Ms: 24243);
const _lapB = LapResult(lapMs: 85441, s1Ms: 29000, s2Ms: 32000, s3Ms: 24441);
const _lapC = LapResult(lapMs: 83654);

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

      testWidgets('exibe contagem de voltas correta', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapA, _lapB],
        ));

        final lapCountWidget = tester.widget<Text>(
          find.byKey(const Key('summary_lap_count')),
        );
        expect(lapCountWidget.data, '2');
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
        expect(find.text('—'), findsOneWidget);
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

      testWidgets('badge PR marcado na volta que é a melhor', (tester) async {
        await tester.pumpWidget(_buildScreen(
          laps: [_lapB, _lapA],
          bestLapMs: _lapA.lapMs,
        ));

        expect(find.text('PR'), findsOneWidget);
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
  });
}
