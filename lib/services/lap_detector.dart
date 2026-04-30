import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/track.dart';

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
///
/// Para cada [TrackLine], todos os sub-segmentos de [TrackLine.allPoints]
/// são verificados — linhas curvas (com middlePoints) são tratadas
/// como polilinhas segmento a segmento.
///
/// O timestamp de cada evento é interpolado a partir dos timestamps GPS
/// das duas posições que enquadram o cruzamento, eliminando o erro de
/// latência de callback (até 1 / taxa_GPS segundos).
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
  DateTime? _previousTimestamp;

  Stream<LapEvent> get events => _controller.stream;

  void start() {
    _previousPosition = null;
    _previousTimestamp = null;
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
    _previousTimestamp = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _onPosition(Position pos) {
    final current = GeoPoint(pos.latitude, pos.longitude);
    final currentTime = pos.timestamp;
    final previous = _previousPosition;
    final previousTime = _previousTimestamp;

    if (previous != null && previousTime != null) {
      final lapTime = _checkLine(
        previous, current, previousTime, currentTime,
        track.startFinishLine,
      );
      if (lapTime != null) {
        _controller.add(LapCrossedEvent(lapTime));
      }

      for (int i = 0; i < track.sectorBoundaries.length; i++) {
        final sectorTime = _checkLine(
          previous, current, previousTime, currentTime,
          track.sectorBoundaries[i],
        );
        if (sectorTime != null) {
          _controller.add(SectorCrossedEvent(i, sectorTime));
        }
      }
    }

    _previousPosition = current;
    _previousTimestamp = currentTime;
  }

  /// Verifica se o vetor de movimento [prev]→[curr] cruza algum sub-segmento
  /// de [line]. Se cruzar, retorna o instante interpolado do cruzamento.
  ///
  /// Itera sobre todos os pares consecutivos de [TrackLine.allPoints], tratando
  /// a linha como uma polilinha. Para linhas sem middlePoints o comportamento é
  /// idêntico à verificação de segmento único original.
  DateTime? _checkLine(
    GeoPoint prev,
    GeoPoint curr,
    DateTime prevTime,
    DateTime currTime,
    TrackLine? line,
  ) {
    if (line == null) return null;

    final points = line.allPoints;
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];

      // Passo 1: mudança de sinal confirma cruzamento da reta infinita.
      final signPrev = _crossSign(a, b, prev);
      final signCurr = _crossSign(a, b, curr);
      if (signPrev == 0 || signCurr == 0) continue;
      if (signPrev == signCurr) continue;

      // Passo 2: verifica se o cruzamento cai dentro do sub-segmento (com buffer).
      final params = _crossingParams(prev, curr, a, b, line.widthMeters);
      if (params == null) continue;

      // Passo 3: interpola o instante exato do cruzamento usando timestamps GPS,
      // eliminando o erro de latência de callback.
      final dtMicros = currTime.difference(prevTime).inMicroseconds;
      final crossingTime = prevTime.add(
        Duration(microseconds: (dtMicros * params.t).round()),
      );
      return crossingTime;
    }
    return null;
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

  /// Resolve o sistema paramétrico de interseção entre o vetor de movimento
  /// [prev]→[curr] e o segmento [a]→[b].
  ///
  /// Retorna `(s, t)` onde:
  /// - `s` é o parâmetro ao longo de [a]→[b] (0 = ponto A, 1 = ponto B),
  ///   verificado contra os limites do segmento com tolerância [bufferMeters]/2.
  /// - `t` é o parâmetro ao longo de [prev]→[curr] (0 = prev, 1 = curr),
  ///   usado para interpolar o timestamp do cruzamento.
  ///
  /// Retorna null se as retas forem paralelas ou se `s` estiver fora dos
  /// limites do segmento.
  static ({double s, double t})? _crossingParams(
    GeoPoint prev,
    GeoPoint curr,
    GeoPoint a,
    GeoPoint b,
    double bufferMeters,
  ) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.lat * math.pi / 180);

    // Vetor de movimento (metros).
    final mx = (curr.lng - prev.lng) * lng2m;
    final my = (curr.lat - prev.lat) * lat2m;

    // Vetor do segmento a→b (metros).
    final lx = (b.lng - a.lng) * lng2m;
    final ly = (b.lat - a.lat) * lat2m;

    // Denominador do sistema paramétrico: lx·my − mx·ly.
    final denom = lx * my - mx * ly;
    if (denom.abs() < 1e-9) return null; // retas paralelas

    // Vetor de a para prev (metros).
    final ax = (a.lng - prev.lng) * lng2m;
    final ay = (a.lat - prev.lat) * lat2m;

    // s: parâmetro ao longo do segmento a→b onde ocorre o cruzamento.
    // s = (Mx·Ay − My·Ax) / denom
    final s = (mx * ay - my * ax) / denom;

    final segLen = math.sqrt(lx * lx + ly * ly);
    final tolerance = segLen > 0 ? (bufferMeters / 2) / segLen : 0.0;
    if (s < -tolerance || s > 1.0 + tolerance) return null;

    // t: parâmetro ao longo do vetor de movimento prev→curr onde ocorre o cruzamento.
    // t = (Lx·Ay − Ly·Ax) / denom
    final t = (lx * ay - ly * ax) / denom;

    return (s: s, t: t.clamp(0.0, 1.0));
  }
}
