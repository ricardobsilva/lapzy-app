import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/widgets/track_selection_sheet.dart';

Widget _app({required VoidCallback onOpen}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              onOpen();
              showTrackSelectionSheet(context);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
}

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

void main() {
  testWidgets('sheet exibe label SELECIONAR PISTA', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(onOpen: () {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('SELECIONAR PISTA'), findsOneWidget);
  });

  testWidgets('sheet exibe campo de busca com hint Buscar pista...', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(onOpen: () {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar pista...'), findsOneWidget);
  });

  testWidgets('sheet exibe estado vazio quando não há pistas cadastradas', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(onOpen: () {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma pista salva'), findsOneWidget);
  });

  testWidgets('sheet exibe subtítulo orientando criar primeira pista', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(onOpen: () {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Crie sua primeira pista para começar'), findsOneWidget);
  });

  testWidgets('sheet exibe botão + NOVA PISTA', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(onOpen: () {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('+ NOVA PISTA'), findsOneWidget);
  });

  testWidgets('sheet é exibida após chamar showTrackSelectionSheet', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool opened = false;
    await tester.pumpWidget(_app(onOpen: () => opened = true));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('campo de busca aceita texto digitado', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(onOpen: () {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Interlagos');
    await tester.pump();

    expect(find.text('Interlagos'), findsOneWidget);
  });
}
