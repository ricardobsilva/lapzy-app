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
/// ### Garantias — S/F
/// - **Cooldown**: nova detecção bloqueada por [minLapMs] ms após cruzamento válido.
/// - **Direção**: após o primeiro cruzamento, apenas cruzamentos no mesmo
///   sentido (diferença de heading ≤ 90°) são aceitos.
/// - **Outlier**: se a duração desviar mais de [maxOutlierFraction] OU
///   [maxOutlierMs] da mediana das últimas [recentLapsForMedian] voltas,
///   o evento emitido é [LapCrossedSuspectEvent].
/// - **Timestamp interpolado**: o instante exato é calculado por interpolação
///   linear entre os dois timestamps GPS adjacentes.
///
/// ### Garantias — Setores
/// - **Buffer de acurácia GPS**: a tolerância de endpoint dos segmentos inclui
///   um buffer de acurácia GPS (~5 m) para compensar GPS impreciso no A35.
/// - **Fallback por proximidade**: quando o algoritmo de sub-segmento falha
///   (ex.: fronteiras curvas com middlePoints), usa a direção global A→B +
///   distância perpendicular para detectar o cruzamento.
/// - **Cooldown por setor**: nova detecção bloqueada por [minSectorMs] ms após
///   o último cruzamento da mesma fronteira — evita double-fire.
class LapDetector {
  final Track track;

  /// Fábrica injetável para o stream de posição — facilita testes.
  final Stream<Position> Function() positionStreamFactory;

  /// Cooldown entre dois cruzamentos válidos da S/C (ms).
  final int minLapMs;

  /// Fração de desvio da mediana que classifica uma volta como suspeita.
  final double maxOutlierFraction;

  /// Desvio absoluto (ms) que classifica uma volta como suspeita.
  final int maxOutlierMs;

  /// Número de voltas recentes usadas para calcular a mediana.
  final int recentLapsForMedian;

  /// Cooldown entre dois cruzamentos válidos da mesma fronteira de setor (ms).
  /// Padrão: 10 000 ms (10 s) — tempo mínimo razoável entre dois setores.
  final int minSectorMs;

  LapDetector({
    required this.track,
    Stream<Position> Function()? positionStreamFactory,
    this.minLapMs = 20000,
    this.maxOutlierFraction = 0.20,
    this.maxOutlierMs = 5000,
    this.recentLapsForMedian = 5,
    this.minSectorMs = 10000,
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

  /// Heading de referência (radianos) estabelecido no primeiro cruzamento S/C.
  double? _referenceHeading;

  /// Últimas N durações de volta válidas, em ms, para cálculo de mediana.
  final List<int> _recentLapMs = [];

  /// Último sinal do produto vetorial A→B por fronteira de setor.
  /// Usado pelo fallback de proximidade. 0 = ainda não estabelecido.
  final List<int> _sectorLastSign = [];

  /// Timestamp do último cruzamento por fronteira de setor (para cooldown).
  final List<DateTime?> _sectorLastCrossing = [];

  Stream<LapEvent> get events => _controller.stream;

  void start() {
    _previousPosition = null;
    _previousTimestamp = null;
    _lastCrossingTime = null;
    _referenceHeading = null;
    _recentLapMs.clear();
    _sectorLastSign
      ..clear()
      ..addAll(List.filled(track.sectorBoundaries.length, 0));
    _sectorLastCrossing
      ..clear()
      ..addAll(List.filled(track.sectorBoundaries.length, null));
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
    _sectorLastSign.clear();
    _sectorLastCrossing.clear();
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
        final sectorTime = _checkSectorCrossing(
          previous, current, previousTime, currentTime,
          track.sectorBoundaries[i], i,
        );
        if (sectorTime != null) {
          debugPrint(
            '[LapDetector] Setor $i cruzado — timestamp=${sectorTime.toIso8601String()}',
          );
          _controller.add(SectorCrossedEvent(i, sectorTime));
        }
      }
    }

    // Atualiza sinal por setor após verificar cruzamentos — o sinal anterior
    // é usado pelo fallback de proximidade no próximo update.
    // Apenas posições dentro de 20 m da fronteira são usadas para evitar
    // falsos sign-changes quando o GPS está longe (ex.: após cruzamento S/C).
    for (int i = 0; i < track.sectorBoundaries.length; i++) {
      final s = _crossSign(
        track.sectorBoundaries[i].a,
        track.sectorBoundaries[i].b,
        current,
      );
      if (s != 0) {
        const proximityM = 20.0;
        final perp = _perpDistMeters(
          current,
          track.sectorBoundaries[i].a,
          track.sectorBoundaries[i].b,
        ).abs();
        if (perp <= proximityM) _sectorLastSign[i] = s;
      }
    }

    _previousPosition = current;
    _previousTimestamp = currentTime;
  }

