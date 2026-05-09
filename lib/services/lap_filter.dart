import '../models/race_session.dart';

/// Funções puras de filtragem de voltas para exibição no resumo pós-corrida.
///
/// Todas as funções são stateless e testáveis isoladamente.
class LapFilter {
  LapFilter._();

  /// Mediana de uma lista de inteiros. Retorna 0 para lista vazia.
  static int median(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) ~/ 2;
  }

  /// Retorna true se a primeira volta for warm-up.
  ///
  /// Critério: primeira volta existe, há pelo menos 2 voltas, e o lapMs da
  /// primeira volta é > 1.05× a mediana das demais (out-lap de kartódromo
  /// tipicamente 5–15% mais lenta que o ritmo de corrida).
  static bool _firstIsWarmup(List<LapResult> laps) {
    if (laps.length < 2) return false;
    final restMs = laps.skip(1).map((l) => l.lapMs).toList();
    final med = median(restMs);
    return laps.first.lapMs > (med * 1.05).round();
  }

  /// Melhor volta válida.
  ///
  /// Exclui:
  /// - primeira volta se for warm-up (lapMs > 1.05× mediana das demais)
  /// - voltas com lapMs > 3× mediana das demais (anomalias de pit/parada)
  ///
  /// Retorna null quando não há voltas válidas.
  static int? bestValidLap(List<LapResult> laps) {
    if (laps.isEmpty) return null;
    if (laps.length == 1) return laps.first.lapMs;

    final restMs = laps.skip(1).map((l) => l.lapMs).toList();
    final med = median(restMs);
    final threshold3x = (med * 3.0).round();
    final firstWarmup = _firstIsWarmup(laps);

    int? best;
    for (int i = 0; i < laps.length; i++) {
      if (i == 0 && firstWarmup) continue;
      if (laps[i].lapMs > threshold3x) continue;
      if (best == null || laps[i].lapMs < best) best = laps[i].lapMs;
    }
    return best;
  }

  /// Média de volta válida.
  ///
  /// Exclui:
  /// - primeira volta se for warm-up
  /// - outliers com lapMs > 2× mediana das demais
  ///
  /// Retorna null quando não há voltas válidas.
  static int? averageLap(List<LapResult> laps) {
    if (laps.isEmpty) return null;
    if (laps.length == 1) return laps.first.lapMs;

    final restMs = laps.skip(1).map((l) => l.lapMs).toList();
    final med = median(restMs);
    final threshold2x = (med * 2.0).round();
    final firstWarmup = _firstIsWarmup(laps);

    final valid = <int>[];
    for (int i = 0; i < laps.length; i++) {
      if (i == 0 && firstWarmup) continue;
      if (laps[i].lapMs > threshold2x) continue;
      valid.add(laps[i].lapMs);
    }
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) ~/ valid.length;
  }
}
