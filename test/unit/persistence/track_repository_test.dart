import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/track_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TrackRepository persistência', () {
    group('load', () {
      test('não faz nada quando o storage está vazio', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();

        await repo.load();

        expect(repo.tracks, isEmpty);
      });

      test('carrega pistas salvas no storage', () async {
        final track = Track(
          id: 'uuid-001',
          name: 'Interlagos',
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        );
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        await repo.save(track);
        repo.clearForTesting();

        await repo.load();

        expect(repo.tracks.length, equals(1));
        expect(repo.tracks.first.id, equals('uuid-001'));
        expect(repo.tracks.first.name, equals('Interlagos'));
      });

      test('carrega pista com startFinishLine', () async {
        const line = TrackLine(
          a: GeoPoint(-23.55, -46.63),
          b: GeoPoint(-23.57, -46.61),
        );
        final track = Track(
          id: 'uuid-002',
          name: 'Pista com linha',
          startFinishLine: line,
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        );
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        await repo.save(track);
        repo.clearForTesting();

        await repo.load();

        expect(repo.tracks.first.startFinishLine, isNotNull);
        expect(
          repo.tracks.first.startFinishLine!.a,
          equals(const GeoPoint(-23.55, -46.63)),
        );
      });

      test('carrega pista com sectorBoundaries', () async {
        const boundaries = [
          TrackLine(
            a: GeoPoint(-23.55, -46.63),
            b: GeoPoint(-23.56, -46.62),
          ),
          TrackLine(
            a: GeoPoint(-23.56, -46.62),
            b: GeoPoint(-23.57, -46.61),
          ),
        ];
        final track = Track(
          id: 'uuid-003',
          name: 'Pista com setores',
          sectorBoundaries: boundaries,
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        );
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        await repo.save(track);
        repo.clearForTesting();

        await repo.load();

        expect(repo.tracks.first.sectorBoundaries.length, equals(2));
      });

      test('é idempotente — segunda chamada não duplica pistas', () async {
        final track = Track(
          id: 'uuid-004',
          name: 'Pista',
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        );
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        await repo.save(track);
        repo.clearForTesting();

        await repo.load();
        await repo.load();

        expect(repo.tracks.length, equals(1));
      });

      test('não apaga cache existente quando storage está vazio', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        repo.add(const Track(id: 'test-1', name: 'Pista Teste'));

        await repo.load();

        expect(repo.tracks.length, equals(1));
        expect(repo.tracks.first.id, equals('test-1'));
      });
    });

    group('save', () {
      test('insere nova pista no cache e no storage', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        final track = Track(
          id: 'uuid-010',
          name: 'Nova Pista',
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        );

        await repo.save(track);

        expect(repo.tracks.length, equals(1));
        expect(repo.tracks.first.name, equals('Nova Pista'));
      });

      test('atualiza pista existente (upsert por id)', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        final original = Track(
          id: 'uuid-011',
          name: 'Nome Original',
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        );
        await repo.save(original);

        final updated = original.copyWith(name: 'Nome Atualizado');
        await repo.save(updated);

        expect(repo.tracks.length, equals(1));
        expect(repo.tracks.first.name, equals('Nome Atualizado'));
      });

      test('persiste múltiplas pistas', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();

        await repo.save(Track(
          id: 'uuid-020',
          name: 'Pista A',
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        ));
        await repo.save(Track(
          id: 'uuid-021',
          name: 'Pista B',
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        ));
        repo.clearForTesting();

        await repo.load();

        expect(repo.tracks.length, equals(2));
      });
    });

    group('remove', () {
      test('remove pista do cache e do storage', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        await repo.save(Track(
          id: 'uuid-030',
          name: 'Pista para remover',
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        ));

        await repo.remove('uuid-030');

        expect(repo.tracks, isEmpty);
      });

      test('remoção persiste após reload', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        await repo.save(Track(
          id: 'uuid-031',
          name: 'Pista',
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        ));
        await repo.remove('uuid-031');
        repo.clearForTesting();

        await repo.load();

        expect(repo.tracks, isEmpty);
      });
    });

    group('clearStorageForTesting', () {
      test('limpa cache e storage', () async {
        SharedPreferences.setMockInitialValues({});
        final repo = TrackRepository();
        repo.clearForTesting();
        await repo.save(Track(
          id: 'uuid-040',
          name: 'Pista',
          createdAt: DateTime.utc(2026, 4, 28),
          updatedAt: DateTime.utc(2026, 4, 28),
        ));

        await repo.clearStorageForTesting();
        await repo.load();

        expect(repo.tracks, isEmpty);
      });
    });
  });
}