  /// Detecta cruzamento de fronteira de setor com três mecanismos em cascata:
  /// 1. Sign-change por sub-segmento com buffer de acurácia GPS (primário).
  /// 2. Fallback por proximidade perpendicular à linha A→B.
  /// 3. Cooldown: rejeita se o cruzamento foi detectado há menos de [minSectorMs].
  DateTime? _checkSectorCrossing(
    GeoPoint prev,
    GeoPoint curr,
    DateTime prevTime,
    DateTime currTime,
    TrackLine boundary,
    int index,
  ) {
    // ── 1. SIGN-CHANGE com buffer de acurácia GPS ──────────────────────────
    // O buffer de 5 m compensa GPS de ~5-10 m de acurácia no Samsung A35.
    // Isso expande a tolerância de endpoint de widthMeters/2 para
    // widthMeters/2 + 5 m, evitando rejeições quando o cruzamento aparece
    // ligeiramente fora dos extremos do segmento.
    const gpsAccuracyBuffer = 5.0;
    DateTime? crossingTime = _checkLine(
      prev, curr, prevTime, currTime, boundary,
      gpsAccuracyBuffer: gpsAccuracyBuffer,
    );

    // ── 2. FALLBACK: direção global A→B + distância perpendicular ──────────
    // Cobre casos onde nenhum sub-segmento da polilinha cruza o vetor GPS
    // (ex.: fronteiras curvas com muitos middlePoints).
    crossingTime ??= _checkLineByProximity(
      prev, curr, prevTime, currTime, boundary, index,
    );

    if (crossingTime == null) return null;

    // ── 3. COOLDOWN ────────────────────────────────────────────────────────
    final lastCrossing = _sectorLastCrossing[index];
    if (lastCrossing != null) {
      final ms = crossingTime.difference(lastCrossing).inMilliseconds;
      if (ms < minSectorMs) {
        debugPrint(
          '[LapDetector] Setor $index rejeitado (cooldown) — '
          'ms=$ms < minSectorMs=$minSectorMs',
        );
        return null;
      }
    }

    _sectorLastCrossing[index] = crossingTime;
    return crossingTime;
  }

