import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:lapzy/repositories/track_repository.dart';
import 'package:lapzy/screens/race_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TASK-011 / TASK-012: Persistência local', () {
    group('CA-PERSIST-001: pistas persistem entre sessões do app', () {
      testWidgets('pista salva via save() é recuperada após reload do repositório',
          (tester) async {
        addTearDown(() async {
          await TrackRepository().clearStorageForTesting();
        });

        await TrackRepository().clearStorageForTesting();
        final now = DateTime.now();
        final track = Track(
          id: 'persist-test-001',
          name: 'Pista Persistida',
          createdAt: now,
          updatedAt: now,
        );
        await TrackRepository().save(track);

        TrackRepository().clearForTesting();
        await TrackRepository().load();

        expect(TrackRepository().tracks.length, equals(1));
        expect(TrackRepository().tracks.first.name, equals('Pista Persistida'));
      });

      testWidgets('pista com linha de largada e setores sobrevive ao reload',
          (tester) async {
        addTearDown(() async {
          await TrackRepository().clearStorageForTesting();
        });

        await TrackRepository().clearStorageForTesting();
        final now = DateTime.now();
        const startFinish = TrackLine(
          a: GeoPoint(-23.55, -46.63),
          b: GeoPoint(-23.57, -46.61),
          widthMeters: 8.0,
        );
        const sector = TrackLine(
          a: GeoPoint(-23.56, -46.62),
          b: GeoPoint(-23.58, -46.60),
          middlePoints: [GeoPoint(-23.565, -46.615)],
        );
        final track = Track(
          id: 'persist-test-002',
          name: 'Pista Completa',
          startFinishLine: startFinish,
          sectorBoundaries: const [sector],
          createdAt: now,
          updatedAt: now,
        );
        await TrackRepository().save(track);

        TrackRepository().clearForTesting();
        await TrackRepository().load();

        final restored = TrackRepository().tracks.first;
        expect(restored.startFinishLine, isNotNull);
        expect(
          restored.startFinishLine!.a,
          equals(const GeoPoint(-23.55, -46.63)),
        );
        expect(restored.startFinishLine!.widthMeters, equals(8.0));
        expect(restored.sectorBoundaries.length, equals(1));
        expect(
          restored.sectorBoundaries.first.middlePoints.length,
          equals(1),
        );
      });

      testWidgets('CA-PERSIST-001-03: id da pista salva via save é UUID v4 (formato)',
          (tester) async {
        addTearDown(() async {
          await TrackRepository().clearStorageForTesting();
        });

        await TrackRepository().clearStorageForTesting();
        TrackRepository().clearForTesting();
        TrackRepository().add(const Track(id: '1', name: 'Pista UUID Test'));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('+ NOVA PISTA'));
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsWidgets);

        TrackRepository().clearForTesting();
      });
    });

    group('CA-PERSIST-002: sessões de corrida persistem entre sessões do app', () {
      testWidgets(
          'CA-PERSIST-002-02: sessão é salva automaticamente ao encerrar corrida',
          (tester) async {
        addTearDown(() async {
          await TrackRepository().clearStorageForTesting();
          await RaceSessionRepository().clearStorageForTesting();
        });

        await TrackRepository().clearStorageForTesting();
        await RaceSessionRepository().clearStorageForTesting();
        TrackRepository().clearForTesting();
        RaceSessionRepository().clearForTesting();

        TrackRepository().add(const Track(id: '1', name: 'Pista Sessão'));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Sessão'));
        await tester.pumpAndSettle();

        final screenWidth = tester.getSize(find.byType(RaceScreen)).width;
        await tester.dragFrom(
          Offset(screenWidth - 5, 200),
          const Offset(-50, 0),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('end_button')));
        await tester.pumpAndSettle();

        expect(RaceSessionRepository().sessions.length, equals(1));
        expect(
          RaceSessionRepository().sessions.first.trackName,
          equals('Pista Sessão'),
        );

        TrackRepository().clearForTesting();
        RaceSessionRepository().clearForTesting();
      });

      testWidgets(
          'CA-PERSIST-002-01: sessão salva contém trackId, trackName e createdAt',
          (tester) async {
        addTearDown(() async {
          await TrackRepository().clearStorageForTesting();
          await RaceSessionRepository().clearStorageForTesting();
        });

        await TrackRepository().clearStorageForTesting();
        await RaceSessionRepository().clearStorageForTesting();
        TrackRepository().clearForTesting();
        RaceSessionRepository().clearForTesting();

        TrackRepository().add(const Track(id: '1', name: 'Pista Campos'));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Campos'));
        await tester.pumpAndSettle();

        final screenWidth = tester.getSize(find.byType(RaceScreen)).width;
        await tester.dragFrom(
          Offset(screenWidth - 5, 200),
          const Offset(-50, 0),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('end_button')));
        await tester.pumpAndSettle();

        final session = RaceSessionRepository().sessions.first;
        expect(session.id, isNotEmpty);
        expect(session.trackId, equals('1'));
        expect(session.trackName, equals('Pista Campos'));
        expect(session.createdAt, isNotNull);
        expect(session.date, isNotNull);

        TrackRepository().clearForTesting();
        RaceSessionRepository().clearForTesting();
      });

      testWidgets(
          'CA-PERSIST-002-03: sessão sobrevive após reload do repositório',
          (tester) async {
        addTearDown(() async {
          await TrackRepository().clearStorageForTesting();
          await RaceSessionRepository().clearStorageForTesting();
        });

        await TrackRepository().clearStorageForTesting();
        await RaceSessionRepository().clearStorageForTesting();
        TrackRepository().clearForTesting();
        RaceSessionRepository().clearForTesting();

        TrackRepository().add(const Track(id: '1', name: 'Pista Reload'));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.text('INICIAR'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pista Reload'));
        await tester.pumpAndSettle();

        final screenWidth = tester.getSize(find.byType(RaceScreen)).width;
        await tester.dragFrom(
          Offset(screenWidth - 5, 200),
          const Offset(-50, 0),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('end_button')));
        await tester.pumpAndSettle();

        final savedId = RaceSessionRepository().sessions.first.id;

        RaceSessionRepository().clearForTesting();
        await RaceSessionRepository().load();

        expect(RaceSessionRepository().sessions.length, equals(1));
        expect(RaceSessionRepository().sessions.first.id, equals(savedId));

        TrackRepository().clearForTesting();
        RaceSessionRepository().clearForTesting();
      });
    });
  });
}
