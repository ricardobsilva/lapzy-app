import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lapzy/services/gps_source.dart';
import 'package:lapzy/services/internal_gps_service.dart';

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

void main() {
  group('InternalGpsService', () {
    test('info retorna GpsConnectionType.internal', () {
      final service = InternalGpsService();
      expect(service.info.connectionType, equals(GpsConnectionType.internal));
    });

    test('info.name é "GPS interno"', () {
      final service = InternalGpsService();
      expect(service.info.name, equals('GPS interno'));
    });

    test('info.isExternal retorna false', () {
      final service = InternalGpsService();
      expect(service.info.isExternal, isFalse);
    });

    test('positionStream usa streamFactory injetada', () async {
      final controller = StreamController<Position>();
      final service = InternalGpsService(streamFactory: () => controller.stream);

      final positions = <Position>[];
      final sub = service.positionStream.listen(positions.add);

      final t = DateTime(2026, 1, 1);
      controller.add(_pos(-23.5, -46.6, t));
      controller.add(_pos(-23.51, -46.61, t.add(const Duration(seconds: 1))));

      await Future<void>.delayed(Duration.zero);
      sub.cancel();
      await controller.close();

      expect(positions.length, equals(2));
      expect(positions[0].latitude, equals(-23.5));
      expect(positions[1].latitude, equals(-23.51));
    });

    test('positionStream repassa posições sem modificação (CA-GPS-001-14)', () async {
      final t = DateTime(2026, 5, 1, 10, 0, 0);
      final original = _pos(-23.500001, -46.630002, t);
      final controller = StreamController<Position>();
      final service = InternalGpsService(streamFactory: () => controller.stream);

      Position? received;
      final sub = service.positionStream.listen((p) => received = p);

      controller.add(original);
      await Future<void>.delayed(Duration.zero);
      sub.cancel();
      await controller.close();

      expect(received, isNotNull);
      expect(received!.latitude, equals(original.latitude));
      expect(received!.longitude, equals(original.longitude));
      expect(received!.timestamp, equals(original.timestamp));
    });

    test('CA-GPS-001-15: pode ser instanciado em isolamento sem depender de ExternalGpsService',
        () {
      expect(() => InternalGpsService(), returnsNormally);
    });
  });
}
