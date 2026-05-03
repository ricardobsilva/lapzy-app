import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:lapzy/repositories/track_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSeedVersionKey = 'lapzy_seed_version';
const _kSeedVersion = 2;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TASK-014 · Gerenciamento de Traçados (US TRACK-001)', () {
    Future<void> resetState() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kSeedVersionKey, _kSeedVersion);
      await TrackRepository().clearStorageForTesting();
      await RaceSessionRepository().clearStorageForTesting();
      TrackRepository().clearForTesting();
      RaceSessionRepository().clearForTesting();
    }

    Track makeTrack({
      required String id,
      required String name,
      DateTime? createdAt,
      int sectorCount = 0,
    }) {
      final sectors = List.generate(
        sectorCount,
        (i) => TrackLine(
          a: GeoPoint(-23.551 - i * 0.001, -46.633),
          b: GeoPoint(-23.552 - i * 0.001, -46.634),
        ),
      );
      return Track(
        id: id,
        name: name,
        createdAt: createdAt ?? DateTime.utc(2026, 4, 29, 14, 0),
        startFinishLine: TrackLine(
          a: const GeoPoint(-23.5505, -46.6333),
          b: const GeoPoint(-23.5510, -46.6340),
        ),
        sectorBoundaries: sectors,
      );
    }

    group('CA-TRACK-001-01: acesso via ícone na HomeScreen', () {
      testWidgets('ícone de traçados na HomeScreen abre TrackListScreen',
          (tester) async {
        addTearDown(resetState);
        await resetState();

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        expect(find.text('TRAÇADOS'), findsOneWidget);
      });
    });

    group('CA-TRACK-001-03: estado vazio', () {
      testWidgets('sem traçados exibe mensagem de estado vazio', (tester) async {
        addTearDown(resetState);
        await resetState();

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tracks_empty_state')), findsOneWidget);
        expect(find.text('CRIAR TRAÇADO'), findsOneWidget);
      });
    });

    group('CA-TRACK-001-02: listagem de traçados', () {
      testWidgets('traçados aparecem com nome e data de criação', (tester) async {
        addTearDown(resetState);
        await resetState();

        await TrackRepository().save(makeTrack(
          id: 't1',
          name: 'Kartódromo Granja Viana',
          createdAt: DateTime.utc(2026, 4, 29, 14, 32),
        ));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        expect(find.text('Kartódromo Granja Viana'), findsOneWidget);
        expect(find.byKey(const Key('tracks_list')), findsOneWidget);
      });

      testWidgets('traçado mais recente aparece no topo', (tester) async {
        addTearDown(resetState);
        await resetState();

        await TrackRepository().save(makeTrack(
          id: 'old',
          name: 'Pista Antiga',
          createdAt: DateTime.utc(2026, 1, 1),
        ));
        await TrackRepository().save(makeTrack(
          id: 'new',
          name: 'Pista Nova',
          createdAt: DateTime.utc(2026, 4, 29),
        ));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        final top = tester.widget<Text>(find.byKey(const Key('track_name_0')));
        expect(top.data, 'Pista Nova');
      });
    });

    group('CA-TRACK-001-04 e CA-TRACK-001-05: detalhe do traçado', () {
      testWidgets('toque em traçado abre TrackDetailScreen com nome e data',
          (tester) async {
        addTearDown(resetState);
        await resetState();

        await TrackRepository().save(makeTrack(
          id: 'detail-1',
          name: 'Speed Park Interlagos',
          createdAt: DateTime.utc(2026, 4, 15, 10, 0),
        ));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('track_card_0')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('detail_name')), findsOneWidget);
        expect(find.text('Speed Park Interlagos'), findsAtLeast(1));
        expect(find.byKey(const Key('detail_date')), findsOneWidget);
        expect(find.byKey(const Key('detail_sectors')), findsOneWidget);
        expect(find.byKey(const Key('detail_edit_button')), findsOneWidget);
      });

      testWidgets('detalhe exibe contagem correta de setores', (tester) async {
        addTearDown(resetState);
        await resetState();

        await TrackRepository().save(makeTrack(
          id: 'sector-track',
          name: 'Pista com Setores',
          sectorCount: 2,
        ));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('track_card_0')));
        await tester.pumpAndSettle();

        expect(find.text('2 setores configurados'), findsOneWidget);
      });
    });

    group('CA-TRACK-001-08 e CA-TRACK-001-09: exclusão de traçado', () {
      testWidgets('swipe exibe ação de exclusão', (tester) async {
        addTearDown(resetState);
        await resetState();

        await TrackRepository().save(makeTrack(id: 'del-1', name: 'Pista Teste'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const Key('track_card_0')),
          const Offset(-300, 0),
        );
        await tester.pump();

        expect(find.text('EXCLUIR'), findsOneWidget);
      });

      testWidgets('swipe completo exibe confirmação com texto correto',
          (tester) async {
        addTearDown(resetState);
        await resetState();

        await TrackRepository().save(makeTrack(id: 'del-2', name: 'Pista Teste'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const Key('track_card_0')),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        expect(find.text('Excluir traçado?'), findsOneWidget);
        expect(
          find.textContaining('Nenhum histórico será perdido'),
          findsOneWidget,
        );
      });

      testWidgets('CA-TRACK-001-09: cancelar não remove traçado', (tester) async {
        addTearDown(resetState);
        await resetState();

        await TrackRepository().save(makeTrack(id: 'del-3', name: 'Pista Manter'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const Key('track_card_0')),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('delete_cancel_button')));
        await tester.pumpAndSettle();

        expect(find.text('Pista Manter'), findsOneWidget);
      });

      testWidgets('CA-TRACK-001-09: confirmar remove traçado da lista',
          (tester) async {
        addTearDown(resetState);
        await resetState();

        await TrackRepository().save(makeTrack(id: 'del-4', name: 'Pista Remover'));

        await app.main();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_tracks_button')));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const Key('track_card_0')),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('delete_confirm_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tracks_empty_state')), findsOneWidget);
        expect(TrackRepository().tracks, isEmpty);
      });
    });
  });
}
