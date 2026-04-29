import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/screens/home_screen.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

void main() {
  testWidgets('tela inicial exibe botão INICIAR', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('INICIAR'), findsOneWidget);
  });

  testWidgets('tela inicial exibe hint de seleção de pista', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('selecione a pista após iniciar'), findsOneWidget);
  });

  testWidgets('tela inicial exibe logo LAPZY com texto LAP', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.textContaining('LAP'), findsOneWidget);
  });

  testWidgets('tela inicial exibe tagline de cronometragem', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('CRONOMETRAGEM DE KART'), findsOneWidget);
  });

  testWidgets('toque em INICIAR abre sheet de seleção de pista', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.text('INICIAR'));
    await tester.pumpAndSettle();

    expect(find.text('SELECIONAR PISTA'), findsOneWidget);
  });

  testWidgets('toque em INICIAR exibe estado vazio de pistas na sheet', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.text('INICIAR'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma pista salva'), findsOneWidget);
  });

  testWidgets('CA-TRACK-001-01: exibe ícone de traçados na top bar', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.byKey(const Key('home_tracks_button')), findsOneWidget);
  });

  testWidgets('CA-TRACK-001-01: toque no ícone de traçados navega para TrackListScreen', (tester) async {
    _setPhoneSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.byKey(const Key('home_tracks_button')));
    await tester.pumpAndSettle();

    expect(find.text('TRAÇADOS'), findsOneWidget);
  });
}
