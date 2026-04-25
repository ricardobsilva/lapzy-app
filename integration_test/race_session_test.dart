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

        app.main();
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

        app.main();
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

        app.main();
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

        app.main();
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

        app.main();
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

        app.main();
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

        app.main();
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

        app.main();
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

        app.main();
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

        app.main();
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

        app.main();
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

    group('CA-RACE-004: feedback visual de borda por estado de volta', () {
      testWidgets(
          'CA-RACE-004-01: estado inicial não exibe borda colorida (neutro)',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista Borda'));

        app.main();
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

        app.main();
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

    group('botão FINALIZAR com confirmação', () {
      testWidgets('toque em FINALIZAR abre dialog de confirmação',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track Z'));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track Z'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('FINALIZAR'));
        await tester.pumpAndSettle();

        expect(find.text('FINALIZAR CORRIDA?'), findsOneWidget);

        TrackRepository().clearForTesting();
      });

      testWidgets('toque em CONTINUAR mantém tela de corrida ativa',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track W'));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track W'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('FINALIZAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('CONTINUAR'));
        await tester.pumpAndSettle();

        expect(find.byType(RaceScreen), findsOneWidget);
        expect(find.text('FINALIZAR CORRIDA?'), findsNothing);

        TrackRepository().clearForTesting();
      });

      testWidgets('confirmar FINALIZAR retorna para tela anterior',
          (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track V'));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track V'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('FINALIZAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('FINALIZAR').last);
        await tester.pumpAndSettle();

        expect(find.byType(RaceScreen), findsNothing);
        expect(find.text('INICIAR'), findsOneWidget);

        TrackRepository().clearForTesting();
      });
    });
  });
}
