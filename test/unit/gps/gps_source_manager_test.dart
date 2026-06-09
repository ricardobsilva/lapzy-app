import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapzy/services/gps_diagnostics.dart';
import 'package:lapzy/services/gps_diagnostics_service.dart';
import 'package:lapzy/services/gps_source.dart';
import 'package:lapzy/services/gps_source_manager.dart';
import 'package:lapzy/services/internal_gps_service.dart';
import 'package:lapzy/services/external_gps_service.dart';

Position _pos(double lat, double lng, DateTime t) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: t,
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

const _kBtInfo = GpsSourceInfo(
  name: 'Garmin GLO 2',
  connectionType: GpsConnectionType.bluetooth,
);

void main() {
  setUp(() {
    GpsSourceManager.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => GpsSourceManager.resetForTesting());

  group('estado inicial', () {
    test('activeSource padrão é InternalGpsService', () {
      final manager = GpsSourceManager.instance;
      expect(manager.activeSource, isA<InternalGpsService>());
    });

    test('activeSource.info é GPS interno', () {
      expect(
        GpsSourceManager.instance.activeSource.info.connectionType,
        equals(GpsConnectionType.internal),
      );
    });
  });

  group('setActiveSource', () {
    test('muda activeSource para ExternalGpsService', () async {
      final controller = StreamController<Position>();
      final external = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => controller.stream,
      );

      final manager = GpsSourceManager.forTesting(activeSource: InternalGpsService(
        streamFactory: () => const Stream.empty(),
      ));
      GpsSourceManager.resetForTesting(manager);

      await manager.setActiveSource(external);
      expect(manager.activeSource, isA<ExternalGpsService>());
      expect(manager.activeSource.info, equals(_kBtInfo));

      await controller.close();
    });

    test('emite evento userChoice no stream events', () async {
      final btController = StreamController<Position>();

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () => const Stream.empty()),
      );
      GpsSourceManager.resetForTesting(manager);

      final events = <GpsSourceChangedEvent>[];
      final sub = manager.events.listen(events.add);

      final external = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => btController.stream,
      );
      await manager.setActiveSource(external);

      expect(events.length, equals(1));
      expect(events.first.reason, equals(GpsSourceChangeReason.userChoice));
      expect(events.first.source.info, equals(_kBtInfo));

      sub.cancel();
      await btController.close();
    });

    test('persiste a escolha no SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final btController = StreamController<Position>();

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () => const Stream.empty()),
        prefs: prefs,
      );
      GpsSourceManager.resetForTesting(manager);

      final external = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => btController.stream,
      );
      await manager.setActiveSource(external);

      expect(prefs.getString('lapzy_gps_source_v1'), isNotNull);
      expect(
        prefs.getString('lapzy_gps_source_v1'),
        contains('Garmin GLO 2'),
      );

      await btController.close();
    });
  });

  group('positionStream', () {
    test('repassa posições da fonte ativa', () async {
      final controller = StreamController<Position>();
      final internal = InternalGpsService(streamFactory: () => controller.stream);

      final manager = GpsSourceManager.forTesting(activeSource: internal);
      GpsSourceManager.resetForTesting(manager);
      await manager.init();

      final positions = <Position>[];
      final sub = manager.positionStream.listen(positions.add);

      final t = DateTime(2026, 1, 1);
      controller.add(_pos(-23.5, -46.6, t));
      controller.add(_pos(-23.51, -46.61, t.add(const Duration(seconds: 1))));

      await Future<void>.delayed(Duration.zero);
      sub.cancel();
      await controller.close();

      expect(positions.length, equals(2));
      expect(positions[0].latitude, closeTo(-23.5, 1e-9));
    });

    test('CA-GPS-001-11: fallback para interno quando externo desconecta (stream fecha)', () async {
      final externalController = StreamController<Position>();

      final external = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => externalController.stream,
      );

      final manager = GpsSourceManager.forTesting(
        activeSource: external,
        internalFallback: InternalGpsService(streamFactory: () => const Stream.empty()),
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();

      expect(manager.activeSource, isA<ExternalGpsService>());

      final events = <GpsSourceChangedEvent>[];
      final eventSub = manager.events.listen(events.add);

      await externalController.close();
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeSource, isA<InternalGpsService>());
      expect(events.length, equals(1));
      expect(events.first.reason, equals(GpsSourceChangeReason.fallback));

      eventSub.cancel();
    });

    test('CA-GPS-001-11: fallback para interno quando externo dá erro', () async {
      final externalController = StreamController<Position>();

      final external = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => externalController.stream,
      );

      final manager = GpsSourceManager.forTesting(
        activeSource: external,
        internalFallback: InternalGpsService(streamFactory: () => const Stream.empty()),
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();

      final events = <GpsSourceChangedEvent>[];
      final eventSub = manager.events.listen(events.add);

      externalController.addError(Exception('BT disconnected'));
      await Future<void>.delayed(Duration.zero);

      expect(manager.activeSource, isA<InternalGpsService>());
      expect(events.first.reason, equals(GpsSourceChangeReason.fallback));

      eventSub.cancel();
      await externalController.close();
    });
  });

  group('persistência', () {
    test('loadPersistedSource com GPS externo persistido reseta para GPS interno', () async {
      // GPS externo não pode ser restaurado automaticamente (conexão física perdida).
      // O app deve iniciar com GPS interno e o usuário reconecta via GpsSourceScreen.
      SharedPreferences.setMockInitialValues({
        'lapzy_gps_source_v1': '{"name":"Garmin GLO 2","connectionType":"bluetooth"}',
      });
      final prefs = await SharedPreferences.getInstance();

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () => const Stream.empty()),
        prefs: prefs,
      );
      await manager.init();

      expect(manager.activeSource, isA<InternalGpsService>());
      expect(manager.activeSource.info.connectionType,
          equals(GpsConnectionType.internal));
    });

    test('loadPersistedSource com JSON inválido mantém GPS interno', () async {
      SharedPreferences.setMockInitialValues({
        'lapzy_gps_source_v1': 'INVALID_JSON!!!',
      });
      final prefs = await SharedPreferences.getInstance();

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () => const Stream.empty()),
        prefs: prefs,
      );
      await manager.init();

      expect(manager.activeSource, isA<InternalGpsService>());
    });

    test('loadPersistedSource sem chave mantém GPS interno', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () => const Stream.empty()),
        prefs: prefs,
      );
      await manager.init();

      expect(manager.activeSource, isA<InternalGpsService>());
    });

    test('CA-GPS-001-08: após selecionar GPS externo e reiniciar, app inicia com GPS interno', () async {
      // GPS externo é selecionado na sessão anterior → preferência persistida.
      // No próximo startup, app reinicia com GPS interno (conexão física não persiste).
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final btController = StreamController<Position>();

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () => const Stream.empty()),
        prefs: prefs,
      );
      GpsSourceManager.resetForTesting(manager);

      final external = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => btController.stream,
      );
      await manager.setActiveSource(external);

      GpsSourceManager.resetForTesting();

      final manager2 = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () => const Stream.empty()),
        prefs: prefs,
      );
      await manager2.init();

      // Após restart, GPS externo é resetado para interno automaticamente.
      expect(manager2.activeSource, isA<InternalGpsService>());
      expect(manager2.activeSource.info.connectionType,
          equals(GpsConnectionType.internal));

      await btController.close();
    });
  });

  group('watchdog de primeira posição', () {
    const kTimeout = Duration(milliseconds: 10);
    const kWait = Duration(milliseconds: 60);

    test('reinicia subscription uma vez após timeout sem dados', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var subscribeCount = 0;
      final controllers = <StreamController<Position>>[];

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(
          streamFactory: () {
            subscribeCount++;
            final ctrl = StreamController<Position>();
            controllers.add(ctrl);
            return ctrl.stream;
          },
        ),
        prefs: prefs,
        watchdogTimeout: kTimeout,
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();
      expect(subscribeCount, equals(1));

      await Future<void>.delayed(kWait);
      expect(subscribeCount, equals(2));

      await Future<void>.delayed(kWait);
      expect(subscribeCount, equals(2));

      for (final c in controllers) {
        await c.close();
      }
      GpsSourceManager.resetForTesting();
    });

    test('watchdog não dispara se posição chegou antes do timeout', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var subscribeCount = 0;
      final ctrl = StreamController<Position>();

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () {
          subscribeCount++;
          return ctrl.stream;
        }),
        prefs: prefs,
        watchdogTimeout: kTimeout,
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();

      ctrl.add(_pos(-23.5, -46.6, DateTime(2026)));
      await Future<void>.delayed(kWait);
      expect(subscribeCount, equals(1));

      await ctrl.close();
      GpsSourceManager.resetForTesting();
    });

    test('posições chegam normalmente após watchdog esgotar retries', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late StreamController<Position> lastCtrl;
      var subscribeCount = 0;

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(
          streamFactory: () {
            subscribeCount++;
            lastCtrl = StreamController<Position>();
            return lastCtrl.stream;
          },
        ),
        prefs: prefs,
        watchdogTimeout: kTimeout,
      );
      GpsSourceManager.resetForTesting(manager);

      final received = <Position>[];
      final sub = manager.positionStream.listen(received.add);

      await manager.init();
      await Future<void>.delayed(kWait * 3);
      expect(subscribeCount, equals(2));

      lastCtrl.add(_pos(-23.5, -46.6, DateTime(2026)));
      await Future<void>.delayed(Duration.zero);
      expect(received.length, equals(1));

      await sub.cancel();
      await lastCtrl.close();
      GpsSourceManager.resetForTesting();
    });

    test('watchdog de externo não interfere em interno após fallback', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var internalCount = 0;
      final externalCtrl = StreamController<Position>();
      final internalCtrls = <StreamController<Position>>[];

      final external = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => externalCtrl.stream,
      );

      final manager = GpsSourceManager.forTesting(
        activeSource: external,
        internalFallback: InternalGpsService(streamFactory: () {
          internalCount++;
          final c = StreamController<Position>();
          internalCtrls.add(c);
          return c.stream;
        }),
        prefs: prefs,
        watchdogTimeout: kTimeout,
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();

      externalCtrl.addError(Exception('BT disconnect'));
      await Future<void>.delayed(Duration.zero);
      expect(manager.activeSource, isA<InternalGpsService>());
      expect(internalCount, equals(1));

      await Future<void>.delayed(kWait);
      expect(internalCount, equals(2));

      await Future<void>.delayed(kWait);
      expect(internalCount, equals(2));

      await externalCtrl.close();
      for (final c in internalCtrls) {
        await c.close();
      }
      GpsSourceManager.resetForTesting();
    });
  });

  group('permissão de localização', () {
    test('erro de permissão não dispara retry normal — solicita permissão ao usuário', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var subscribeCount = 0;
      final ctrl = StreamController<Position>();
      var permissionRequested = false;

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(
          streamFactory: () {
            subscribeCount++;
            return ctrl.stream;
          },
        ),
        prefs: prefs,
        permissionRequester: () async {
          permissionRequested = true;
          return LocationPermission.denied;
        },
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();

      ctrl.addError(Exception('User denied permissions to access the device location'));
      await Future<void>.delayed(Duration.zero);

      expect(permissionRequested, isTrue);
      expect(subscribeCount, equals(1));

      await ctrl.close();
      GpsSourceManager.resetForTesting();
    });

    test('quando permissão é concedida, GPS reinicia automaticamente', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var subscribeCount = 0;
      final ctrls = <StreamController<Position>>[];

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(
          streamFactory: () {
            subscribeCount++;
            final c = StreamController<Position>();
            ctrls.add(c);
            return c.stream;
          },
        ),
        prefs: prefs,
        permissionRequester: () async => LocationPermission.whileInUse,
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();
      expect(subscribeCount, equals(1));

      ctrls.first.addError(Exception('User denied permissions'));
      await Future<void>.delayed(Duration.zero);

      expect(subscribeCount, equals(2));

      for (final c in ctrls) { await c.close(); }
      GpsSourceManager.resetForTesting();
    });

    test('quando permissão é negada permanentemente, abre configurações', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctrl = StreamController<Position>();
      var settingsOpened = false;

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () => ctrl.stream),
        prefs: prefs,
        permissionRequester: () async => LocationPermission.deniedForever,
        appSettingsOpener: () async {
          settingsOpened = true;
          return true;
        },
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();

      ctrl.addError(Exception('permission denied'));
      await Future<void>.delayed(Duration.zero);

      expect(settingsOpened, isTrue);

      await ctrl.close();
      GpsSourceManager.resetForTesting();
    });

    test('quando permissão é negada, estado diagnóstico muda para permissionDenied', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      GpsDiagnosticsService.resetForTesting();
      final ctrl = StreamController<Position>();

      final manager = GpsSourceManager.forTesting(
        activeSource: InternalGpsService(streamFactory: () => ctrl.stream),
        prefs: prefs,
        permissionRequester: () async => LocationPermission.denied,
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();

      ctrl.addError(Exception('User denied permissions'));
      await Future<void>.delayed(Duration.zero);

      expect(
        GpsDiagnosticsService.instance.current.fixState,
        equals(GpsFixState.permissionDenied),
      );

      await ctrl.close();
      GpsSourceManager.resetForTesting();
      GpsDiagnosticsService.resetForTesting();
    });

    test('erro de permissão em GPS externo não bloqueia — faz fallback normal', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var permissionRequested = false;
      final externalCtrl = StreamController<Position>();

      final external = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => externalCtrl.stream,
      );

      final manager = GpsSourceManager.forTesting(
        activeSource: external,
        internalFallback: InternalGpsService(streamFactory: () => const Stream.empty()),
        prefs: prefs,
        permissionRequester: () async {
          permissionRequested = true;
          return LocationPermission.denied;
        },
      );
      GpsSourceManager.resetForTesting(manager);
      await manager.init();

      externalCtrl.addError(Exception('denied permissions'));
      await Future<void>.delayed(Duration.zero);

      expect(permissionRequested, isFalse);
      expect(manager.activeSource, isA<InternalGpsService>());

      await externalCtrl.close();
      GpsSourceManager.resetForTesting();
    });
  });

  group('isolamento CA-GPS-001-13', () {
    test('positionStream de InternalGpsService não aplica processamento do Externo',
        () async {
      final internalController = StreamController<Position>();
      final internal = InternalGpsService(
        streamFactory: () => internalController.stream,
      );

      final manager = GpsSourceManager.forTesting(activeSource: internal);
      await manager.init();

      final received = <Position>[];
      final sub = manager.positionStream.listen(received.add);

      final t = DateTime(2026, 5, 1);
      internalController.add(_pos(-23.5, -46.6, t));
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received.first.latitude, equals(-23.5),
          reason: 'Posição interna não deve ser modificada');

      sub.cancel();
      await internalController.close();
    });

    test('CA-GPS-001-13: trocar para externo não aplica lógica interna às posições', () async {
      final externalController = StreamController<Position>();
      final external = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => externalController.stream,
      );

      final manager = GpsSourceManager.forTesting(activeSource: external);
      await manager.init();

      final received = <Position>[];
      final sub = manager.positionStream.listen(received.add);

      final t = DateTime(2026, 5, 1);
      final rawPos = _pos(-23.500001, -46.630002, t);
      externalController.add(rawPos);
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received.first.latitude, equals(rawPos.latitude),
          reason: 'ExternalGpsService não deve modificar lat/lng');
      expect(received.first.longitude, equals(rawPos.longitude));
      expect(received.first.timestamp, equals(rawPos.timestamp));

      sub.cancel();
      await externalController.close();
    });
  });
}
