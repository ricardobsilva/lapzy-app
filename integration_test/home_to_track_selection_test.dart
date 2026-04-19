import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fluxo: home → toque em INICIAR → sheet de seleção de pista abre', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('INICIAR'), findsOneWidget);

    await tester.tap(find.text('INICIAR'));
    await tester.pumpAndSettle();

    expect(find.text('SELECIONAR PISTA'), findsOneWidget);
  });

  testWidgets('fluxo: home → toque em INICIAR → estado vazio exibido sem pistas', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('INICIAR'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma pista salva'), findsOneWidget);
    expect(find.text('Crie sua primeira pista para começar'), findsOneWidget);
  });

  testWidgets('fluxo: home → toque em INICIAR → botão + NOVA PISTA visível', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('INICIAR'));
    await tester.pumpAndSettle();

    expect(find.text('+ NOVA PISTA'), findsOneWidget);
  });

  testWidgets('fluxo: home → toque em INICIAR → campo de busca disponível', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('INICIAR'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar pista...'), findsOneWidget);
  });
}
