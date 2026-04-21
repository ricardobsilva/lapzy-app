import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;
import 'package:lapzy/screens/track_creation_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Criação de pista', () {
    group('navegação a partir da sheet de seleção', () {
      testWidgets(
          'fluxo: home → INICIAR → + NOVA PISTA → tela de criação abre',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        expect(find.byType(TrackCreationScreen), findsOneWidget);
      });

      testWidgets(
          'fluxo: home → INICIAR → + NOVA PISTA → seletor de modo visível',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        expect(find.text('TRILHA'), findsOneWidget);
        expect(find.text('S/C'), findsOneWidget);
        expect(find.text('S1'), findsOneWidget);
        expect(find.text('S2'), findsOneWidget);
        expect(find.text('S3'), findsOneWidget);
      });

      testWidgets(
          'fluxo: home → INICIAR → + NOVA PISTA → sheet fecha antes de abrir criação',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        expect(find.text('SELECIONAR PISTA'), findsNothing);
      });
    });

    group('campo de nome', () {
      testWidgets('aceita entrada de texto e exibe o valor digitado',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        await tester.enterText(
            find.byKey(const Key('track_name_field')), 'Granja Viana');
        await tester.pump();

        expect(find.text('Granja Viana'), findsOneWidget);
      });
    });

    group('botão SALVAR', () {
      testWidgets('está desabilitado ao abrir a tela sem nome e sem pista traçada',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        final saveText =
            tester.widget<Text>(find.byKey(const Key('save_button')));
        expect(saveText.style!.color,
            isNot(equals(const Color(0xFF00E676))));
      });
    });

    group('botão voltar', () {
      testWidgets('retorna para a tela inicial ao pressionar voltar',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('INICIAR'), findsOneWidget);
      });
    });

  });
}
