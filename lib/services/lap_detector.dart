import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/track.dart';

/// Evento emitido pelo LapDetector.
sealed class LapEvent {}

/// A linha de largada/chegada foi cruzada — nova volta iniciada.
class LapCrossedEvent extends LapEvent {
  final DateTime timestamp;
  LapCrossedEvent(this.timestamp);
}

/// A linha de largada/chegada foi cruzada, mas o tempo da volta está fora
/// da faixa esperada com base nas últimas voltas válidas. A volta foi registrada
/// normalmente — o piloto e o app decidem como tratar.
class LapCrossedSuspectEvent extends LapEvent {
  final DateTime timestamp;

  /// Duração calculada desta volta (ms).
  final int lapMs;

  /// Mediana das últimas voltas válidas (ms). Usado para comparação.
  final int medianMs;

  LapCrossedSuspectEvent(
    this.timestamp, {
    required this.lapMs,
    required this.medianMs,
  });
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
/// Emite [LapCrossedEvent], [LapCrossedSuspectEvent] e [SectorCrossedEvent]
/// conforme o piloto cruza as linhas definidas na [Track].
///
/// ### Garantias
/// - **Cooldown**: nova detecção da S/C bloqueada por [minLapMs] ms após uma
///   volta válida — evita dupla contagem por GPS ruidoso.
/// - **Direção**: após o primeiro cruzamento, apenas cruzamentos no mesmo
///   sentido (diferença de heading ≤ 90°) são aceitos — rejeita travessias
///   no sentido contrário.
/// - **Outlier**: se a duração da volta desviar mais de [maxOutlierFraction]
///   OU [maxOutlierMs] da mediana das últimas [recentLapsForMedian] voltas
///   válidas, o evento emitido é [LapCrossedSuspectEvent] em vez de
///   [LapCrossedEvent].
/// - **Timestamp interpolado**: o instante exato do cruzamento é calculado
///   por interpolação linear entre os dois timestamps GPS adjacentes,
///   eliminando o erro de latência de callback.
///
/// Para cada [TrackLine], todos os sub-segmentos de [TrackLine.allPoints]
/// são verificados — linhas curvas (com middlePoints) são tratadas como
/// polilinhas segmento a segmento.
class LapDetector {
  final Track track;

  /// Fábrica injetável para o stream de posição — facilita testes.
  final Stream<Position> Function() positionStreamFactory;

  /// Cooldown entre dois cruzamentos válidos da S/C (ms).
  /// Cruzamentos detectados antes deste intervalo são silenciosamente
  /// descartados. Padrão: 20 000 ms (20 s).
  final int minLapMs;

  /// Fração de desvio da mediana que classifica uma volta como suspeita.
  /// Ex: 0.20 = 20% de diferença. Padrão: 0.20.
  final double maxOutlierFraction;

  /// Desvio absoluto (ms) que classifica uma volta como suspeita.
  /// A condição é OR com [maxOutlierFraction]. Padrão: 5 000 ms.
  final int maxOutlierMs;

  /// Número de voltas recentes usadas para calcular a mediana.
  /// Padrão: 5.
  final int recentLapsForMedian;

