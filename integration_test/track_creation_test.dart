import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;
import 'package:lapzy/screens/track_creation_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Criação de pista', () {
    // ── NAVEGAÇÃO ─────────────────────────────────────────────────────────────

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

      testWidgets(
          'fluxo: home → INICIAR → + NOVA PISTA → barra de progresso visível com 4 passos',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        expect(find.text('LARGADA'), findsOneWidget);
        expect(find.text('SETORES'), findsOneWidget);
        expect(find.text('NOME'), findsOneWidget);
        expect(find.text('SALVAR'), findsOneWidget);
      });

      testWidgets(
          'fluxo: home → INICIAR → + NOVA PISTA → não exibe label TRAÇADO',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        expect(find.text('TRAÇADO'), findsNothing);
      });
    });

    // ── PASSO INICIAL — LARGADA ───────────────────────────────────────────────

    group('passo inicial (LARGADA)', () {
      testWidgets('abre no passo LARGADA com painel correto', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        expect(find.text('Largada / Chegada'), findsOneWidget);
      });

      testWidgets('exibe botão TRAÇAR para entrar em modo de desenho',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        expect(find.text('TRAÇAR'), findsOneWidget);
      });

      testWidgets('hint correto no mapa aparece ao ativar modo traçar',
          (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('TRAÇAR'));
        await tester.pumpAndSettle();

        expect(find.text('Arraste para marcar a largada'), findsOneWidget);
      });

      testWidgets('não exibe botão FECHAR PISTA (step removido)', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('close_track_button')), findsNothing);
      });
    });

    // ── BACK BUTTON ───────────────────────────────────────────────────────────

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
