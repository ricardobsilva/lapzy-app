/// Estado visual da borda após uma volta completada.
/// Segue exatamente o SVG em docs/tela_corrida_svg.md (fonte de verdade para cores).
enum RaceEventState {
  /// Corrida iniciada, nenhuma volta completada ainda.
  neutral,

  /// Primeira session best (borda roxa, texto "MELHOR").
  melhorVolta,

  /// Nova session best que supera uma anterior (borda verde, delta numérico).
  voltaMelhor,

  /// Volta pior que a session best (borda vermelha, delta negativo).
  voltaPior,

  /// Nova session best que bate o personal record histórico (borda verde + banner PR).
  personalRecord,
}

/// Resultado de uma volta completada.
class LapResult {
  final int lapMs;
  final int? s1Ms;
  final int? s2Ms;
  final int? s3Ms;

  const LapResult({
    required this.lapMs,
    this.s1Ms,
    this.s2Ms,
    this.s3Ms,
  });
}

/// Snapshot imutável do estado da sessão — usado para reconstruir a UI.
class RaceSessionSnapshot {
  /// Tempo decorrido na volta atual em ms (atualizado a cada tick).
  final int currentLapMs;

  /// Número da volta atual (começa em 1).
  final int lapNumber;

  /// Session best em ms. null até a primeira volta ser completada.
  final int? bestLapMs;

  /// Delta em ms em relação ao contexto do evento.
  /// Positivo = mais rápido que a referência; negativo = mais lento.
  /// null quando o estado é neutral ou melhorVolta.
  final int? deltaMs;

  /// Estado do evento para coloração da borda e delta pill.
  final RaceEventState eventState;

  /// Tempos dos setores completados na volta atual (null = ainda não completado).
  final List<int?> currentSectors;

  /// Voltas completadas na sessão.
  final List<LapResult> completedLaps;

  const RaceSessionSnapshot({
    required this.currentLapMs,
    required this.lapNumber,
    required this.bestLapMs,
    required this.deltaMs,
    required this.eventState,
    required this.currentSectors,
    required this.completedLaps,
  });

  RaceSessionSnapshot copyWith({
    int? currentLapMs,
    int? lapNumber,
    int? bestLapMs,
    int? deltaMs,
    bool clearDelta = false,
    RaceEventState? eventState,
    List<int?>? currentSectors,
    List<LapResult>? completedLaps,
  }) {
    return RaceSessionSnapshot(
      currentLapMs: currentLapMs ?? this.currentLapMs,
      lapNumber: lapNumber ?? this.lapNumber,
      bestLapMs: bestLapMs ?? this.bestLapMs,
      deltaMs: clearDelta ? null : (deltaMs ?? this.deltaMs),
      eventState: eventState ?? this.eventState,
      currentSectors: currentSectors ?? this.currentSectors,
      completedLaps: completedLaps ?? this.completedLaps,
    );
  }
}