  LapDetector({
    required this.track,
    Stream<Position> Function()? positionStreamFactory,
    this.minLapMs = 20000,
    this.maxOutlierFraction = 0.20,
    this.maxOutlierMs = 5000,
    this.recentLapsForMedian = 5,
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

  /// Timestamp do último cruzamento válido da S/C.
  DateTime? _lastCrossingTime;

  /// Heading de referência (radianos) estabelecido no primeiro cruzamento.
  /// Subsequentes cruzamentos com diferença > 90° são rejeitados.
  double? _referenceHeading;

  /// Últimas N durações de volta válidas, em ms, para cálculo de mediana.
  final List<int> _recentLapMs = [];

  Stream<LapEvent> get events => _controller.stream;

  void start() {
    _previousPosition = null;
    _previousTimestamp = null;
    _lastCrossingTime = null;
    _referenceHeading = null;
    _recentLapMs.clear();
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
    _lastCrossingTime = null;
    _referenceHeading = null;
    _recentLapMs.clear();
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
      _checkStartFinish(previous, current, previousTime, currentTime);

      for (int i = 0; i < track.sectorBoundaries.length; i++) {
        final sectorTime = _checkLine(
          previous, current, previousTime, currentTime,
          track.sectorBoundaries[i],
        );
        if (sectorTime != null) {
          debugPrint(
            '[LapDetector] Setor $i cruzado — timestamp=${sectorTime.toIso8601String()}',
          );
          _controller.add(SectorCrossedEvent(i, sectorTime));
        }
      }
    }

    _previousPosition = current;
    _previousTimestamp = currentTime;
  }

  /// Avalia o cruzamento da linha S/C com todas as validações:
  /// cooldown, direção e outlier.
  void _checkStartFinish(
    GeoPoint prev,
    GeoPoint curr,
    DateTime prevTime,
    DateTime currTime,
  ) {
    final crossingTime = _checkLine(
      prev, curr, prevTime, currTime,
      track.startFinishLine,
    );

    if (crossingTime == null) return;

    final heading = _bearing(prev, curr);

    // ── 1. COOLDOWN ──────────────────────────────────────────────────────────
    if (_lastCrossingTime != null) {
      final msSinceLast =
          crossingTime.difference(_lastCrossingTime!).inMilliseconds;
      if (msSinceLast < minLapMs) {
        debugPrint(
          '[LapDetector] S/C rejeitado (cooldown) — '
          'msSinceLast=$msSinceLast < minLapMs=$minLapMs | '
          'heading=${heading.toStringAsFixed(3)} rad',
        );
        return;
      }
    }

    // ── 2. DIREÇÃO ───────────────────────────────────────────────────────────
    if (_referenceHeading != null &&
        !_isCompatibleHeading(heading, _referenceHeading!)) {
      debugPrint(
        '[LapDetector] S/C rejeitado (direção) — '
        'heading=${heading.toStringAsFixed(3)} rad | '
        'referência=${_referenceHeading!.toStringAsFixed(3)} rad',
      );
      return;
    }

    // ── 3. OUTLIER ───────────────────────────────────────────────────────────
    LapEvent event;
    if (_lastCrossingTime != null) {
      final lapMs =
          crossingTime.difference(_lastCrossingTime!).inMilliseconds;

      if (_recentLapMs.length >= 2) {
        final median = _median(_recentLapMs);
        final deviation = (lapMs - median).abs();
        final isSuspect = deviation > maxOutlierMs ||
            deviation > (median * maxOutlierFraction).round();

        if (isSuspect) {
          debugPrint(
            '[LapDetector] S/C suspeito — '
            'lapMs=$lapMs | mediana=$median | desvio=$deviation',
          );
          event = LapCrossedSuspectEvent(
            crossingTime,
            lapMs: lapMs,
            medianMs: median,
          );
        } else {
          debugPrint(
            '[LapDetector] S/C válido — '
            'lapMs=$lapMs | mediana=$median | '
            'heading=${heading.toStringAsFixed(3)} rad',
          );
          _updateRecentLaps(lapMs);
          event = LapCrossedEvent(crossingTime);
        }
      } else {
        // Ainda não há mediana suficiente — aceita sem verificação de outlier.
        debugPrint(
          '[LapDetector] S/C válido (sem mediana ainda) — '
          'lapMs=$lapMs | heading=${heading.toStringAsFixed(3)} rad',
        );
        _updateRecentLaps(lapMs);
        event = LapCrossedEvent(crossingTime);
      }
    } else {
      // Primeiro cruzamento: apenas inicia o timer, sem volta a registrar.
      debugPrint(
        '[LapDetector] S/C inicial — '
        'timestamp=${crossingTime.toIso8601String()} | '
        'heading=${heading.toStringAsFixed(3)} rad',
      );
      event = LapCrossedEvent(crossingTime);
    }

    _lastCrossingTime = crossingTime;
    _referenceHeading ??= heading;
    _controller.add(event);
  }

  void _updateRecentLaps(int lapMs) {
    _recentLapMs.add(lapMs);
    if (_recentLapMs.length > recentLapsForMedian) {
      _recentLapMs.removeAt(0);
    }
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
    final s = (mx * ay - my * ax) / denom;

    final segLen = math.sqrt(lx * lx + ly * ly);
    final tolerance = segLen > 0 ? (bufferMeters / 2) / segLen : 0.0;
    if (s < -tolerance || s > 1.0 + tolerance) return null;

    // t: parâmetro ao longo do vetor de movimento prev→curr.
    final t = (lx * ay - ly * ax) / denom;

    return (s: s, t: t.clamp(0.0, 1.0));
  }

  /// Bearing do vetor [from]→[to] em radianos no intervalo [-π, π].
  /// 0 = norte, π/2 = leste, -π/2 = oeste, ±π = sul.
  static double _bearing(GeoPoint from, GeoPoint to) {
    const toRad = math.pi / 180;
    final dLng = (to.lng - from.lng) * toRad;
    final lat1 = from.lat * toRad;
    final lat2 = to.lat * toRad;
    return math.atan2(
      math.sin(dLng) * math.cos(lat2),
      math.cos(lat1) * math.sin(lat2) -
          math.sin(lat1) * math.cos(lat2) * math.cos(dLng),
    );
  }

  /// Retorna true se [heading] é compatível com [reference] (diferença ≤ 90°).
  static bool _isCompatibleHeading(double heading, double reference) {
    var diff = (heading - reference).abs();
    if (diff > math.pi) diff = 2 * math.pi - diff;
    return diff <= math.pi / 2;
  }

  /// Mediana de uma lista de inteiros (sem modificar o original).
  static int _median(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) ~/ 2;
  }
}
