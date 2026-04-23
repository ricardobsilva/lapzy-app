import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/race_session.dart';
import 'package:lapzy/services/delta_calculator.dart';

void main() {
  group('DeltaCalculator', () {
    group('quando não há best anterior (primeira volta)', () {
      test('retorna estado melhorVolta', () {
        final result = DeltaCalculator.compute(
          lapMs: 84000,
          previousBestMs: null,
        );

        expect(result.eventState, RaceEventState.melhorVolta);
      });

      test('delta é null (sem referência)', () {
        final result = DeltaCalculator.compute(
          lapMs: 84000,
          previousBestMs: null,
        );

        expect(result.deltaMs, isNull);
      });

      test('newBestLapMs é o tempo da volta atual', () {
        final result = DeltaCalculator.compute(
          lapMs: 84000,
          previousBestMs: null,
        );

        expect(result.newBestLapMs, 84000);
      });
    });

    group('quando a volta atual é mais rápida que o best anterior', () {
      test('retorna estado voltaMelhor sem PR threshold', () {
        final result = DeltaCalculator.compute(
          lapMs: 83000,
          previousBestMs: 84000,
        );

        expect(result.eventState, RaceEventState.voltaMelhor);
      });

      test('delta é positivo (melhoria)', () {
        final result = DeltaCalculator.compute(
          lapMs: 83000,
          previousBestMs: 84000,
        );

        expect(result.deltaMs, 1000);
      });

      test('newBestLapMs é atualizado para o tempo atual', () {
        final result = DeltaCalculator.compute(
          lapMs: 83000,
          previousBestMs: 84000,
        );

        expect(result.newBestLapMs, 83000);
      });

      test('retorna estado personalRecord quando abaixo do threshold de PR', () {
        final result = DeltaCalculator.compute(
          lapMs: 82000,
          previousBestMs: 84000,
          prThresholdMs: 83000,
        );

        expect(result.eventState, RaceEventState.personalRecord);
      });

      test('não retorna personalRecord quando igual ao threshold', () {
        final result = DeltaCalculator.compute(
          lapMs: 83000,
          previousBestMs: 84000,
          prThresholdMs: 83000,
        );

        expect(result.eventState, RaceEventState.voltaMelhor);
      });

      test('não retorna personalRecord quando PR threshold é null', () {
        final result = DeltaCalculator.compute(
          lapMs: 82000,
          previousBestMs: 84000,
        );

        expect(result.eventState, isNot(RaceEventState.personalRecord));
      });
    });

    group('quando a volta atual é mais lenta que o best anterior', () {
      test('retorna estado voltaPior', () {
        final result = DeltaCalculator.compute(
          lapMs: 85000,
          previousBestMs: 84000,
        );

        expect(result.eventState, RaceEventState.voltaPior);
      });

      test('delta é negativo (piora)', () {
        final result = DeltaCalculator.compute(
          lapMs: 85000,
          previousBestMs: 84000,
        );

        expect(result.deltaMs, -1000);
      });

      test('newBestLapMs permanece com o best anterior', () {
        final result = DeltaCalculator.compute(
          lapMs: 85000,
          previousBestMs: 84000,
        );

        expect(result.newBestLapMs, 84000);
      });
    });

    group('quando a volta atual é igual ao best anterior', () {
      test('retorna estado voltaPior (não é nova best)', () {
        final result = DeltaCalculator.compute(
          lapMs: 84000,
          previousBestMs: 84000,
        );

        expect(result.eventState, RaceEventState.voltaPior);
      });

      test('delta é zero', () {
        final result = DeltaCalculator.compute(
          lapMs: 84000,
          previousBestMs: 84000,
        );

        expect(result.deltaMs, 0);
      });
    });

    group('cálculo do delta numérico', () {
      test('delta de 233ms para melhoria de 0.233s', () {
        final result = DeltaCalculator.compute(
          lapMs: 83887,
          previousBestMs: 84120,
        );

        expect(result.deltaMs, 233);
      });

      test('delta de -1321ms para piora de 1.321s', () {
        final result = DeltaCalculator.compute(
          lapMs: 85441,
          previousBestMs: 84120,
        );

        expect(result.deltaMs, -1321);
      });
    });
  });
}