  /// Fallback de detecção: verifica se a direção global A→B mudou de sinal
  /// E se o GPS está dentro da zona de proximidade perpendicular da fronteira.
  ///
  /// Cobre fronteiras curvas onde o algoritmo de sub-segmento falha porque
  /// nenhum segmento individual produz um sign-change com crossing dentro dos
  /// limites — situação comum com 15-40 middlePoints.
  DateTime? _checkLineByProximity(
    GeoPoint prev,
    GeoPoint curr,
    DateTime prevTime,
    DateTime currTime,
    TrackLine boundary,
    int index,
  ) {
    final prevSign = _sectorLastSign[index];
    if (prevSign == 0) return null;

    final currSign = _crossSign(boundary.a, boundary.b, curr);
    if (currSign == 0 || prevSign == currSign) return null;

    // Distância perpendicular à reta A→B em metros (sem sinal).
    const gpsAccuracy = 5.0;
    final threshold = boundary.widthMeters / 2 + gpsAccuracy;
    final perpPrev = _perpDistMeters(prev, boundary.a, boundary.b).abs();
    final perpCurr = _perpDistMeters(curr, boundary.a, boundary.b).abs();

    if (perpPrev > threshold && perpCurr > threshold) {
      debugPrint(
        '[LapDetector] Setor $index fallback rejeitado (distância perp) — '
        'perpPrev=${perpPrev.toStringAsFixed(1)}m '
        'perpCurr=${perpCurr.toStringAsFixed(1)}m '
        'threshold=${threshold.toStringAsFixed(1)}m',
      );
      return null;
    }

    // Interpola o timestamp: quanto mais próximo da fronteira, maior o peso.
    final t = perpPrev / (perpPrev + perpCurr + 1e-9);
    final dtMicros = currTime.difference(prevTime).inMicroseconds;
    final crossingTime = prevTime.add(
      Duration(microseconds: (dtMicros * t).round()),
    );

    debugPrint(
      '[LapDetector] Setor $index via fallback de proximidade — '
      'perpPrev=${perpPrev.toStringAsFixed(1)}m '
      'perpCurr=${perpCurr.toStringAsFixed(1)}m | '
      'timestamp=${crossingTime.toIso8601String()}',
    );

    return crossingTime;
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
        debugPrint(
          '[LapDetector] S/C válido (sem mediana ainda) — '
          'lapMs=$lapMs | heading=${heading.toStringAsFixed(3)} rad',
        );
        _updateRecentLaps(lapMs);
        event = LapCrossedEvent(crossingTime);
      }
    } else {
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
  /// de [line] via sign-change. Se cruzar, retorna o instante interpolado.
  ///
  /// [gpsAccuracyBuffer]: metros adicionados à tolerância de endpoint para
  /// compensar imprecisão do GPS. Use 0 para S/C (padrão), ~5 m para setores.
  DateTime? _checkLine(
    GeoPoint prev,
    GeoPoint curr,
    DateTime prevTime,
    DateTime currTime,
    TrackLine? line, {
    double gpsAccuracyBuffer = 0.0,
  }) {
    if (line == null) return null;

    final points = line.allPoints;
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];

      final signPrev = _crossSign(a, b, prev);
      final signCurr = _crossSign(a, b, curr);
      if (signPrev == 0 || signCurr == 0) continue;
      if (signPrev == signCurr) continue;

      final params = _crossingParams(
        prev, curr, a, b, line.widthMeters,
        gpsAccuracyBuffer: gpsAccuracyBuffer,
      );
      if (params == null) continue;

      final dtMicros = currTime.difference(prevTime).inMicroseconds;
      final crossingTime = prevTime.add(
        Duration(microseconds: (dtMicros * params.t).round()),
      );
      return crossingTime;
    }
    return null;
  }

  /// Sinal do produto vetorial (B-A) × (P-A) em coordenadas 2D planas.
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
  /// [gpsAccuracyBuffer]: buffer adicional em metros na tolerância de endpoint.
  static ({double s, double t})? _crossingParams(
    GeoPoint prev,
    GeoPoint curr,
    GeoPoint a,
    GeoPoint b,
    double bufferMeters, {
    double gpsAccuracyBuffer = 0.0,
  }) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.lat * math.pi / 180);

    final mx = (curr.lng - prev.lng) * lng2m;
    final my = (curr.lat - prev.lat) * lat2m;

    final lx = (b.lng - a.lng) * lng2m;
    final ly = (b.lat - a.lat) * lat2m;

    final denom = lx * my - mx * ly;
    if (denom.abs() < 1e-9) return null;

    final ax = (a.lng - prev.lng) * lng2m;
    final ay = (a.lat - prev.lat) * lat2m;

    final s = (mx * ay - my * ax) / denom;

    final segLen = math.sqrt(lx * lx + ly * ly);
    final tolerance =
        segLen > 0 ? (bufferMeters / 2 + gpsAccuracyBuffer) / segLen : 0.0;
    if (s < -tolerance || s > 1.0 + tolerance) return null;

    final t = (lx * ay - ly * ax) / denom;

    return (s: s, t: t.clamp(0.0, 1.0));
  }

  /// Distância perpendicular com sinal (metros) de [p] à reta que passa por
  /// [a] e [b]. Positivo = mesmo lado que a normal (b-a rotacionada 90°).
  static double _perpDistMeters(GeoPoint p, GeoPoint a, GeoPoint b) {
    const lat2m = 111320.0;
    final lng2m = 111320.0 * math.cos(a.lat * math.pi / 180);

    final lx = (b.lng - a.lng) * lng2m;
    final ly = (b.lat - a.lat) * lat2m;
    final len = math.sqrt(lx * lx + ly * ly);
    if (len < 1e-9) return 0;

    final ax = (p.lng - a.lng) * lng2m;
    final ay = (p.lat - a.lat) * lat2m;

    return (lx * ay - ly * ax) / len;
  }

  /// Bearing do vetor [from]→[to] em radianos no intervalo [-π, π].
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
