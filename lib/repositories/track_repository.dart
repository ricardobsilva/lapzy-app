import '../models/track.dart';

/// Repositório in-memory de pistas.
/// Singleton — persiste durante a sessão do app.
class TrackRepository {
  static final TrackRepository _instance = TrackRepository._();

  factory TrackRepository() => _instance;
  TrackRepository._();

  final List<Track> _tracks = [];

  List<Track> get tracks => List.unmodifiable(_tracks);

  void add(Track track) {
    _tracks.add(track);
  }

  void remove(String id) {
    _tracks.removeWhere((t) => t.id == id);
  }

  /// Para uso em testes — reseta o repositório ao estado inicial.
  void clearForTesting() {
    _tracks.clear();
  }
}
