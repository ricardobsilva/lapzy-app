import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:lapzy/repositories/track_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TASK-005: Resumo Pós-Corrida', () {
    setUp(() async {
      await TrackRepository().clearStorageForTesting();
      await RaceSessionRepository().clearStorageForTesting();
    });

    group('CA-SUM-001: navegação e estrutura básica', () {
      testWidgets('resumo exibe RESUMO e nome da pista após encerramento',
          (tester) async {
        TrackRepository().add(const Track(id: '1', name: 'Pista Resumo'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Resumo'));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('end_button'))),
        );
        await tester.pump(const Duration(milliseconds: 2100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('RESUMO'), findsOneWidget);
        expect(find.text('Pista Resumo'), findsOneWidget);
      });

      testWidgets('resumo exibe botão COMPARTILHAR no rodapé',
          (tester) async {
        TrackRepository().add(const Track(id: '1', name: 'Pista Share'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Share'));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('end_button'))),
        );
        await tester.pump(const Duration(milliseconds: 2100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('summary_share_button')), findsOneWidget);
        expect(find.text('COMPARTILHAR'), findsOneWidget);
      });

      testWidgets('resumo NÃO exibe botão Descartar', (tester) async {
        TrackRepository().add(const Track(id: '1', name: 'Pista ND'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista ND'));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('end_button'))),
        );
        await tester.pump(const Duration(milliseconds: 2100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('DESCARTAR'), findsNothing);
        expect(find.text('Descartar'), findsNothing);
      });

      testWidgets('resumo sem voltas exibe mensagem vazia', (tester) async {
        TrackRepository().add(const Track(id: '1', name: 'Pista Vazia'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Vazia'));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('end_button'))),
        );
        await tester.pump(const Duration(milliseconds: 2100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('summary_no_laps')), findsOneWidget);
      });

      testWidgets('resumo NÃO exibe grade de setores sem dados de setor',
          (tester) async {
        TrackRepository().add(const Track(id: '1', name: 'Pista Sem Setores'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Sem Setores'));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('end_button'))),
        );
        await tester.pump(const Duration(milliseconds: 2100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('summary_sector_0')), findsNothing);
      });
    });
  });
}
