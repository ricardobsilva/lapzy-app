import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/race_session_record.dart';

/// Repositório de sessões de corrida com persistência local via SharedPreferences.
///
/// O singleton mantém um cache em memória ([_sessions]) sincronizado com o
/// storage. Chame [load] uma vez na inicialização do app antes de [runApp].
class RaceSessionRepository {
  static final RaceSessionRepository _instance = RaceSessionRepository._();

  factory RaceSessionRepository() => _instance;
  RaceSessionRepository._();

  final List<RaceSessionRecord> _sessions = [];
  bool _loaded = false;

  static const _storageKey = 'lapzy_sessions_v1';

  List<RaceSessionRecord> get sessions => List.unmodifiable(_sessions);

  /// Carrega sessões do storage para o cache em memória.
  ///
  /// Idempotente: chamadas subsequentes são no-ops até que [clearForTesting]
  /// ou [clearStorageForTesting] sejam chamados.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final list = jsonDecode(raw) as List<dynamic>;
    _sessions
      ..clear()
      ..addAll(
        list.map((e) => RaceSessionRecord.fromJson(e as Map<String, dynamic>)),
      );
  }

  /// Salva (insere ou atualiza) uma sessão no cache e persiste no storage.
  Future<void> save(RaceSessionRecord record) async {
    final idx = _sessions.indexWhere((s) => s.id == record.id);
    if (idx >= 0) {
      _sessions[idx] = record;
    } else {
      _sessions.add(record);
    }
    await _persist();
  }

  /// Remove uma sessão do cache e do storage.
  Future<void> delete(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  /// Para uso em testes — reseta o cache em memória e permite nova chamada a [load].
  /// Não toca o storage; use [clearStorageForTesting] quando necessário.
  void clearForTesting() {
    _sessions.clear();
    _loaded = false;
  }

  /// Para uso em testes de persistência — limpa cache E storage.
  Future<void> clearStorageForTesting() async {
    _sessions.clear();
    _loaded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
