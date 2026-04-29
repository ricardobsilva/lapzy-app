import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/track_repository.dart';
import 'package:lapzy/screens/track_list_screen.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

Track _makeTrack({
  required String id,
  required String name,
  DateTime? createdAt,
}) {
  return Track(
    id: id,
    name: name,
    createdAt: createdAt ?? DateTime(2026, 4, 29, 14, 0),
    startFinishLine: TrackLine(
      a: const GeoPoint(-23.5505, -46.6333),
      b: const GeoPoint(-23.5510, -46.6340),
    ),
  );
}

void main() {
  setUp(() => TrackRepository().clearForTesting());
  tearDown(() => TrackRepository().clearForTesting());

  group('TrackListScreen', () {
    group('CA-TRACK-001-02: estado vazio', () {
      testWidgets('exibe título TRAÇADOS', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: TrackListScreen()));

        expect(find.byKey(const Key('tracks_title')), findsOneWidget);
        expect(find.text('TRAÇADOS'), findsOneWidget);
      });

      testWidgets('exibe estado vazio quando não há traçados', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: TrackListScreen()));

        expect(find.byKey(const Key('tracks_empty_state')), findsOneWidget);
        expect(find.byKey(const Key('tracks_empty_title')), findsOneWidget);
      });

      testWidgets('estado vazio exibe botão CRIAR TRAÇADO', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: TrackListScreen()));

        expect(find.byKey(const Key('tracks_create_button')), findsOneWidget);
        expect(find.text('CRIAR TRAÇADO'), findsOneWidget);
      });
    });

    group('CA-TRACK-001-02: exibição de traçados', () {
      testWidgets('exibe nome do traçado e data de criação', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        TrackRepository().add(_makeTrack(
          id: 'track-1',
          name: 'Kartódromo Granja Viana',
          createdAt: DateTime(2026, 4, 29, 14, 32),
        ));

        await tester.pumpWidget(const MaterialApp(home: TrackListScreen()));

        expect(find.byKey(const Key('track_name_0')), findsOneWidget);
        expect(find.text('Kartódromo Granja Viana'), findsOneWidget);
        expect(find.byKey(const Key('track_date_0')), findsOneWidget);
        expect(find.textContaining('29 abr 2026'), findsOneWidget);
      });

      testWidgets('exibe múltiplos traçados', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        TrackRepository()
          ..add(_makeTrack(id: 't1', name: 'Pista A'))
          ..add(_makeTrack(id: 't2', name: 'Pista B'));

        await tester.pumpWidget(const MaterialApp(home: TrackListScreen()));

        expect(find.byKey(const Key('tracks_list')), findsOneWidget);
        expect(find.byKey(const Key('track_card_0')), findsOneWidget);
        expect(find.byKey(const Key('track_card_1')), findsOneWidget);
      });

      testWidgets('ordena por createdAt decrescente', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final older = _makeTrack(
          id: 't1',
          name: 'Pista Antiga',
          createdAt: DateTime(2026, 1, 1),
        );
        final newer = _makeTrack(
          id: 't2',
          name: 'Pista Nova',
          createdAt: DateTime(2026, 4, 29),
        );
        TrackRepository()
          ..add(older)
          ..add(newer);

        await tester.pumpWidget(const MaterialApp(home: TrackListScreen()));

        final newIdx = tester.getTopLeft(find.text('Pista Nova')).dy;
        final oldIdx = tester.getTopLeft(find.text('Pista Antiga')).dy;
        expect(newIdx, lessThan(oldIdx));
      });
    });

    group('CA-TRACK-001-09: confirmação de exclusão', () {
      testWidgets('bottom sheet exibe título e mensagem corretos', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        TrackRepository().add(_makeTrack(id: 'track-1', name: 'Pista Teste'));

        await tester.pumpWidget(const MaterialApp(home: TrackListScreen()));

        await tester.drag(
          find.byKey(const Key('track_card_0')),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('delete_confirm_title')), findsOneWidget);
        expect(find.text('Excluir traçado?'), findsOneWidget);
        expect(find.byKey(const Key('delete_confirm_body')), findsOneWidget);
        expect(
          find.textContaining('Nenhum histórico será perdido'),
          findsOneWidget,
        );
      });

      testWidgets('cancelar fecha bottom sheet sem remover traçado', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        TrackRepository().add(_makeTrack(id: 'track-1', name: 'Pista Teste'));

        await tester.pumpWidget(const MaterialApp(home: TrackListScreen()));

        await tester.drag(
          find.byKey(const Key('track_card_0')),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('delete_cancel_button')));
        await tester.pumpAndSettle();

        expect(find.text('Pista Teste'), findsOneWidget);
        expect(TrackRepository().tracks.length, 1);
      });

      testWidgets('confirmar remove traçado da lista', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        TrackRepository().add(_makeTrack(id: 'track-1', name: 'Pista Teste'));

        await tester.pumpWidget(const MaterialApp(home: TrackListScreen()));

        await tester.drag(
          find.byKey(const Key('track_card_0')),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('delete_confirm_button')));
        await tester.pumpAndSettle();

        expect(TrackRepository().tracks, isEmpty);
        expect(find.byKey(const Key('tracks_empty_state')), findsOneWidget);
      });
    });

    group('CA-TRACK-001-01: botão voltar', () {
      testWidgets('botão voltar fecha a tela', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('home')),
            ),
          ),
        );

        final nav = tester.element(find.text('home'));
        Navigator.of(nav).push(
          MaterialPageRoute<void>(
            builder: (_) => const TrackListScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('TRAÇADOS'), findsOneWidget);

        await tester.tap(find.byKey(const Key('tracks_back_button')));
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
      });
    });
  });
}
