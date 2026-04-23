import '../models/race_session.dart';

/// Resultado do cálculo de delta após uma volta.
class DeltaResult {
  final RaceEventState eventState;

  /// Delta em ms.
  /// - positivo: volta atual foi mais rápida que a referência
  /// - negativo: volta atual foi mais lenta que a referência
  /// - null: sem referência (primeira session best)
  final int? deltaMs;

  /// Session best atualizada após o cálculo.
  final int newBestLapMs;

  const DeltaResult({
    required this.eventState,
    required this.deltaMs,
    required this.newBestLapMs,
  });
}

/// Lógica pura de delta — sem estado, sem Flutter, testável em isolamento.
class DeltaCalculator {
  DeltaCalculator._();

  /// Computa o evento e delta de uma volta recém-completada.
  ///
  /// [lapMs] — tempo da volta completada em ms.
  /// [previousBestMs] — session best anterior (null se for a primeira volta).
  /// [prThresholdMs] — threshold de personal record (null = PR desabilitado).
  static DeltaResult compute({
    required int lapMs,
    required int? previousBestMs,
    int? prThresholdMs,
  }) {
    if (previousBestMs == null) {
      // Primeira volta completada — primeira session best.
      return DeltaResult(
        eventState: RaceEventState.melhorVolta,
        deltaMs: null,
        newBestLapMs: lapMs,
      );
    }

    if (lapMs < previousBestMs) {
      // Nova session best.
      final delta = previousBestMs - lapMs; // positivo = melhoria
      final isPr = prThresholdMs != null && lapMs < prThresholdMs;
      return DeltaResult(
        eventState: isPr ? RaceEventState.personalRecord : RaceEventState.voltaMelhor,
        deltaMs: delta,
        newBestLapMs: lapMs,
      );
    }

    // Volta pior ou igual à session best.
    final delta = previousBestMs - lapMs; // negativo = piora
    return DeltaResult(
      eventState: RaceEventState.voltaPior,
      deltaMs: delta,
      newBestLapMs: previousBestMs,
    );
  }
}
