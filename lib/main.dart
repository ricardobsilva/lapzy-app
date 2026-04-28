import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'debug/seed_data.dart';
import 'repositories/race_session_repository.dart';
import 'repositories/track_repository.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await TrackRepository().load();
  await RaceSessionRepository().load();
  await seedDebugDataIfNeeded();
  runApp(const LapzyApp());
}

class LapzyApp extends StatelessWidget {
  const LapzyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lapzy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          surface: Color(0xFF141414),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
      },
    );
  }
}
