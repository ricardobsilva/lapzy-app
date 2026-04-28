import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/race_session.dart';
import 'package:lapzy/models/race_session_record.dart';

void main() {
  group('LapResult serialização', () {
    test('toJson/fromJson preserva lapMs sem setores', () {
      const original = LapResult(lapMs: 62450);
      final restored = LapResult.fromJson(original.toJson());

      expect(restored.lapMs, equals(62450));
      expect(restored.sectors, isEmpty);
    });

    test('toJson/fromJson preserva setores com valores', () {
      const original = LapResult(lapMs: 62450, sectors: [20100, 21300, 21050]);
      final restored = LapResult.fromJson(original.toJson());

      expect(restored.sectors, equals([20100, 21300, 21050]));
    });

    test('toJson/fromJson preserva setores com valores nulos', () {
      const original = LapResult(lapMs: 62450, sectors: [20100, null, 21050]);
      final restored = LapResult.fromJson(original.toJson());

      expect(restored.sectors[0], equals(20100));
      expect(restored.sectors[1], isNull);
      expect(restored.sectors[2], equals(21050));
    });

    test('toJson inclui lapMs e sectors', () {
      const lap = LapResult(lapMs: 60000, sectors: [30000, 30000]);
      final json = lap.toJson();

      expect(json['lapMs'], equals(60000));
      expect(json['sectors'], equals([30000, 30000]));
    });
  });

  group('RaceSessionRecord', () {
    final baseDate = DateTime.utc(2026, 4, 28, 14, 0);
    final baseCreatedAt = DateTime.utc(2026, 4, 28, 14, 30);

    group('campos', () {
      test('armazena todos os campos obrigatórios', () {
        final record = RaceSessionRecord(
          id: 'uuid-001',
          trackId: 'track-abc',
          trackName: 'Interlagos',
          date: baseDate,
          laps: const [],
          bestLapMs: null,
          createdAt: baseCreatedAt,
        );

        expect(record.id, equals('uuid-001'));
        expect(record.trackId, equals('track-abc'));
        expect(record.trackName, equals('Interlagos'));
        expect(record.date, equals(baseDate));
        expect(record.laps, isEmpty);
        expect(record.bestLapMs, isNull);
        expect(record.createdAt, equals(baseCreatedAt));
      });

      test('armazena bestLapMs quando fornecido', () {
        final record = RaceSessionRecord(
          id: 'uuid-001',
          trackId: 'track-abc',
          trackName: 'Pista',
          date: baseDate,
          laps: const [LapResult(lapMs: 60000)],
          bestLapMs: 60000,
          createdAt: baseCreatedAt,
        );

        expect(record.bestLapMs, equals(60000));
      });
    });

    group('serialização', () {
      test('toJson/fromJson preserva todos os campos sem laps', () {
        final original = RaceSessionRecord(
          id: 'uuid-001',
          trackId: 'track-abc',
          trackName: 'Interlagos',
          date: baseDate,
          laps: const [],
          bestLapMs: null,
          createdAt: baseCreatedAt,
        );
        final restored = RaceSessionRecord.fromJson(original.toJson());

        expect(restored.id, equals('uuid-001'));
        expect(restored.trackId, equals('track-abc'));
        expect(restored.trackName, equals('Interlagos'));
        expect(restored.date, equals(baseDate));
        expect(restored.laps, isEmpty);
        expect(restored.bestLapMs, isNull);
        expect(restored.createdAt, equals(baseCreatedAt));
      });

      test('toJson/fromJson preserva laps com setores', () {
        final original = RaceSessionRecord(
          id: 'uuid-002',
          trackId: 'track-xyz',
          trackName: 'Granja Viana',
          date: baseDate,
          laps: const [
            LapResult(lapMs: 62000, sectors: [20000, 21000, 21000]),
            LapResult(lapMs: 61500, sectors: [19800, 20700, 21000]),
          ],
          bestLapMs: 61500,
          createdAt: baseCreatedAt,
        );
        final restored = RaceSessionRecord.fromJson(original.toJson());

        expect(restored.laps.length, equals(2));
        expect(restored.laps[0].lapMs, equals(62000));
        expect(restored.laps[0].sectors, equals([20000, 21000, 21000]));
        expect(restored.laps[1].lapMs, equals(61500));
        expect(restored.bestLapMs, equals(61500));
      });

      test('toJson usa formato ISO 8601 para datas', () {
        final original = RaceSessionRecord(
          id: 'uuid-003',
          trackId: 'track-1',
          trackName: 'Pista',
          date: baseDate,
          laps: const [],
          bestLapMs: null,
          createdAt: baseCreatedAt,
        );
        final json = original.toJson();

        expect(json['date'], isA<String>());
        expect(json['createdAt'], isA<String>());
        expect(() => DateTime.parse(json['date'] as String), returnsNormally);
        expect(
          () => DateTime.parse(json['createdAt'] as String),
          returnsNormally,
        );
      });

      test('toJson/fromJson preserva bestLapMs nulo', () {
        final original = RaceSessionRecord(
          id: 'uuid-004',
          trackId: 'track-1',
          trackName: 'Pista',
          date: baseDate,
          laps: const [],
          bestLapMs: null,
          createdAt: baseCreatedAt,
        );
        final restored = RaceSessionRecord.fromJson(original.toJson());

        expect(restored.bestLapMs, isNull);
      });

      test('trackName é desnormalizado — preservado independentemente do trackId', () {
        final original = RaceSessionRecord(
          id: 'uuid-005',
          trackId: 'id-de-pista-que-pode-ser-deletada',
          trackName: 'Nome Preservado',
          date: baseDate,
          laps: const [],
          bestLapMs: null,
          createdAt: baseCreatedAt,
        );
        final restored = RaceSessionRecord.fromJson(original.toJson());

        expect(restored.trackName, equals('Nome Preservado'));
      });
    });
  });
}
