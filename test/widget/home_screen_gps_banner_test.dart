import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/screens/home_screen.dart';
import 'package:lapzy/services/gps_source.dart';
import 'package:lapzy/services/gps_source_manager.dart';
import 'package:lapzy/services/internal_gps_service.dart';
import 'package:lapzy/services/external_gps_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

const _kBtInfo = GpsSourceInfo(
  name: 'Garmin GLO 2',
  connectionType: GpsConnectionType.bluetooth,
);

const _kUsbInfo = GpsSourceInfo(
  name: 'Bad Elf GPS Pro+',
  connectionType: GpsConnectionType.usb,
);

void main() {
  setUp(() => GpsSourceManager.resetForTesting());
  tearDown(() => GpsSourceManager.resetForTesting());

  group('HomeScreen GPS banner', () {
    testWidgets('CA-GPS-001-03: banner NÃO aparece com GPS interno (estado padrão)',
        (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      GpsSourceManager.resetForTesting(
        GpsSourceManager.forTesting(
          activeSource: InternalGpsService(
            streamFactory: () => const Stream.empty(),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      expect(find.byKey(const Key('home_gps_banner')), findsNothing);
    });

    testWidgets('CA-GPS-001-01: banner aparece com GPS externo Bluetooth', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      GpsSourceManager.resetForTesting(
        GpsSourceManager.forTesting(
          activeSource: ExternalGpsService(
            info: _kBtInfo,
            streamFactory: () => const Stream.empty(),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      expect(find.byKey(const Key('home_gps_banner')), findsOneWidget);
      expect(find.text('Garmin GLO 2'), findsOneWidget);
      expect(find.text('BT'), findsOneWidget);
    });

    testWidgets('CA-GPS-001-02: banner aparece com GPS externo USB-C', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      GpsSourceManager.resetForTesting(
        GpsSourceManager.forTesting(
          activeSource: ExternalGpsService(
            info: _kUsbInfo,
            streamFactory: () => const Stream.empty(),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      expect(find.byKey(const Key('home_gps_banner')), findsOneWidget);
      expect(find.text('Bad Elf GPS Pro+'), findsOneWidget);
      expect(find.text('USB'), findsOneWidget);
    });

    testWidgets('banner some ao receber evento de volta para GPS interno', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});

      final manager = GpsSourceManager.forTesting(
        activeSource: ExternalGpsService(
          info: _kBtInfo,
          streamFactory: () => const Stream.empty(),
        ),
      );
      GpsSourceManager.resetForTesting(manager);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      expect(find.byKey(const Key('home_gps_banner')), findsOneWidget);

      // Muda para GPS interno — deve sumir o banner.
      await manager.setActiveSource(
        InternalGpsService(streamFactory: () => const Stream.empty()),
      );
      await tester.pump();

      expect(find.byKey(const Key('home_gps_banner')), findsNothing);
    });

    testWidgets('CA-GPS-001-04: toque no banner navega para GpsSourceScreen', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      GpsSourceManager.resetForTesting(
        GpsSourceManager.forTesting(
          activeSource: ExternalGpsService(
            info: _kBtInfo,
            streamFactory: () => const Stream.empty(),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      await tester.tap(find.byKey(const Key('home_gps_banner')));
      await tester.pumpAndSettle();

      expect(find.text('FONTE GPS'), findsOneWidget);
    });
  });
}
