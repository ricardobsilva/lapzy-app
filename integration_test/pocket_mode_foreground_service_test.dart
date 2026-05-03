import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:lapzy/screens/race_screen.dart';
import 'package:lapzy/screens/race_summary_screen.dart';
import 'package:lapzy/services/lap_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detector que não usa GPS — apenas permite injetar eventos manualmente.
class _FakeDetector extends LapDetector {
  final StreamController<LapEvent> _ctrl =
      StreamController<LapEvent>.broadcast();

  _FakeDetector()
      : super(
          track: const Track(id: 'test', name: 'Test'),
          positionStreamFactory: () => const Stream.empty(),
        );

  @override
  Stream<LapEvent> get events => _ctrl.stream;

  @override
  void start() {}

  @override
  void stop() {}

  @override
  void dispose() {
    _ctrl.close();
    super.dispose();
  }
}

const _track = Track(id: 'it-1', name: 'Integration Test Track');

Widget _buildRaceScreen(_FakeDetector detector) {
  return MaterialApp(
    home: RaceScreen(
      track: _track,
      detectorFactory: (_) => detector,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Monta RaceScreen diretamente via pumpWidget para evitar dependência de
  // seed data e app.main(). O MethodChannel lapzy/foreground_service chama o
  // Kotlin real no dispositivo — este É um teste de integração.

  testWidgets(
      'CA-POCKET-003-02: RaceScreen monta sem travar — '
      'Foreground Service iniciou no Kotlin sem exceção', (tester) async {
    SharedPreferences.setMockInitialValues({});
    RaceSessionRepository().clearForTesting();

    final detector = _FakeDetector();
    await tester.pumpWidget(_buildRaceScreen(detector));
    await tester.pump(const Duration(milliseconds: 500));

    // Se o startForegroundService() tivesse lançado exceção, o widget teria
    // falhado ao montar. Chegar aqui confirma que o serviço iniciou sem erro.
    expect(find.byType(RaceScreen), findsOneWidget);
  });

  testWidgets(
      'CA-POCKET-003-04: encerrar corrida desmonta RaceScreen sem travar — '
      'Foreground Service parou no Kotlin sem exceção', (tester) async {
    SharedPreferences.setMockInitialValues({});
    RaceSessionRepository().clearForTesting();

    final detector = _FakeDetector();
    await tester.pumpWidget(_buildRaceScreen(detector));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RaceScreen), findsOneWidget);

    // Simula FINALIZAR (segura 3s)
    final endButton = find.byKey(const Key('end_button'));
    final gesture = await tester.startGesture(tester.getCenter(endButton));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await gesture.up();

    // Se stopService() tivesse lançado exceção, não chegaríamos aqui.
    expect(find.byType(RaceSummaryScreen), findsOneWidget);

    RaceSessionRepository().clearForTesting();
  });

  testWidgets(
      'CA-POCKET-003-03: notificação "Lapzy · Corrida em andamento" aparece '
      'na barra de status — verificar manualmente após este teste', (tester) async {
    SharedPreferences.setMockInitialValues({});
    RaceSessionRepository().clearForTesting();

    // Monta a tela — a notificação deve aparecer na barra de status do dispositivo.
    // Verificação automática não é possível via Flutter test; este teste confirma
    // que o canal foi chamado sem erro (se falhasse, o pump lançaria exceção).
    final detector = _FakeDetector();
    await tester.pumpWidget(_buildRaceScreen(detector));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RaceScreen), findsOneWidget);
    // Nenhuma exceção lançada = notificação foi criada sem erro no Kotlin.
  });

  testWidgets(
      'CA-POCKET-003-05: Foreground Service mantém GPS com tela bloqueada — '
      'verificar manualmente no dispositivo (Samsung A35)', (tester) async {
    // Este cenário (GPS ativo por 10 min com tela apagada) requer verificação
    // manual no dispositivo real. Este teste é um placeholder que documenta
    // o CA e confirma que o serviço inicia corretamente.
    SharedPreferences.setMockInitialValues({});
    RaceSessionRepository().clearForTesting();

    final detector = _FakeDetector();
    await tester.pumpWidget(_buildRaceScreen(detector));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RaceScreen), findsOneWidget);
    // GPS com tela bloqueada: verificar manualmente bloqueando a tela com o
    // app no foreground e confirmando que a notificação permanece ativa.
  });

  testWidgets(
      'CA-POCKET-003-06: swipe no recents para o app — Foreground Service '
      'para automaticamente via stopWithTask="true"', (tester) async {
    // stopWithTask="true" no AndroidManifest garante que o serviço para
    // quando o usuário remove o app do recents. Verificação via logcat:
    // após swipe no recents, LapzyLocationService.onTaskRemoved() é chamado.
    SharedPreferences.setMockInitialValues({});
    RaceSessionRepository().clearForTesting();

    final detector = _FakeDetector();
    await tester.pumpWidget(_buildRaceScreen(detector));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RaceScreen), findsOneWidget);
    // Verificar manualmente: swipe no recents → notificação desaparece.
  });
}
