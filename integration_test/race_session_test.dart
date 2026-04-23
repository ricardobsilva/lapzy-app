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

    group('layout landscape', () {
      testWidgets('exibe labels VOLTA, SETORES, MELHOR VOLTA', (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track X'));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track X'));
        await tester.pumpAndSettle();

        expect(find.text('VOLTA'), findsOneWidget);
        expect(find.text('SETORES'), findsOneWidget);
        expect(find.text('MELHOR VOLTA'), findsOneWidget);

        TrackRepository().clearForTesting();
      });

      testWidgets('exibe badges de setor S1, S2, S3', (tester) async {
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Track Y'));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Track Y'));
        await tester.pumpAndSettle();

        expect(find.text('S1'), findsOneWidget);
        expect(find.text('S2'), findsOneWidget);
        expect(find.text('S3'), findsOneWidget);

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
