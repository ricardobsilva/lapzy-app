import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';

/// Repositório de pistas com persistência local via SharedPreferences.
///
/// O singleton mantém um cache em memória ([_tracks]) sincronizado com o
/// storage. Chame [load] uma vez na inicialização do app antes de [runApp].
class TrackRepository {
  static final TrackRepository _instance = TrackRepository._();

  factory TrackRepository() => _instance;
  TrackRepository._();

  final List<Track> _tracks = [];
  bool _loaded = false;

  static const _storageKey = 'lapzy_tracks_v1';

  List<Track> get tracks => List.unmodifiable(_tracks);

  /// Carrega pistas do storage para o cache em memória.
  ///
  /// Idempotente: chamadas subsequentes são no-ops até que [clearForTesting]
  /// ou [clearStorageForTesting] sejam chamados.
  /// Se o storage estiver vazio, o cache é preservado (útil em testes que
  /// inserem dados via [add] antes de chamar este método).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final list = jsonDecode(raw) as List<dynamic>;
    _tracks
      ..clear()
      ..addAll(
        list.map((e) => Track.fromJson(e as Map<String, dynamic>)),
      );
  }

  /// Salva (insere ou atualiza) uma pista no cache e persiste no storage.
  Future<void> save(Track track) async {
    final idx = _tracks.indexWhere((t) => t.id == track.id);
    if (idx >= 0) {
      _tracks[idx] = track;
    } else {
      _tracks.add(track);
    }
    await _persist();
  }

  /// Remove uma pista do cache e do storage.
  Future<void> remove(String id) async {
    _tracks.removeWhere((t) => t.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_tracks.map((t) => t.toJson()).toList()),
    );
  }

  /// Para uso em testes — reseta o cache em memória e permite nova chamada a [load].
  /// Não toca o storage; use [clearStorageForTesting] quando necessário.
  void clearForTesting() {
    _tracks.clear();
    _loaded = false;
  }

  /// Para uso em testes de persistência — limpa cache E storage.
  Future<void> clearStorageForTesting() async {
    _tracks.clear();
    _loaded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Para uso em testes de integração que precisam de setup in-memory rápido.
  /// Não persiste no storage.
  void add(Track track) => _tracks.add(track);
}
