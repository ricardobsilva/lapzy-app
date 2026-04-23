import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/track.dart';
import 'track_geometry.dart';

/// Evento emitido pelo LapDetector.
sealed class LapEvent {}

/// A linha de largada/chegada foi cruzada — nova volta iniciada.
class LapCrossedEvent extends LapEvent {
  final DateTime timestamp;
  LapCrossedEvent(this.timestamp);
}

/// Uma fronteira de setor foi cruzada.
class SectorCrossedEvent extends LapEvent {
  /// Índice 0-based do setor cruzado (0 = S1, 1 = S2, 2 = S3).
  final int sectorIndex;
  final DateTime timestamp;
  SectorCrossedEvent(this.sectorIndex, this.timestamp);
}

/// Detecta cruzamentos de linhas de pista via GPS.
///
/// Emite [LapCrossedEvent] e [SectorCrossedEvent] conforme o piloto
/// cruza as linhas definidas na [Track].
class LapDetector {
  final Track track;

  /// Fábrica injetável para o stream de posição — facilita testes.
  final Stream<Position> Function() positionStreamFactory;

  LapDetector({
    required this.track,
    Stream<Position> Function()? positionStreamFactory,
  }) : positionStreamFactory = positionStreamFactory ??
            (() => Geolocator.getPositionStream(
                  locationSettings: const LocationSettings(
                    accuracy: LocationAccuracy.best,
                    distanceFilter: 0,
                  ),
                ));

  final _controller = StreamController<LapEvent>.broadcast();
  StreamSubscription<Position>? _gpsSub;
  GeoPoint? _previousPosition;

  Stream<LapEvent> get events => _controller.stream;

  void start() {
    _previousPosition = null;
    _gpsSub = positionStreamFactory().listen(
      _onPosition,
      onError: (_) {
        // Permissão negada ou erro de GPS — sem eventos, sem crash.
      },
    );
  }

  void stop() {
    _gpsSub?.cancel();
    _gpsSub = null;
    _previousPosition = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _onPosition(Position pos) {
    final current = GeoPoint(pos.latitude, pos.longitude);
    final previous = _previousPosition;

    if (previous != null) {
      _checkLine(previous, current, track.startFinishLine, onCrossed: () {
        _controller.add(LapCrossedEvent(DateTime.now()));
      });

      for (int i = 0; i < track.sectorBoundaries.length; i++) {
        final idx = i;
        _checkLine(previous, current, track.sectorBoundaries[i], onCrossed: () {
          _controller.add(SectorCrossedEvent(idx, DateTime.now()));
        });
      }
    }

    _previousPosition = current;
  }

  void _checkLine(
    GeoPoint prev,
    GeoPoint curr,
    TrackLine? line, {
    required VoidCallback onCrossed,
  }) {
    if (line == null) return;

    final a = line.a;
    final b = line.b;

    final signPrev = _crossSign(a, b, prev);
    final signCurr = _crossSign(a, b, curr);

    if (signPrev == 0 || signCurr == 0) return;
    if (signPrev == signCurr) return; // mesmo lado — sem cruzamento

    // Verifica se o cruzamento ocorre dentro do corredor de detecção.
    // Usa o ponto mais próximo da linha (curr) para verificar distância.
    final distToLine = _perpendicularDistance(curr, a, b);
    if (distToLine > line.widthMeters) return;

    onCrossed();
  }

  /// Sinal do produto vetorial (B-A) × (P-A) em coordenadas 2D planas.
  /// Retorna 1, -1 ou 0.
  static int _crossSign(GeoPoint a, GeoPoint b, GeoPoint p) {
    final cross = (b.lat - a.lat) * (p.lng - a.lng) -
        (b.lng - a.lng) * (p.lat - a.lat);
    if (cross > 0) return 1;
    if (cross < 0) return -1;
    return 0;
  }

  /// Distância perpendicular de [p] ao segmento [a]→[b] em metros.
  static double _perpendicularDistance(GeoPoint p, GeoPoint a, GeoPoint b) {
    // Converte para coordenadas cartesianas aproximadas (metros).
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.lat * math.pi / 180);

    final bx = (b.lng - a.lng) * lng2m;
    final by = (b.lat - a.lat) * lat2m;
    final px = (p.lng - a.lng) * lng2m;
    final py = (p.lat - a.lat) * lat2m;

    final abLen = math.sqrt(bx * bx + by * by);
    if (abLen < 1e-9) return TrackGeometry.haversine(p, a);

    // Distância da reta infinita (não do segmento).
    final cross = (bx * py - by * px).abs();
    return cross / abLen;
  }
}

/// Alias para evitar import de Flutter em lap_detector.dart
typedef VoidCallback = void Function();
