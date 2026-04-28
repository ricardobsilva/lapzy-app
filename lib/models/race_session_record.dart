import 'race_session.dart';

/// Registro histórico imutável de uma sessão de corrida encerrada.
///
/// Diferente de [RaceSessionSnapshot] (estado ao vivo durante a corrida),
/// este modelo representa o resultado final persistido no dispositivo.
///
/// Campos de auditoria ([createdAt]) são obrigatórios para futura
/// reconciliação de conflitos no sync com a nuvem.
class RaceSessionRecord {
  /// UUID v4 gerado no momento do encerramento da corrida.
  final String id;

  /// ID da pista onde a corrida ocorreu.
  final String trackId;

  /// Nome da pista desnormalizado — preservado mesmo se a pista for deletada.
  final String trackName;

  /// Data/hora de início da sessão (ISO 8601).
  final DateTime date;

  /// Voltas completadas na sessão.
  final List<LapResult> laps;

  /// Melhor volta em ms. null se nenhuma volta foi completada.
  final int? bestLapMs;

  /// Timestamp de criação do record — usado para resolução de conflitos de sync.
  final DateTime createdAt;

  const RaceSessionRecord({
    required this.id,
    required this.trackId,
    required this.trackName,
    required this.date,
    required this.laps,
    required this.bestLapMs,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackId': trackId,
        'trackName': trackName,
        'date': date.toIso8601String(),
        'laps': laps.map((l) => l.toJson()).toList(),
        'bestLapMs': bestLapMs,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RaceSessionRecord.fromJson(Map<String, dynamic> json) =>
      RaceSessionRecord(
        id: json['id'] as String,
        trackId: json['trackId'] as String,
        trackName: json['trackName'] as String,
        date: DateTime.parse(json['date'] as String),
        laps: (json['laps'] as List<dynamic>)
            .map((l) => LapResult.fromJson(l as Map<String, dynamic>))
            .toList(),
        bestLapMs: json['bestLapMs'] as int?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
