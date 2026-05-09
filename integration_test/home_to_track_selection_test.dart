import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:lapzy/repositories/track_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('fluxo: home → toque em INICIAR', () {
    setUp(() async {
      await TrackRepository().clearStorageForTesting();
      await RaceSessionRepository().clearStorageForTesting();
    });

    testWidgets('sheet de seleção de pista abre', (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      expect(find.text('INICIAR'), findsOneWidget);

      await tester.tap(find.text('INICIAR'));
      await tester.pumpAndSettle();

      expect(find.text('SELECIONAR PISTA'), findsOneWidget);
    });

    testWidgets('estado vazio exibido sem pistas', (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('INICIAR'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma pista salva'), findsOneWidget);
      expect(find.text('Crie sua primeira pista para começar'), findsOneWidget);
    });

    testWidgets('botão + NOVA PISTA visível', (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('INICIAR'));
      await tester.pumpAndSettle();

      expect(find.text('+ NOVA PISTA'), findsOneWidget);
    });

    testWidgets('campo de busca disponível', (tester) async {
      await app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('INICIAR'));
      await tester.pumpAndSettle();

      expect(find.text('Buscar pista...'), findsOneWidget);
    });
  });
}
