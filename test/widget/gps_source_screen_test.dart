import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/screens/gps_source_screen.dart';
import 'package:lapzy/services/gps_source.dart';
import 'package:lapzy/services/gps_source_manager.dart';
import 'package:lapzy/services/internal_gps_service.dart';
import 'package:lapzy/services/external_gps_service.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

const _kBtInfo = GpsSourceInfo(
  name: 'Garmin GLO 2',
  connectionType: GpsConnectionType.bluetooth,
);

GpsSourceManager _internalManager() => GpsSourceManager.forTesting(
      activeSource: InternalGpsService(
        streamFactory: () => const Stream.empty(),
      ),
    );

GpsSourceManager _btManager() => GpsSourceManager.forTesting(
      activeSource: ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => const Stream.empty(),
      ),
    );

Stream<List<ExternalGpsService>> _emptyBtScanner() async* {
  yield [];
}

Stream<List<ExternalGpsService>> _btScannerWith(ExternalGpsService device) async* {
  yield [device];
}

void main() {
  group('GpsSourceScreen', () {
    testWidgets('CA-GPS-001-05: exibe seção ATIVO com dispositivo atual', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: _emptyBtScanner,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ATIVO'), findsOneWidget);
      expect(find.byKey(const Key('gps_active_card')), findsOneWidget);
      expect(find.byKey(const Key('gps_active_name')), findsOneWidget);
    });

    testWidgets('CA-GPS-001-05: exibe seção DISPOSITIVOS DISPONÍVEIS', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: _emptyBtScanner,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('DISPOSITIVOS DISPONÍVEIS'), findsOneWidget);
    });

    testWidgets('CA-GPS-001-06: GPS interno sempre visível e nunca desabilitado', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: _emptyBtScanner,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gps_item_internal')), findsOneWidget);
      expect(find.text('GPS interno do celular'), findsOneWidget);
    });

    testWidgets('CA-GPS-001-07: USB-C aparece desabilitado quando sem cabo', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: _emptyBtScanner,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gps_item_usb')), findsOneWidget);
      expect(find.textContaining('Nenhum cabo conectado'), findsOneWidget);
    });

    testWidgets('CA-GPS-001-09: indicador de scan ativo durante descoberta BT', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final scanController = StreamController<List<ExternalGpsService>>();

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: () => scanController.stream,
        ),
      ));
      await tester.pump();

      expect(find.byKey(const Key('gps_bt_scanning')), findsOneWidget);

      await scanController.close();
    });

    testWidgets('exibe "nenhum dispositivo encontrado" quando scan termina sem resultados',
        (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: _emptyBtScanner,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gps_bt_empty')), findsOneWidget);
    });

    testWidgets('exibe dispositivo BT encontrado durante scan', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final device = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => const Stream.empty(),
      );

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: () => _btScannerWith(device),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gps_device_0')), findsOneWidget);
      expect(find.text('Garmin GLO 2'), findsOneWidget);
    });

    testWidgets('botão "USAR ESTE GPS" desabilitado quando seleção igual ao ativo', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: _emptyBtScanner,
        ),
      ));
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('gps_apply_button'));
      expect(button, findsOneWidget);
      final container = tester.widget<Container>(button);
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.color,
        isNot(const Color(0xFF00E676)),
        reason: 'Botão deve estar desabilitado quando GPS interno já está ativo',
      );
    });

    testWidgets('CA-GPS-001-08: selecionar dispositivo + USAR ESTE GPS chama setActiveSource',
        (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Stream persistente — não fecha imediatamente para não acionar fallback automático.
      final btDeviceController = StreamController<Position>();
      addTearDown(btDeviceController.close);

      final device = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => btDeviceController.stream,
      );

      final manager = _internalManager();

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: manager,
          btScannerFactory: () => _btScannerWith(device),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gps_device_0')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('gps_apply_button')));
      await tester.pumpAndSettle();

      expect(manager.activeSource.info, equals(_kBtInfo));
    });

    testWidgets('CA-GPS-001-09: scan BT para ao sair da tela', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool scanCancelled = false;
      final scanController = StreamController<List<ExternalGpsService>>(
        onCancel: () => scanCancelled = true,
      );
      // Não usar await scanController.close() após o cancel — o close() bufferiza
      // quando não há listeners e o Future nunca completa.
      addTearDown(scanController.close);

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: () => scanController.stream,
        ),
      ));
      await tester.pump();

      expect(scanCancelled, isFalse);

      // Remove a tela do widget tree — aciona o dispose do State.
      await tester.pumpWidget(const SizedBox());

      expect(scanCancelled, isTrue);
    });
  });

  group('GpsSourceScreen com GPS externo ativo', () {
    testWidgets('seção ATIVO exibe nome do dispositivo externo', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _btManager(),
          btScannerFactory: _emptyBtScanner,
        ),
      ));
      await tester.pumpAndSettle();

      final activeName = tester.widget<Text>(
        find.byKey(const Key('gps_active_name')),
      );
      expect(activeName.data, equals('Garmin GLO 2'));
    });
  });
}
