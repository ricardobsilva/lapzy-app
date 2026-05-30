import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
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

Stream<ExternalGpsService?> _noUsbDetector() async* {
  yield null;
}

Stream<ExternalGpsService?> _usbDetectorWith(ExternalGpsService device) async* {
  yield device;
}

const _kUsbInfo = GpsSourceInfo(
  name: 'Bad Elf GPS Pro+',
  connectionType: GpsConnectionType.usb,
);

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
          usbDetectorFactory: _noUsbDetector,
        ),
      ));
      await tester.pumpAndSettle();

      final activeName = tester.widget<Text>(
        find.byKey(const Key('gps_active_name')),
      );
      expect(activeName.data, equals('Garmin GLO 2'));
    });
  });

  group('GpsSourceScreen — fallback automático por desconexão', () {
    testWidgets('USB desconecta enquanto ativo: ATIVO card muda para GPS interno',
        (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final usbController = StreamController<ExternalGpsService?>(sync: true);
      addTearDown(usbController.close);

      final usbDevice = ExternalGpsService(
        info: _kUsbInfo,
        streamFactory: () => const Stream.empty(),
      );

      final manager = GpsSourceManager.forTesting(
        activeSource: ExternalGpsService(
          info: _kUsbInfo,
          streamFactory: () => const Stream.empty(),
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: manager,
          btScannerFactory: _emptyBtScanner,
          usbDetectorFactory: () => usbController.stream,
        ),
      ));
      await tester.pump();

      // Confirma que ATIVO mostra USB.
      usbController.add(usbDevice);
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('gps_active_name'))).data,
        equals('Bad Elf GPS Pro+'),
      );

      // Despluga o cabo — ATIVO card deve atualizar para GPS interno.
      usbController.add(null);
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const Key('gps_active_name'))).data,
        equals('GPS interno'),
      );
    });

    testWidgets('USB desconecta enquanto ativo: manager.activeSource muda para interno',
        (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final usbController = StreamController<ExternalGpsService?>(sync: true);
      addTearDown(usbController.close);

      final usbDevice = ExternalGpsService(
        info: _kUsbInfo,
        streamFactory: () => const Stream.empty(),
      );

      final manager = GpsSourceManager.forTesting(
        activeSource: ExternalGpsService(
          info: _kUsbInfo,
          streamFactory: () => const Stream.empty(),
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: manager,
          btScannerFactory: _emptyBtScanner,
          usbDetectorFactory: () => usbController.stream,
        ),
      ));
      await tester.pump();

      usbController.add(usbDevice);
      await tester.pump();

      // Despluga o cabo.
      usbController.add(null);
      await tester.pump();

      expect(manager.activeSource.info.connectionType, equals(GpsConnectionType.internal));
    });

    testWidgets('fallback via manager.events: ATIVO card e selectedSource atualizam',
        (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final btService = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => const Stream.empty(),
      );
      final internalService = InternalGpsService(
        streamFactory: () => const Stream.empty(),
      );

      final manager = GpsSourceManager.forTesting(
        activeSource: btService,
        internalFallback: internalService,
      );

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: manager,
          btScannerFactory: _emptyBtScanner,
          usbDetectorFactory: _noUsbDetector,
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Confirma que ATIVO mostra BT.
      expect(
        tester.widget<Text>(find.byKey(const Key('gps_active_name'))).data,
        equals('Garmin GLO 2'),
      );

      // Manager emite fallback → widget deve atualizar ATIVO card.
      manager.simulateFallbackForTesting(internalService);
      await tester.pump(); // entrega evento do stream ao listener → setState
      await tester.pump(); // processa frame agendado pelo setState → rebuild

      expect(
        tester.widget<Text>(find.byKey(const Key('gps_active_name'))).data,
        equals('GPS interno'),
      );
    });
  });

  group('GpsSourceScreen USB-C (CA-GPS-001-07)', () {
    testWidgets('item USB desabilitado quando nenhum dispositivo detectado', (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: _emptyBtScanner,
          usbDetectorFactory: _noUsbDetector,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gps_item_usb')), findsOneWidget);
      expect(find.textContaining('Nenhum cabo conectado'), findsOneWidget);
    });

    testWidgets('CA-GPS-001-07: item USB ativado automaticamente quando cabo é plugado',
        (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final usbController = StreamController<ExternalGpsService?>(sync: true);
      addTearDown(usbController.close);

      final usbDevice = ExternalGpsService(
        info: _kUsbInfo,
        streamFactory: () => const Stream.empty(),
      );

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: _emptyBtScanner,
          usbDetectorFactory: () => usbController.stream,
        ),
      ));
      await tester.pump();

      // Inicialmente sem dispositivo USB.
      usbController.add(null);
      await tester.pump();
      expect(find.textContaining('Nenhum cabo conectado'), findsOneWidget);

      // Cabo plugado — item USB deve ativar sem reiniciar a tela.
      usbController.add(usbDevice);
      await tester.pump();

      expect(find.text('USB-C · Bad Elf GPS Pro+'), findsOneWidget);
      expect(find.textContaining('Nenhum cabo conectado'), findsNothing);
    });

    testWidgets('CA-GPS-001-07: item USB desabilita novamente ao desplugar cabo',
        (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final usbController = StreamController<ExternalGpsService?>(sync: true);
      addTearDown(usbController.close);

      final usbDevice = ExternalGpsService(
        info: _kUsbInfo,
        streamFactory: () => const Stream.empty(),
      );

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: _internalManager(),
          btScannerFactory: _emptyBtScanner,
          usbDetectorFactory: () => usbController.stream,
        ),
      ));
      await tester.pump();

      // Conecta e depois desconecta.
      usbController.add(usbDevice);
      await tester.pump();
      expect(find.text('USB-C · Bad Elf GPS Pro+'), findsOneWidget);

      usbController.add(null);
      await tester.pump();
      expect(find.textContaining('Nenhum cabo conectado'), findsOneWidget);
    });

    testWidgets('CA-GPS-001-08: selecionar USB + USAR ESTE GPS aplica fonte USB',
        (tester) async {
      _setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final usbStreamController = StreamController<Position>();
      addTearDown(usbStreamController.close);

      final usbDevice = ExternalGpsService(
        info: _kUsbInfo,
        streamFactory: () => usbStreamController.stream,
      );

      final manager = _internalManager();

      await tester.pumpWidget(MaterialApp(
        home: GpsSourceScreen(
          manager: manager,
          btScannerFactory: _emptyBtScanner,
          usbDetectorFactory: () => _usbDetectorWith(usbDevice),
        ),
      ));
      await tester.pumpAndSettle();

      // Toca no item USB.
      await tester.tap(find.byKey(const Key('gps_item_usb')));
      await tester.pump();

      // Confirma.
      await tester.tap(find.byKey(const Key('gps_apply_button')));
      await tester.pumpAndSettle();

      expect(manager.activeSource.info, equals(_kUsbInfo));
    });
  });
}
