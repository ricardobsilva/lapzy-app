import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/screens/track_detail_screen.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

Track _makeTrack({
  String id = 'track-1',
  String name = 'Kartódromo Granja Viana',
  int sectorCount = 0,
  DateTime? createdAt,
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
    createdAt: createdAt ?? DateTime(2026, 4, 29, 14, 32),
    startFinishLine: TrackLine(
      a: const GeoPoint(-23.5505, -46.6333),
      b: const GeoPoint(-23.5510, -46.6340),
    ),
    sectorBoundaries: sectors,
  );
}

Widget _app(Track track) {
  return MaterialApp(home: TrackDetailScreen(track: track));
}

void main() {
  group('TrackDetailScreen', () {
    group('CA-TRACK-001-05: painel inferior', () {
      testWidgets('exibe nome do traçado', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(_makeTrack(name: 'Kartódromo Granja Viana')));

        expect(find.byKey(const Key('detail_name')), findsOneWidget);
        expect(find.text('Kartódromo Granja Viana'), findsAtLeast(1));
      });

      testWidgets('exibe data de criação formatada', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(_makeTrack(
          createdAt: DateTime(2026, 4, 29, 14, 32),
        )));

        expect(find.byKey(const Key('detail_date')), findsOneWidget);
        expect(find.textContaining('29 abr 2026'), findsOneWidget);
      });

      testWidgets('exibe contagem de setores — zero setores', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(_makeTrack(sectorCount: 0)));

        expect(find.byKey(const Key('detail_sectors')), findsOneWidget);
        expect(find.text('Sem setores configurados'), findsOneWidget);
      });

      testWidgets('exibe contagem de setores — 1 setor', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(_makeTrack(sectorCount: 1)));

        expect(find.byKey(const Key('detail_sectors')), findsOneWidget);
        expect(find.text('1 setor configurado'), findsOneWidget);
      });

      testWidgets('exibe contagem de setores — 2 setores', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(_makeTrack(sectorCount: 2)));

        expect(find.byKey(const Key('detail_sectors')), findsOneWidget);
        expect(find.text('2 setores configurados'), findsOneWidget);
      });

      testWidgets('exibe botão EDITAR', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(_makeTrack()));

        expect(find.byKey(const Key('detail_edit_button')), findsOneWidget);
        expect(find.text('EDITAR'), findsOneWidget);
      });
    });

    group('CA-TRACK-001-05: top bar', () {
      testWidgets('exibe nome do traçado na top bar', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(_makeTrack(name: 'Speed Park')));

        expect(find.byKey(const Key('detail_track_name')), findsOneWidget);
      });

      testWidgets('botão voltar fecha a tela', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: const Scaffold(body: Center(child: Text('home'))),
          ),
        );

        final nav = tester.element(find.text('home'));
        Navigator.of(nav).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackDetailScreen(track: _makeTrack()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('detail_back_button')), findsOneWidget);

        await tester.tap(find.byKey(const Key('detail_back_button')));
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
      });
    });
  });
}
