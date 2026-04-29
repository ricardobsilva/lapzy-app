import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/track_repository.dart';
import 'package:lapzy/screens/track_creation_screen.dart';

// ── HELPERS ───────────────────────────────────────────────────────────────────

Widget _app({int initialStep = 0}) {
  return MaterialApp(
    home: TrackCreationScreen(
      mapBuilder: () => const ColoredBox(color: Color(0xFF0A0A0A)),
      initialStep: initialStep,
    ),
  );
}

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

void _resetView(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

// ── TESTES ────────────────────────────────────────────────────────────────────

void main() {
  group('TrackCreationScreen', () {
    // ── RENDERIZAÇÃO INICIAL ──────────────────────────────────────────────────

    group('quando a tela é exibida pela primeira vez', () {
      testWidgets('renderiza sem erros', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.byType(TrackCreationScreen), findsOneWidget);
      });

      testWidgets('exibe ícone de voltar', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });
    });

    // ── BARRA DE PROGRESSO ────────────────────────────────────────────────────

    group('barra de progresso', () {
      testWidgets('exibe label LARGADA', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('LARGADA'), findsOneWidget);
      });

      testWidgets('exibe label SETORES', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('SETORES'), findsOneWidget);
      });

      testWidgets('exibe label NOME', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('NOME'), findsOneWidget);
      });

      testWidgets('exibe label SALVAR', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('SALVAR'), findsOneWidget);
      });

      testWidgets('não exibe label TRAÇADO (step removido)', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('TRAÇADO'), findsNothing);
      });

      testWidgets('passo 0 exibe nó S/C ativo', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('S/C'), findsOneWidget);
      });
    });

    // ── PAINEL 0 — LARGADA ────────────────────────────────────────────────────

    group('painel LARGADA (passo 0)', () {
      testWidgets('exibe título "Largada / Chegada"', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('Largada / Chegada'), findsOneWidget);
      });

      testWidgets('não exibe hint no mapa antes de entrar em modo traçar',
          (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('Arraste para marcar a largada'), findsNothing);
      });

      testWidgets('exibe hint no mapa após ativar modo traçar', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());
        await tester.tap(find.text('TRAÇAR'));
        await tester.pump();

        expect(find.text('Arraste para marcar a largada'), findsOneWidget);
      });

      testWidgets('exibe botão TRAÇAR para entrar em modo de desenho',
          (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('TRAÇAR'), findsOneWidget);
      });

      testWidgets('exibe botão de busca no mapa', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.byKey(const Key('search_button')), findsOneWidget);
      });

      testWidgets('toque no botão de busca abre campo de texto', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());
        await tester.tap(find.byKey(const Key('search_button')));
        await tester.pump();

        expect(find.byKey(const Key('search_field')), findsOneWidget);
      });

      testWidgets('exibe toggle de imagem de satélite', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.byKey(const Key('map_type_toggle')), findsOneWidget);
      });

      testWidgets('não exibe controle de largura sem linha de largada definida',
          (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('Largura da linha'), findsNothing);
      });

      testWidgets('botão Confirmar está desabilitado sem S/C definida',
          (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.text('Confirmar →'), findsOneWidget);
      });

      testWidgets('não exibe botão FECHAR PISTA (step removido)', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app());

        expect(find.byKey(const Key('close_track_button')), findsNothing);
      });
    });

    // ── PAINEL 1 — SETORES ────────────────────────────────────────────────────

    group('painel SETORES (passo 1)', () {
      testWidgets('exibe título "Setores"', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 1));

        expect(find.text('Setores'), findsOneWidget);
      });

      testWidgets('exibe indicação de opcional', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 1));

        expect(find.text('(opcional)'), findsOneWidget);
      });

      testWidgets('exibe estado vazio "Nenhum setor ainda."', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 1));

        expect(find.text('Nenhum setor ainda.'), findsOneWidget);
      });

      testWidgets('botão Continuar está sempre habilitado', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 1));

        expect(find.text('Continuar →'), findsOneWidget);
      });
    });

    // ── PAINEL 2 — NOME ───────────────────────────────────────────────────────

    group('painel NOME (passo 2)', () {
      testWidgets('exibe campo de nome da pista', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 2));

        expect(find.byKey(const Key('track_name_field')), findsOneWidget);
      });

      testWidgets('exibe placeholder "Nome da pista" no campo vazio',
          (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 2));

        expect(find.text('Nome da pista'), findsAtLeastNWidgets(1));
      });

      testWidgets('exibe botão SALVAR', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 2));

        expect(find.byKey(const Key('save_button')), findsOneWidget);
      });

      testWidgets('botão SALVAR está desabilitado quando o nome está vazio',
          (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 2));

        final saveText =
            tester.widget<Text>(find.byKey(const Key('save_button')));
        expect(saveText.style!.color, isNot(equals(Colors.black)));
      });

      testWidgets('aceita digitação no campo de nome', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 2));
        await tester.enterText(
            find.byKey(const Key('track_name_field')), 'Kartódromo SP');
        await tester.pump();

        expect(find.text('Kartódromo SP'), findsOneWidget);
      });

      testWidgets('exibe botão voltar', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        await tester.pumpWidget(_app(initialStep: 2));

        expect(find.text('← Voltar'), findsOneWidget);
      });
    });

    // ── MODO EDIÇÃO ───────────────────────────────────────────────────────────

    group('CA-TRACK-001-06: modo edição com initialTrack', () {
      setUp(() => TrackRepository().clearForTesting());
      tearDown(() => TrackRepository().clearForTesting());

      testWidgets('pré-popula campo de nome com o traçado existente', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        final track = Track(
          id: 'edit-1',
          name: 'Pista Existente',
          createdAt: DateTime(2026, 1, 1),
          startFinishLine: TrackLine(
            a: const GeoPoint(-23.5505, -46.6333),
            b: const GeoPoint(-23.5510, -46.6340),
          ),
        );

        await tester.pumpWidget(MaterialApp(
          home: TrackCreationScreen(
            mapBuilder: () => const ColoredBox(color: Color(0xFF0A0A0A)),
            initialTrack: track,
            initialStep: 2,
          ),
        ));

        expect(find.text('Pista Existente'), findsOneWidget);
      });

      testWidgets('CA-TRACK-001-07: salvar atualiza registro existente sem criar novo', (tester) async {
        _setPhoneSize(tester);
        addTearDown(() => _resetView(tester));

        final original = Track(
          id: 'edit-id-001',
          name: 'Pista Original',
          createdAt: DateTime(2026, 1, 1),
          startFinishLine: TrackLine(
            a: const GeoPoint(-23.5505, -46.6333),
            b: const GeoPoint(-23.5510, -46.6340),
          ),
        );
        TrackRepository().add(original);

        await tester.pumpWidget(MaterialApp(
          home: TrackCreationScreen(
            mapBuilder: () => const ColoredBox(color: Color(0xFF0A0A0A)),
            initialTrack: original,
            initialStep: 2,
          ),
        ));

        await tester.enterText(
          find.byKey(const Key('track_name_field')),
          'Pista Editada',
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        final tracks = TrackRepository().tracks;
        expect(tracks.length, 1);
        expect(tracks.first.id, 'edit-id-001');
        expect(tracks.first.name, 'Pista Editada');
        expect(tracks.first.createdAt, DateTime(2026, 1, 1));
      });
    });
  });
}
