import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Serviço de telemetria — persiste todas as posições GPS e eventos relevantes
/// em SQLite para análise posterior de bugs, precisão e comportamento do pipeline.
///
/// ### Tabelas
/// - `telem_sessions`  — uma linha por sessão de corrida
/// - `telem_positions` — cada posição GPS recebida durante a sessão
/// - `telem_events`    — cruzamentos, rejeições, erros e mudanças de fonte
///
/// ### Uso
/// ```dart
/// await TelemetryService.instance.init();   // main()
/// TelemetryService.instance.startSession(...);  // RaceScreen.initState()
/// TelemetryService.instance.logPosition(...);   // GpsSourceManager
/// TelemetryService.instance.logEvent(...);      // LapDetector
/// TelemetryService.instance.endSession();       // RaceScreen.dispose()
/// ```
class TelemetryService {
  TelemetryService._();

  static TelemetryService? _instance;
  static TelemetryService get instance => _instance ??= TelemetryService._();

  /// Substitui o singleton — use apenas em testes.
  static void resetForTesting([TelemetryService? mock]) => _instance = mock;

  Database? _db;
  String? _currentSessionId;

  String? get currentSessionId => _currentSessionId;
  bool get isActive => _db != null;

  // ── inicialização ────────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      final dbPath = p.join(await getDatabasesPath(), 'lapzy_telemetry.db');
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createSchema,
      );
      debugPrint('[LAPZY/TELEM] DB inicializado: $dbPath');
    } catch (e) {
      debugPrint('[LAPZY/TELEM] ERRO ao inicializar DB: $e');
    }
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE telem_sessions (
        id             TEXT    PRIMARY KEY,
        track_id       TEXT    NOT NULL,
        track_name     TEXT    NOT NULL,
        gps_source     TEXT    NOT NULL,
        gps_source_name TEXT   NOT NULL,
        started_at     INTEGER NOT NULL,
        ended_at       INTEGER,
        note           TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE telem_positions (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id    TEXT    NOT NULL,
        wall_ms       INTEGER NOT NULL,
        gps_ms        INTEGER NOT NULL,
        lat           REAL    NOT NULL,
        lng           REAL    NOT NULL,
        speed_ms      REAL    NOT NULL,
        speed_kmh     REAL    NOT NULL,
        accuracy_m    REAL    NOT NULL,
        bearing_deg   REAL    NOT NULL,
        altitude_m    REAL    NOT NULL,
        delta_wall_ms INTEGER,
        delta_gps_ms  INTEGER,
        hz_wall       REAL,
        gps_source    TEXT    NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_pos_session ON telem_positions(session_id)',
    );
    await db.execute(
      'CREATE INDEX idx_pos_wall ON telem_positions(session_id, wall_ms)',
    );

    await db.execute('''
      CREATE TABLE telem_events (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id  TEXT,
        wall_ms     INTEGER NOT NULL,
        gps_ms      INTEGER,
        type        TEXT    NOT NULL,
        sector_idx  INTEGER,
        value_ms    INTEGER,
        median_ms   INTEGER,
        reason      TEXT,
        extra       TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_evt_session ON telem_events(session_id)',
    );
  }

  // ── sessão ───────────────────────────────────────────────────────────────────

  void startSession({
    required String sessionId,
    required String trackId,
    required String trackName,
    required String gpsSource,
    required String gpsSourceName,
  }) {
    _currentSessionId = sessionId;
    unawaited(_safeInsert('telem_sessions', {
      'id': sessionId,
      'track_id': trackId,
      'track_name': trackName,
      'gps_source': gpsSource,
      'gps_source_name': gpsSourceName,
      'started_at': DateTime.now().millisecondsSinceEpoch,
    }));
    debugPrint('[LAPZY/TELEM] Sessão iniciada: $sessionId — $trackName ($gpsSourceName)');
  }

  void endSession({String note = 'user_ended'}) {
    final id = _currentSessionId;
    if (id == null) return;
    _currentSessionId = null;
    unawaited(_safeUpdate(
      'telem_sessions',
      {'ended_at': DateTime.now().millisecondsSinceEpoch, 'note': note},
      'id = ?',
      [id],
    ));
    debugPrint('[LAPZY/TELEM] Sessão encerrada: $id ($note)');
  }

  // ── posições ─────────────────────────────────────────────────────────────────

  /// Registra uma posição GPS. Fire-and-forget — não bloqueia o pipeline GPS.
  void logPosition(
    Position pos, {
    required int? deltaWallMs,
    required DateTime? prevGpsTime,
    required String gpsSource,
  }) {
    final db = _db;
    final sessionId = _currentSessionId;
    if (db == null || sessionId == null) return;

    final deltaGpsMs = prevGpsTime != null
        ? pos.timestamp.difference(prevGpsTime).inMilliseconds
        : null;
    final hzWall =
        deltaWallMs != null && deltaWallMs > 0 ? 1000.0 / deltaWallMs : null;

    unawaited(db.insert('telem_positions', {
      'session_id': sessionId,
      'wall_ms': DateTime.now().millisecondsSinceEpoch,
      'gps_ms': pos.timestamp.millisecondsSinceEpoch,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'speed_ms': pos.speed < 0 ? 0.0 : pos.speed,
      'speed_kmh': pos.speed < 0 ? 0.0 : pos.speed * 3.6,
      'accuracy_m': pos.accuracy,
      'bearing_deg': pos.heading,
      'altitude_m': pos.altitude,
      'delta_wall_ms': deltaWallMs,
      'delta_gps_ms': deltaGpsMs,
      'hz_wall': hzWall,
      'gps_source': gpsSource,
    }));
  }

  // ── eventos ──────────────────────────────────────────────────────────────────

  /// Tipos de evento reconhecidos:
  ///
  /// GPS pipeline:
  ///   `gps_source_changed` `gps_source_error` `gps_source_done` `gps_fallback`
  ///
  /// LapDetector:
  ///   `detector_start` `detector_stop`
  ///   `lap_start` `lap_crossed` `lap_suspect` `lap_rejected_cooldown`
  ///   `sector_crossed` `sector_rejected_cooldown` `sector_rejected_proximity`
  ///
  /// Sessão:
  ///   `race_start` `race_end`
  void logEvent(
    String type, {
    DateTime? gpsTime,
    int? sectorIdx,
    int? valueMs,
    int? medianMs,
    String? reason,
    Map<String, dynamic>? extra,
  }) {
    final db = _db;
    if (db == null) return;

    unawaited(db.insert('telem_events', {
      'session_id': _currentSessionId,
      'wall_ms': DateTime.now().millisecondsSinceEpoch,
      'gps_ms': gpsTime?.millisecondsSinceEpoch,
      'type': type,
      'sector_idx': sectorIdx,
      'value_ms': valueMs,
      'median_ms': medianMs,
      'reason': reason,
      'extra': extra != null ? jsonEncode(extra) : null,
    }));
  }

  // ── consultas para análise ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> querySessions() async {
    return await _db?.query('telem_sessions', orderBy: 'started_at DESC') ?? [];
  }

  Future<List<Map<String, dynamic>>> queryPositions(String sessionId) async {
    return await _db?.query(
          'telem_positions',
          where: 'session_id = ?',
          whereArgs: [sessionId],
          orderBy: 'wall_ms ASC',
        ) ??
        [];
  }

  Future<List<Map<String, dynamic>>> queryEvents(String sessionId) async {
    return await _db?.query(
          'telem_events',
          where: 'session_id = ?',
          whereArgs: [sessionId],
          orderBy: 'wall_ms ASC',
        ) ??
        [];
  }

  /// Resumo estatístico de uma sessão — usado para análise rápida de qualidade.
  Future<Map<String, dynamic>?> sessionSummary(String sessionId) async {
    final db = _db;
    if (db == null) return null;

    final positions = await queryPositions(sessionId);
    final events = await queryEvents(sessionId);
    if (positions.isEmpty) return null;

    final speeds = positions
        .map((r) => (r['speed_kmh'] as num).toDouble())
        .where((s) => s > 0)
        .toList();

    final hzList = positions
        .map((r) => r['hz_wall'])
        .whereType<num>()
        .map((h) => h.toDouble())
        .toList();

    final accuracies = positions
        .map((r) => (r['accuracy_m'] as num).toDouble())
        .toList();

    double? avg(List<double> list) =>
        list.isEmpty ? null : list.reduce((a, b) => a + b) / list.length;
    double? max(List<double> list) =>
        list.isEmpty ? null : list.reduce((a, b) => a > b ? a : b);
    double? min(List<double> list) =>
        list.isEmpty ? null : list.reduce((a, b) => a < b ? a : b);

    return {
      'session_id': sessionId,
      'total_positions': positions.length,
      'avg_hz': avg(hzList),
      'max_hz': max(hzList),
      'min_hz': min(hzList),
      'max_speed_kmh': max(speeds),
      'avg_accuracy_m': avg(accuracies),
      'min_accuracy_m': min(accuracies),
      'total_events': events.length,
      'laps_crossed': events.where((e) => e['type'] == 'lap_crossed').length,
      'laps_suspect': events.where((e) => e['type'] == 'lap_suspect').length,
      'laps_rejected': events.where((e) => e['type'] == 'lap_rejected_cooldown').length,
      'sectors_crossed': events.where((e) => e['type'] == 'sector_crossed').length,
      'sectors_rejected': events
          .where((e) => (e['type'] as String).startsWith('sector_rejected'))
          .length,
      'gps_errors': events
          .where((e) => (e['type'] as String).startsWith('gps_source_error'))
          .length,
    };
  }

  // ── internos ─────────────────────────────────────────────────────────────────

  Future<void> _safeInsert(String table, Map<String, dynamic> values) async {
    try {
      await _db?.insert(table, values);
    } catch (e) {
      debugPrint('[LAPZY/TELEM] Erro ao inserir em $table: $e');
    }
  }

  Future<void> _safeUpdate(
    String table,
    Map<String, dynamic> values,
    String where,
    List<dynamic> whereArgs,
  ) async {
    try {
      await _db?.update(table, values, where: where, whereArgs: whereArgs);
    } catch (e) {
      debugPrint('[LAPZY/TELEM] Erro ao atualizar $table: $e');
    }
  }
}
