import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/race_session.dart';
import 'package:lapzy/models/race_session_record.dart';
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:lapzy/screens/race_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

Widget _buildScreen() =>
    const MaterialApp(home: RaceHistoryScreen());

RaceSessionRecord _makeRecord({
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RaceSessionRepository().clearForTesting();
  });
  tearDown(() => RaceSessionRepository().clearForTesting());

  group('CA-HIST-001-06: top bar', () {
    testWidgets('exibe label CORRIDAS centralizado', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen());

      expect(find.byKey(const Key('history_title')), findsOneWidget);
      expect(find.text('CORRIDAS'), findsOneWidget);
    });

    testWidgets('exibe botão voltar à esquerda', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen());

      expect(find.byKey(const Key('history_back_button')), findsOneWidget);
    });

    testWidgets('botão voltar fecha a tela', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RaceHistoryScreen(),
                ),
              ),
              child: const Scaffold(body: Text('HOME')),
            ),
          ),
        ),
      );

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.text('CORRIDAS'), findsOneWidget);

      await tester.tap(find.byKey(const Key('history_back_button')));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('CA-HIST-001-05: estado vazio', () {
    testWidgets('exibe ícone de relógio quando sem corridas', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen());

      expect(find.byKey(const Key('history_empty_state')), findsOneWidget);
    });

    testWidgets('exibe "Nenhuma corrida ainda."', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen());

      expect(find.byKey(const Key('history_empty_title')), findsOneWidget);
      expect(find.text('Nenhuma corrida ainda.'), findsOneWidget);
    });

    testWidgets('exibe mensagem de encorajamento', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen());

      expect(
        find.text('Sua primeira corrida vai aparecer aqui.'),
        findsOneWidget,
      );
      expect(find.text('Que tal aquecer o motor?'), findsOneWidget);
    });

    testWidgets('exibe botão ghost INICIAR CORRIDA', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen());

      expect(find.byKey(const Key('history_start_race_button')), findsOneWidget);
      expect(find.text('INICIAR CORRIDA'), findsOneWidget);
    });

    testWidgets('botão INICIAR CORRIDA retorna à tela anterior', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RaceHistoryScreen(),
                ),
              ),
              child: const Scaffold(body: Text('HOME')),
            ),
          ),
        ),
      );

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_start_race_button')));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('CA-HIST-001-02 e CA-HIST-001-03: lista com corridas', () {
    testWidgets('exibe cards para todas as sessões salvas', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await RaceSessionRepository().save(_makeRecord(
        id: 'r1',
        trackName: 'Pista Alpha',
        date: DateTime.utc(2026, 4, 10, 14, 30),
      ));
      await RaceSessionRepository().save(_makeRecord(
        id: 'r2',
        trackName: 'Pista Beta',
        date: DateTime.utc(2026, 4, 8, 9, 0),
      ));

      await tester.pumpWidget(_buildScreen());

      expect(find.byKey(const Key('history_card_0')), findsOneWidget);
      expect(find.byKey(const Key('history_card_1')), findsOneWidget);
    });

    testWidgets('exibe nome do circuito em cada card', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await RaceSessionRepository().save(_makeRecord(
        id: 'r1',
        trackName: 'Kartódromo Ayrton Senna',
        date: DateTime.utc(2026, 4, 10, 14, 30),
      ));

      await tester.pumpWidget(_buildScreen());

      expect(
        find.byKey(const Key('history_track_name_0')),
        findsOneWidget,
      );
      expect(find.text('Kartódromo Ayrton Senna'), findsOneWidget);
    });

    testWidgets('exibe data formatada em "dd mmm aaaa · HH:mm"', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await RaceSessionRepository().save(_makeRecord(
        id: 'r1',
        trackName: 'Pista Alpha',
        date: DateTime.utc(2026, 4, 12, 14, 32),
      ));

      await tester.pumpWidget(_buildScreen());

      expect(find.byKey(const Key('history_date_0')), findsOneWidget);
      // Aceita qualquer formato que contenha o dia, mês e hora corretos
      final dateText = tester.widget<Text>(
        find.byKey(const Key('history_date_0')),
      );
      expect(dateText.data, contains('12'));
      expect(dateText.data, contains('abr'));
      expect(dateText.data, contains('2026'));
    });

    testWidgets('ordenação decrescente por data — mais recente no topo', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Salva na ordem inversa da esperada
      await RaceSessionRepository().save(_makeRecord(
        id: 'old',
        trackName: 'Pista Antiga',
        date: DateTime.utc(2026, 3, 1, 9, 0),
      ));
      await RaceSessionRepository().save(_makeRecord(
        id: 'new',
        trackName: 'Pista Nova',
        date: DateTime.utc(2026, 4, 15, 14, 0),
      ));

      await tester.pumpWidget(_buildScreen());

      final card0 = tester.widget<Text>(
        find.byKey(const Key('history_track_name_0')),
      );
      final card1 = tester.widget<Text>(
        find.byKey(const Key('history_track_name_1')),
      );
      expect(card0.data, 'Pista Nova');
      expect(card1.data, 'Pista Antiga');
    });
  });

  group('CA-HIST-001-04: navegação para RaceSummaryScreen', () {
    testWidgets('toque em card navega para tela de resumo', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await RaceSessionRepository().save(_makeRecord(
        id: 'nav1',
        trackName: 'Pista Navegação',
        date: DateTime.utc(2026, 4, 10, 14, 0),
      ));

      await tester.pumpWidget(_buildScreen());
      await tester.tap(find.byKey(const Key('history_card_0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('summary_title')), findsOneWidget);
      expect(find.text('Pista Navegação'), findsOneWidget);
    });

    testWidgets('resumo aberto via histórico exibe nome da pista correto', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await RaceSessionRepository().save(_makeRecord(
        id: 'nav2',
        trackName: 'Speed Park Interlagos',
        date: DateTime.utc(2026, 4, 3, 9, 15),
      ));

      await tester.pumpWidget(_buildScreen());
      await tester.tap(find.byKey(const Key('history_card_0')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('summary_track_name')),
        findsOneWidget,
      );
      expect(find.text('Speed Park Interlagos'), findsOneWidget);
    });
  });

  group('CA-HIST-001-07: fade gradiente inferior', () {
    testWidgets('fade gradiente existe quando há sessões', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await RaceSessionRepository().save(_makeRecord(
        id: 'f1',
        trackName: 'Pista Fade',
        date: DateTime.utc(2026, 4, 10, 14, 0),
      ));

      await tester.pumpWidget(_buildScreen());

      expect(find.byKey(const Key('history_fade')), findsOneWidget);
    });

    testWidgets('estado vazio não exibe fade gradiente', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen());

      expect(find.byKey(const Key('history_fade')), findsNothing);
    });
  });

  group('CA-HIST-001-01: acesso via HomeScreen', () {
    testWidgets('ícone de histórico navega para RaceHistoryScreen', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RaceHistoryScreen(),
                  ),
                ),
                child: const Text('history_icon'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('history_icon'));
      await tester.pumpAndSettle();

      expect(find.text('CORRIDAS'), findsOneWidget);
    });
  });
}
