import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/models/race_session.dart';
import 'package:lapzy/services/lap_filter.dart';

LapResult _lap(int ms) => LapResult(lapMs: ms);

void main() {
  group('LapFilter.median', () {
    group('lista vazia', () {
      test('retorna 0', () {
        expect(LapFilter.median([]), 0);
      });
    });

    group('lista com 1 elemento', () {
      test('retorna o único valor', () {
        expect(LapFilter.median([5000]), 5000);
      });
    });

    group('lista com número ímpar de elementos', () {
      test('retorna o elemento central ordenado', () {
        expect(LapFilter.median([3000, 1000, 2000]), 2000);
      });
    });

    group('lista com número par de elementos', () {
      test('retorna a média dos dois centrais', () {
        expect(LapFilter.median([1000, 2000, 3000, 4000]), 2500);
      });
    });
  });

  group('LapFilter.bestValidLap', () {
    group('lista vazia', () {
      test('retorna null', () {
        expect(LapFilter.bestValidLap([]), isNull);
      });
    });

    group('volta única', () {
      test('retorna o lapMs da única volta', () {
        expect(LapFilter.bestValidLap([_lap(65000)]), 65000);
      });
    });

    group('sem warm-up, sem outliers', () {
      test('retorna a menor volta', () {
        final laps = [_lap(65000), _lap(66000), _lap(64000), _lap(65500)];
        expect(LapFilter.bestValidLap(laps), 64000);
      });
    });

    group('CA-BUG-002-01: primeira volta é warm-up (> 1.05× mediana das demais)', () {
      test('exclui a primeira volta do cálculo', () {
        // Primeira: 75000ms (warm-up), demais ~65000ms
        // mediana das demais: median([64000, 65000, 66000]) = 65000
        // threshold warm-up: 65000 * 1.05 = 68250
        // 75000 > 68250 → warm-up excluído
        final laps = [_lap(75000), _lap(65000), _lap(64000), _lap(66000)];
        expect(LapFilter.bestValidLap(laps), 64000);
      });

      test('não exclui a primeira volta quando está dentro do ritmo normal', () {
        // Primeira: 65500ms — não é warm-up
        // mediana das demais: median([65000, 64000, 66000]) = 65000
        // threshold warm-up: 65000 * 1.05 = 68250
        // 65500 < 68250 → não é warm-up
        final laps = [_lap(65500), _lap(65000), _lap(64000), _lap(66000)];
        expect(LapFilter.bestValidLap(laps), 64000);
      });
    });

    group('CA-BUG-002-01: outliers > 3× mediana excluídos', () {
      test('exclui volta de 259s em sessão com ritmo ~65s', () {
        // mediana das demais (excl lap1): median([65000, 64000, 66000, 65500]) = 65250
        // não é warm-up: lap1=65000 < 65250 * 1.05 = 68512
        // threshold 3x: 65250 * 3 = 195750
        // 259000 > 195750 → excluído
        final laps = [
          _lap(65000), _lap(64000), _lap(259000), _lap(66000), _lap(65500),
        ];
        expect(LapFilter.bestValidLap(laps), 64000);
      });

      test('não exclui voltas levemente acima da mediana (não são outliers)', () {
        final laps = [_lap(65000), _lap(70000), _lap(64000)];
        // mediana das demais: median([70000, 64000]) = 67000
        // threshold 3x: 67000 * 3 = 201000
        // 70000 < 201000 → não excluído
        expect(LapFilter.bestValidLap(laps), 64000);
      });
    });

    group('primeiro cruzamento com warm-up + outlier', () {
      test('exclui warm-up E outlier, retorna a melhor volta válida', () {
        // lap0=74000 (warm-up), lap2=259000 (outlier), restantes ~65000
        // mediana das demais (laps[1:]): median([65000, 259000, 64000, 66000]) = 65500
        // warm-up threshold: 65500 * 1.05 = 68775 → 74000 > 68775 → excluído
        // outlier threshold: 65500 * 3 = 196500 → 259000 > 196500 → excluído
        final laps = [
          _lap(74000), _lap(65000), _lap(259000), _lap(64000), _lap(66000),
        ];
        expect(LapFilter.bestValidLap(laps), 64000);
      });
    });
  });

  group('LapFilter.averageLap', () {
    group('lista vazia', () {
      test('retorna null', () {
        expect(LapFilter.averageLap([]), isNull);
      });
    });

    group('volta única', () {
      test('retorna o lapMs da única volta', () {
        expect(LapFilter.averageLap([_lap(65000)]), 65000);
      });
    });

    group('CA-BUG-002-03: outliers > 2× mediana excluídos', () {
      test('exclui volta anômala do cálculo da média', () {
        // laps: [65000, 65000, 259000, 65000]
        // mediana das demais (laps[1:]): median([65000, 259000, 65000]) = 65000
        // não é warm-up: 65000 < 65000 * 1.05 = 68250
        // threshold 2x: 65000 * 2 = 130000
        // 259000 > 130000 → excluído
        // valid: [65000, 65000, 65000] → média = 65000
        final laps = [
          _lap(65000), _lap(65000), _lap(259000), _lap(65000),
        ];
        expect(LapFilter.averageLap(laps), 65000);
      });
    });

    group('com warm-up', () {
      test('exclui warm-up da média', () {
        // laps: [75000, 65000, 64000, 66000]
        // mediana das demais: 65000
        // warm-up: 75000 > 65000 * 1.05 = 68250 → excluído
        // threshold 2x: 65000 * 2 = 130000, nenhum outlier
        // valid: [65000, 64000, 66000] → média = 65000
        final laps = [_lap(75000), _lap(65000), _lap(64000), _lap(66000)];
        expect(LapFilter.averageLap(laps), 65000);
      });
    });

    group('todos os valores iguais', () {
      test('retorna o valor comum', () {
        final laps = [_lap(65000), _lap(65000), _lap(65000)];
        expect(LapFilter.averageLap(laps), 65000);
      });
    });
  });
}
