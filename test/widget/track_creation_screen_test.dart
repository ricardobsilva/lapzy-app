import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/screens/track_creation_screen.dart';

Widget _app() {
  return MaterialApp(
    home: TrackCreationScreen(
      mapBuilder: () => const ColoredBox(color: Color(0xFF0A0A0A)),
    ),
  );
}

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

void main() {
  group('TrackCreationScreen', () {
    group('quando a tela é exibida pela primeira vez', () {
      testWidgets('renderiza sem erros', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.byType(TrackCreationScreen), findsOneWidget);
      });

      testWidgets('exibe campo de nome da pista', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.byKey(const Key('track_name_field')), findsOneWidget);
      });

      testWidgets('exibe hint "Nome da pista" no campo vazio', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.text('Nome da pista'), findsOneWidget);
      });

      testWidgets('exibe botão SALVAR', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.byKey(const Key('save_button')), findsOneWidget);
      });
    });

    group('seletor de modo', () {
      testWidgets('exibe aba TRILHA', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.text('TRILHA'), findsOneWidget);
      });

      testWidgets('exibe aba S/C', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.text('S/C'), findsOneWidget);
      });

      testWidgets('exibe aba S1', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.text('S1'), findsOneWidget);
      });

      testWidgets('exibe aba S2', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.text('S2'), findsOneWidget);
      });

      testWidgets('exibe aba S3', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.text('S3'), findsOneWidget);
      });

      testWidgets('modo TRILHA está ativo por padrão (hint de traçar pista visível)',
          (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        // O hint do modo TRILHA indica que este modo está ativo
        expect(find.text('Toque no mapa para traçar a pista'), findsOneWidget);
      });
    });

    group('hint de modo', () {
      testWidgets('exibe instrução para traçar a pista no modo TRILHA sem pontos',
          (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.text('Toque no mapa para traçar a pista'), findsOneWidget);
      });
    });

    group('botão FECHAR PISTA', () {
      testWidgets('não é exibido quando há menos de 3 pontos', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.byKey(const Key('close_track_button')), findsNothing);
      });
    });

    group('botão SALVAR', () {
      testWidgets('está desabilitado quando o nome está vazio', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        // O texto SALVAR existe mas deve estar na cor desabilitada (branco com alpha 77)
        final saveWidget = tester.widget<Text>(find.byKey(const Key('save_button')));
        final style = saveWidget.style!;
        expect(style.color, isNot(equals(const Color(0xFF00E676))));
      });

      testWidgets('aceita digitação no campo de nome', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());
        await tester.enterText(
            find.byKey(const Key('track_name_field')), 'Kartódromo SP');
        await tester.pump();

        expect(find.text('Kartódromo SP'), findsOneWidget);
      });
    });

    group('botão voltar', () {
      testWidgets('exibe ícone de voltar no top bar', (tester) async {
        _setPhoneSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app());

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });
    });
  });
}
