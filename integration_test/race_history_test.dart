import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;
import 'package:lapzy/models/race_session.dart';
import 'package:lapzy/models/race_session_record.dart';
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:lapzy/repositories/track_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mesma chave e versão definidas em seed_data.dart — mantidas em sincronia.
const _kSeedVersionKey = 'lapzy_seed_version';
const _kSeedVersion = 2;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TASK-013 · Histórico de Corridas (US HIST-001)', () {
    /// Limpa toda a state local e marca seed como já executado,
    /// evitando que seedDebugDataIfNeeded() insira dados durante main().
    Future<void> resetState() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kSeedVersionKey, _kSeedVersion);
      await TrackRepository().clearStorageForTesting();
      await RaceSessionRepository().clearStorageForTesting();
      TrackRepository().clearForTesting();
      RaceSessionRepository().clearForTesting();
    }

    RaceSessionRecord makeRecord({
      required String id,
      required String trackName,
      required DateTime date,
    }) =>
        RaceSessionRecord(
          id: id,
          trackId: 'track-$id',
          trackName: trackName,
          date: date,
          laps: const [LapResult(lapMs: 55000, sectors: [18000, 19000, 18000])],
          bestLapMs: 55000,
          createdAt: date,
        );

    group('CA-HIST-001-01: acesso via ícone na HomeScreen', () {
      testWidgets('ícone de relógio na HomeScreen abre RaceHistoryScreen',
          (tester) async {
        addTearDown(resetState);
        await resetState();

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_history_button')));
        await tester.pumpAndSettle();

        expect(find.text('CORRIDAS'), findsOneWidget);
      });
    });

    group('CA-HIST-001-05: estado vazio', () {
      testWidgets('sem corridas exibe Nenhuma corrida ainda.', (tester) async {
        addTearDown(resetState);
        await resetState();

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_history_button')));
        await tester.pumpAndSettle();

        expect(find.text('Nenhuma corrida ainda.'), findsOneWidget);
        expect(find.text('INICIAR CORRIDA'), findsOneWidget);
      });

      testWidgets('botão INICIAR CORRIDA retorna à HomeScreen', (tester) async {
        addTearDown(resetState);
        await resetState();

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_history_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('history_start_race_button')));
        await tester.pumpAndSettle();

        expect(find.text('INICIAR'), findsOneWidget);
      });
    });

    group('CA-HIST-001-02 e CA-HIST-001-03: lista e ordenação', () {
      testWidgets('corridas aparecem como cards com nome e data', (tester) async {
        addTearDown(resetState);
        await resetState();

        await RaceSessionRepository().save(makeRecord(
          id: 's1',
          trackName: 'Kartódromo Ayrton Senna',
          date: DateTime.utc(2026, 4, 12, 14, 32),
        ));
        await RaceSessionRepository().save(makeRecord(
          id: 's2',
          trackName: 'Speed Park Interlagos',
          date: DateTime.utc(2026, 4, 3, 9, 15),
        ));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_history_button')));
        await tester.pumpAndSettle();

        expect(find.text('Kartódromo Ayrton Senna'), findsOneWidget);
        expect(find.text('Speed Park Interlagos'), findsOneWidget);
      });

      testWidgets('corrida mais recente aparece no topo', (tester) async {
        addTearDown(resetState);
        await resetState();

        await RaceSessionRepository().save(makeRecord(
          id: 'old',
          trackName: 'Pista Antiga',
          date: DateTime.utc(2026, 3, 1, 9, 0),
        ));
        await RaceSessionRepository().save(makeRecord(
          id: 'new',
          trackName: 'Pista Nova',
          date: DateTime.utc(2026, 4, 15, 14, 0),
        ));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_history_button')));
        await tester.pumpAndSettle();

        final card0 = tester.widget<Text>(
          find.byKey(const Key('history_track_name_0')),
        );
        expect(card0.data, 'Pista Nova');
      });

      testWidgets('data exibida com mês em português', (tester) async {
        addTearDown(resetState);
        await resetState();

        await RaceSessionRepository().save(makeRecord(
          id: 'date1',
          trackName: 'Pista Data',
          date: DateTime.utc(2026, 4, 12, 14, 32),
        ));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_history_button')));
        await tester.pumpAndSettle();

        final dateWidget = tester.widget<Text>(
          find.byKey(const Key('history_date_0')),
        );
        expect(dateWidget.data, contains('abr'));
        expect(dateWidget.data, contains('2026'));
      });
    });

    group('CA-HIST-001-04: navegação para resumo', () {
      testWidgets('toque em card abre RaceSummaryScreen com dados corretos',
          (tester) async {
        addTearDown(resetState);
        await resetState();

        await RaceSessionRepository().save(makeRecord(
          id: 'nav1',
          trackName: 'Kartódromo de Cascavel',
          date: DateTime.utc(2026, 3, 15, 11, 5),
        ));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_history_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('history_card_0')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('summary_title')), findsOneWidget);
        expect(find.text('Kartódromo de Cascavel'), findsOneWidget);
      });

      testWidgets('resumo via histórico exibe voltas corretas', (tester) async {
        addTearDown(resetState);
        await resetState();

        await RaceSessionRepository().save(RaceSessionRecord(
          id: 'nav2',
          trackId: 'track-nav2',
          trackName: 'Pista Voltas',
          date: DateTime.utc(2026, 4, 10, 14, 0),
          laps: const [
            LapResult(lapMs: 55210, sectors: [18000, 19000, 18210]),
            LapResult(lapMs: 54980, sectors: [17800, 18900, 18280]),
          ],
          bestLapMs: 54980,
          createdAt: DateTime.utc(2026, 4, 10, 14, 45),
        ));

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_history_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('history_card_0')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('summary_lap_time_1')), findsOneWidget);
        expect(find.byKey(const Key('summary_lap_time_2')), findsOneWidget);
      });
    });

    group('CA-HIST-001-06: top bar', () {
      testWidgets('botão voltar retorna para HomeScreen', (tester) async {
        addTearDown(resetState);
        await resetState();

        app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_history_button')));
        await tester.pumpAndSettle();

        expect(find.text('CORRIDAS'), findsOneWidget);

        await tester.tap(find.byKey(const Key('history_back_button')));
        await tester.pumpAndSettle();

        expect(find.text('INICIAR'), findsOneWidget);
      });
    });
  });
}
