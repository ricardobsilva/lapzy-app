import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/track_repository.dart';
import 'package:lapzy/screens/race_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tela de Corrida', () {
    group('navegação', () {
      testWidgets(
          'fluxo: home → INICIAR → seleciona pista → tela de corrida abre',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista Teste'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Teste'));
        await tester.pumpAndSettle();

        expect(find.byType(RaceScreen), findsOneWidget);

        TrackRepository().clearForTesting();
      });

      testWidgets('tela de corrida exibe TEMPO DA VOLTA após abrir',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Granja Viana'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Granja Viana'));
        await tester.pumpAndSettle();

        expect(find.text('TEMPO DA VOLTA'), findsOneWidget);

        TrackRepository().clearForTesting();
      });

      testWidgets('tela de corrida exibe botão FINALIZAR', (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista A'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista A'));
        await tester.pumpAndSettle();

        expect(find.text('FINALIZAR'), findsOneWidget);

        TrackRepository().clearForTesting();
      });

      testWidgets('sheet fecha ao navegar para tela de corrida', (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista B'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista B'));
        await tester.pumpAndSettle();

        expect(find.text('SELECIONAR PISTA'), findsNothing);

        TrackRepository().clearForTesting();
      });
    });

    group('CA-RACE-002: cronômetro e delta (estado inicial)', () {
      testWidgets(
          'CA-RACE-002-01: timer exibe 0:00.000 ao abrir tela (antes do 1º cruzamento)',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista Timer'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Timer'));
        await tester.pumpAndSettle();

        expect(find.text('0:00.000'), findsOneWidget);

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-RACE-002-03: LapNumber exibe 1 ao abrir tela',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista Lap'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Lap'));
        await tester.pumpAndSettle();

        expect(find.text('1'), findsOneWidget);

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-RACE-002-03: sem delta exibido ao abrir tela',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista Delta'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Delta'));
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != null &&
                (w.data!.startsWith('▲') ||
                    w.data!.startsWith('▼') ||
                    w.data == 'MELHOR'),
          ),
          findsNothing,
        );

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-RACE-002-01: timer permanece em 0:00.000 enquanto aguarda 1º cruzamento',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista Freeze'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Freeze'));
        await tester.pumpAndSettle();

        // Aguarda sem cruzar linha — timer deve permanecer congelado
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('0:00.000'), findsOneWidget);

        TrackRepository().clearForTesting();
      });
    });

    group('layout landscape', () {
      testWidgets('exibe labels VOLTA e MELHOR VOLTA', (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track X'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track X'));
        await tester.pumpAndSettle();

        expect(find.text('VOLTA'), findsOneWidget);
        expect(find.text('MELHOR VOLTA'), findsOneWidget);

        TrackRepository().clearForTesting();
      });

      testWidgets('não exibe células de setor para pista sem setores definidos',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track Y'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track Y'));
        await tester.pumpAndSettle();

        expect(find.text('S1'), findsNothing);
        expect(find.text('S2'), findsNothing);
        expect(find.text('S3'), findsNothing);

        TrackRepository().clearForTesting();
      });

      testWidgets('exibe células S1, S2, S3 para pista com 3 setores',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(
          id: '2',
          name: 'Track Z Setores',
          sectorBoundaries: [
            TrackLine(
              a: GeoPoint(-23.50, -46.63),
              b: GeoPoint(-23.50, -46.62),
            ),
            TrackLine(
              a: GeoPoint(-23.49, -46.63),
              b: GeoPoint(-23.49, -46.62),
            ),
            TrackLine(
              a: GeoPoint(-23.48, -46.63),
              b: GeoPoint(-23.48, -46.62),
            ),
          ],
        ));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track Z Setores'));
        await tester.pumpAndSettle();

        expect(find.text('S1'), findsOneWidget);
        expect(find.text('S2'), findsOneWidget);
        expect(find.text('S3'), findsOneWidget);

        TrackRepository().clearForTesting();
      });
    });

    group('CA-RACE-003: tempos parciais por setor em tempo real', () {
      testWidgets(
          'CA-RACE-003-04: pista sem setores não exibe badges S1/S2/S3',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista Sem Setores'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Sem Setores'));
        await tester.pumpAndSettle();

        expect(find.text('S1'), findsNothing);
        expect(find.text('S2'), findsNothing);
        expect(find.text('S3'), findsNothing);

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-RACE-003: pista com 3 setores exibe badges S1, S2 e S3',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(
          id: '3',
          name: 'Pista Com Setores',
          sectorBoundaries: [
            TrackLine(a: GeoPoint(-23.50, -46.63), b: GeoPoint(-23.50, -46.62)),
            TrackLine(a: GeoPoint(-23.49, -46.63), b: GeoPoint(-23.49, -46.62)),
            TrackLine(a: GeoPoint(-23.48, -46.63), b: GeoPoint(-23.48, -46.62)),
          ],
        ));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Com Setores'));
        await tester.pumpAndSettle();

        expect(find.text('S1'), findsOneWidget);
        expect(find.text('S2'), findsOneWidget);
        expect(find.text('S3'), findsOneWidget);

        TrackRepository().clearForTesting();
      });
    });

    group('CA-RACE-004: feedback visual de borda por estado de volta', () {
      testWidgets(
          'CA-RACE-004-01: estado inicial não exibe borda colorida (neutro)',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista Borda'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Borda'));
        await tester.pumpAndSettle();

        // Estado neutro: sem borda colorida visível
        expect(find.byKey(const Key('race_event_border')), findsNothing);

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-RACE-004-04: após aguardar sem eventos, borda permanece ausente',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista Neutro'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Neutro'));
        await tester.pumpAndSettle();

        // Aguarda mais de 3s sem nenhum cruzamento
        await tester.pump(const Duration(seconds: 4));

        expect(find.byKey(const Key('race_event_border')), findsNothing);

        TrackRepository().clearForTesting();
      });
    });

    group('CA-END-001: encerramento anti-acidental', () {
      testWidgets(
          'CA-END-001-01: swipe da borda direita revela botão FINALIZAR em destaque',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track End'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track End'));
        await tester.pumpAndSettle();

        final screenWidth =
            tester.getSize(find.byType(RaceScreen)).width;
        await tester.dragFrom(
          Offset(screenWidth - 5, 200),
          const Offset(-50, 0),
        );
        await tester.pump();

        final button = tester.widget<AnimatedContainer>(
          find.byKey(const Key('end_button')),
        );
        final deco = button.decoration as BoxDecoration;
        expect(deco.color, const Color(0xFFFF3B30));

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-END-001-01: botão está no estado opaco antes do swipe',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track Opaque'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track Opaque'));
        await tester.pumpAndSettle();

        final button = tester.widget<AnimatedContainer>(
          find.byKey(const Key('end_button')),
        );
        final deco = button.decoration as BoxDecoration;
        expect(deco.color, isNot(const Color(0xFFFF3B30)));

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-END-001-02: botão em destaque retorna ao estado opaco após 3s',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track Timer'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track Timer'));
        await tester.pumpAndSettle();

        final screenWidth =
            tester.getSize(find.byType(RaceScreen)).width;
        await tester.dragFrom(
          Offset(screenWidth - 5, 200),
          const Offset(-50, 0),
        );
        await tester.pump();

        await tester.pump(const Duration(seconds: 3));

        final button = tester.widget<AnimatedContainer>(
          find.byKey(const Key('end_button')),
        );
        expect(
          (button.decoration as BoxDecoration).color,
          isNot(const Color(0xFFFF3B30)),
        );

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-END-001-03: toque no botão revelado encerra a corrida sem dialog',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track Fim'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track Fim'));
        await tester.pumpAndSettle();

        final screenWidth =
            tester.getSize(find.byType(RaceScreen)).width;
        await tester.dragFrom(
          Offset(screenWidth - 5, 200),
          const Offset(-50, 0),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('end_button')));
        await tester.pumpAndSettle();

        expect(find.text('FINALIZAR CORRIDA?'), findsNothing);
        expect(find.byType(RaceScreen), findsNothing);

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-END-001-04: ResumoScreen exibe dados da sessão após encerramento',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository()
            .add(const Track(id: '1', name: 'Pista Resumo'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Resumo'));
        await tester.pumpAndSettle();

        final screenWidth =
            tester.getSize(find.byType(RaceScreen)).width;
        await tester.dragFrom(
          Offset(screenWidth - 5, 200),
          const Offset(-50, 0),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('end_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('summary_title')), findsOneWidget);
        expect(find.byKey(const Key('summary_track_name')), findsOneWidget);
        expect(find.text('Pista Resumo'), findsOneWidget);

        TrackRepository().clearForTesting();
      });

      testWidgets(
          'CA-END-001-04: ResumoScreen NÃO exibe botão Descartar',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository()
            .add(const Track(id: '1', name: 'Track SemDescartar'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track SemDescartar'));
        await tester.pumpAndSettle();

        final screenWidth =
            tester.getSize(find.byType(RaceScreen)).width;
        await tester.dragFrom(
          Offset(screenWidth - 5, 200),
          const Offset(-50, 0),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('end_button')));
        await tester.pumpAndSettle();

        expect(find.text('DESCARTAR'), findsNothing);
        expect(find.text('Descartar'), findsNothing);

        TrackRepository().clearForTesting();
      });
    });
  });
}
