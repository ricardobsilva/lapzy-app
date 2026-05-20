import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lapzy/services/gps_source.dart';
import 'package:lapzy/services/external_gps_service.dart';

Position _pos(double lat, double lng, DateTime t, double speed) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: t,
      accuracy: 3.0,
      altitude: 100.0,
      altitudeAccuracy: 0.5,
      heading: 45.0,
      headingAccuracy: 1.0,
      speed: speed,
      speedAccuracy: 0.1,
    );

const _kBtInfo = GpsSourceInfo(
  name: 'Garmin GLO 2',
  connectionType: GpsConnectionType.bluetooth,
);

const _kUsbInfo = GpsSourceInfo(
  name: 'Bad Elf GPS Pro+',
  connectionType: GpsConnectionType.usb,
);

void main() {
  group('ExternalGpsService', () {
    test('info retorna o GpsSourceInfo fornecido', () {
      final service = ExternalGpsService(info: _kBtInfo);
      expect(service.info, equals(_kBtInfo));
    });

    test('info.connectionType bluetooth', () {
      final service = ExternalGpsService(info: _kBtInfo);
      expect(service.info.connectionType, equals(GpsConnectionType.bluetooth));
    });

    test('info.connectionType usb', () {
      final service = ExternalGpsService(info: _kUsbInfo);
      expect(service.info.connectionType, equals(GpsConnectionType.usb));
    });

    test('info.isExternal retorna true', () {
      final service = ExternalGpsService(info: _kBtInfo);
      expect(service.info.isExternal, isTrue);
    });

    test('positionStream usa streamFactory injetada', () async {
      final controller = StreamController<Position>();
      final service = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => controller.stream,
      );

      final positions = <Position>[];
      final sub = service.positionStream.listen(positions.add);

      final t = DateTime(2026, 5, 1, 10, 0, 0);
      controller.add(_pos(-23.5, -46.6, t, 14.5));

      await Future<void>.delayed(Duration.zero);
      sub.cancel();
      await controller.close();

      expect(positions.length, equals(1));
    });

    test('CA-GPS-001-14: velocidade não é modificada pelo ExternalGpsService', () async {
      final t = DateTime(2026, 5, 1, 10, 0, 0);
      final rawPosition = _pos(-23.500001, -46.630002, t, 13.89);
      final controller = StreamController<Position>();
      final service = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => controller.stream,
      );

      Position? received;
      final sub = service.positionStream.listen((p) => received = p);
      controller.add(rawPosition);
      await Future<void>.delayed(Duration.zero);
      sub.cancel();
      await controller.close();

      expect(received, isNotNull);
      expect(received!.speed, equals(rawPosition.speed),
          reason: 'ExternalGpsService não deve modificar velocidade');
    });

    test('CA-GPS-001-14: posição não é modificada pelo ExternalGpsService', () async {
      final t = DateTime(2026, 5, 1, 10, 0, 1);
      final rawPosition = _pos(-23.500123, -46.630456, t, 0.0);
      final controller = StreamController<Position>();
      final service = ExternalGpsService(
        info: _kBtInfo,
        streamFactory: () => controller.stream,
      );

      Position? received;
      final sub = service.positionStream.listen((p) => received = p);
      controller.add(rawPosition);
      await Future<void>.delayed(Duration.zero);
      sub.cancel();
      await controller.close();

      expect(received!.latitude, equals(rawPosition.latitude),
          reason: 'ExternalGpsService não deve modificar latitude');
      expect(received!.longitude, equals(rawPosition.longitude),
          reason: 'ExternalGpsService não deve modificar longitude');
      expect(received!.timestamp, equals(rawPosition.timestamp),
          reason: 'ExternalGpsService não deve modificar timestamp');
    });

    test('CA-GPS-001-15: pode ser instanciado em isolamento sem depender de InternalGpsService',
        () {
      expect(() => ExternalGpsService(info: _kBtInfo), returnsNormally);
    });

    test('positionStream padrão é stream vazia quando sem factory', () async {
      final service = ExternalGpsService(info: _kBtInfo);
      final positions = <Position>[];
      final sub = service.positionStream.listen(positions.add);
      await Future<void>.delayed(Duration.zero);
      sub.cancel();
      expect(positions, isEmpty);
    });
  });

  group('GpsSourceInfo serialização', () {
    test('toJson/fromJson bluetooth preserva campos', () {
      const info = GpsSourceInfo(
        name: 'Garmin GLO 2',
        connectionType: GpsConnectionType.bluetooth,
      );
      final restored = GpsSourceInfo.fromJson(info.toJson());
      expect(restored, equals(info));
    });

    test('toJson/fromJson usb preserva campos', () {
      const info = GpsSourceInfo(
        name: 'Bad Elf GPS Pro+',
        connectionType: GpsConnectionType.usb,
      );
      final restored = GpsSourceInfo.fromJson(info.toJson());
      expect(restored, equals(info));
    });

    test('toJson/fromJson internal preserva campos', () {
      const info = GpsSourceInfo(
        name: 'GPS interno',
        connectionType: GpsConnectionType.internal,
      );
      final restored = GpsSourceInfo.fromJson(info.toJson());
      expect(restored, equals(info));
    });

    test('fromJson com tipo desconhecido faz fallback para internal', () {
      final json = {'name': 'Desconhecido', 'connectionType': 'INVALID_TYPE'};
      final info = GpsSourceInfo.fromJson(json);
      expect(info.connectionType, equals(GpsConnectionType.internal));
    });

    test('summaryLabel BT inclui nome e "via BT"', () {
      const info = GpsSourceInfo(
        name: 'Garmin GLO 2',
        connectionType: GpsConnectionType.bluetooth,
      );
      expect(info.summaryLabel, contains('Garmin GLO 2'));
      expect(info.summaryLabel, contains('via BT'));
    });

    test('summaryLabel USB inclui nome e "via USB-C"', () {
      const info = GpsSourceInfo(
        name: 'Bad Elf GPS',
        connectionType: GpsConnectionType.usb,
      );
      expect(info.summaryLabel, contains('Bad Elf GPS'));
      expect(info.summaryLabel, contains('via USB-C'));
    });

    test('summaryLabel internal menciona GPS interno', () {
      const info = GpsSourceInfo(
        name: 'GPS interno',
        connectionType: GpsConnectionType.internal,
      );
      expect(info.summaryLabel, contains('GPS interno'));
    });
  });
}
