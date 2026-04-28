import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/race_session.dart';
import 'package:lapzy/models/race_session_record.dart';
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

RaceSessionRecord _makeRecord({
  String id = 'uuid-001',
  String trackId = 'track-abc',
  String trackName = 'Interlagos',
  List<LapResult> laps = const [],
  int? bestLapMs,
}) {
  final now = DateTime.utc(2026, 4, 28, 14, 0);
  return RaceSessionRecord(
    id: id,
    trackId: trackId,
    trackName: trackName,
    date: now,
    laps: laps,
    bestLapMs: bestLapMs,
    createdAt: now,
  );
}

void main() {
  group('RaceSessionRepository persistência', () {
    group('load', () {
      test('não faz nada quando o storage está vazio', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();

        await repo.load();

        expect(repo.sessions, isEmpty);
      });

      test('carrega sessão salva no storage', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();
        await repo.save(_makeRecord(id: 'uuid-001', trackName: 'Interlagos'));
        repo.clearForTesting();

        await repo.load();

        expect(repo.sessions.length, equals(1));
        expect(repo.sessions.first.id, equals('uuid-001'));
        expect(repo.sessions.first.trackName, equals('Interlagos'));
      });

      test('carrega sessão com laps e setores', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();
        final record = _makeRecord(
          id: 'uuid-002',
          laps: const [
            LapResult(lapMs: 62000, sectors: [20000, 21000, 21000]),
            LapResult(lapMs: 61500, sectors: [19800, 20700, 21000]),
          ],
          bestLapMs: 61500,
        );
        await repo.save(record);
        repo.clearForTesting();

        await repo.load();

        expect(repo.sessions.first.laps.length, equals(2));
        expect(repo.sessions.first.laps[0].sectors, equals([20000, 21000, 21000]));
        expect(repo.sessions.first.bestLapMs, equals(61500));
      });

      test('é idempotente — segunda chamada não duplica sessões', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();
        await repo.save(_makeRecord());
        repo.clearForTesting();

        await repo.load();
        await repo.load();

        expect(repo.sessions.length, equals(1));
      });
    });

    group('save', () {
      test('insere nova sessão no cache', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();

        await repo.save(_makeRecord(id: 'uuid-010', trackName: 'Granja Viana'));

        expect(repo.sessions.length, equals(1));
        expect(repo.sessions.first.trackName, equals('Granja Viana'));
      });

      test('atualiza sessão existente (upsert por id)', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();
        final now = DateTime.utc(2026, 4, 28, 14, 0);
        final original = RaceSessionRecord(
          id: 'uuid-011',
          trackId: 'track-1',
          trackName: 'Pista',
          date: now,
          laps: const [],
          bestLapMs: null,
          createdAt: now,
        );
        await repo.save(original);

        final updated = RaceSessionRecord(
          id: 'uuid-011',
          trackId: 'track-1',
          trackName: 'Pista',
          date: now,
          laps: const [LapResult(lapMs: 60000)],
          bestLapMs: 60000,
          createdAt: now,
        );
        await repo.save(updated);

        expect(repo.sessions.length, equals(1));
        expect(repo.sessions.first.bestLapMs, equals(60000));
      });

      test('persiste múltiplas sessões', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();

        await repo.save(_makeRecord(id: 'uuid-020'));
        await repo.save(_makeRecord(id: 'uuid-021'));
        repo.clearForTesting();

        await repo.load();

        expect(repo.sessions.length, equals(2));
      });
    });

    group('delete', () {
      test('remove sessão do cache', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();
        await repo.save(_makeRecord(id: 'uuid-030'));

        await repo.delete('uuid-030');

        expect(repo.sessions, isEmpty);
      });

      test('remoção persiste após reload', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();
        await repo.save(_makeRecord(id: 'uuid-031'));
        await repo.delete('uuid-031');
        repo.clearForTesting();

        await repo.load();

        expect(repo.sessions, isEmpty);
      });
    });

    group('clearStorageForTesting', () {
      test('limpa cache e storage', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = RaceSessionRepository();
        repo.clearForTesting();
        await repo.save(_makeRecord(id: 'uuid-040'));

        await repo.clearStorageForTesting();
        await repo.load();

        expect(repo.sessions, isEmpty);
      });
    });
  });
}
