import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/services/lap_detector.dart';

// ── HELPERS ───────────────────────────────────────────────────────────────────

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 1, 1),
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

Position _posAt(double lat, double lng, DateTime timestamp) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: timestamp,
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

/// Cria um LapDetector com stream de posições controlado por [controller].
LapDetector _detectorWithStream(
  Track track,
  StreamController<Position> controller, {
  int minLapMs = 5000,
  double maxOutlierFraction = 0.20,
  int maxOutlierMs = 5000,
  int recentLapsForMedian = 5,
}) {
  return LapDetector(
    track: track,
    positionStreamFactory: () => controller.stream,
    minLapMs: minLapMs,
    maxOutlierFraction: maxOutlierFraction,
    maxOutlierMs: maxOutlierMs,
    recentLapsForMedian: recentLapsForMedian,
  );
}

/// Pista mínima: linha S/C horizontal em lat=-23.5, lng de -46.63 até -46.62.
/// Largura de detecção: 50m. Posições de teste usam ±0.0004 lat (~44m).
Track _trackWithLine() {
  return const Track(
    id: 'test',
    name: 'Test Track',
    startFinishLine: TrackLine(
      a: GeoPoint(-23.5, -46.63),
      b: GeoPoint(-23.5, -46.62),
      widthMeters: 50.0,
    ),
  );
}

/// Pista com S/C + 2 setores.
Track _trackWithSectors() {
  return const Track(
    id: 'test',
    name: 'Test Track',
    startFinishLine: TrackLine(
      a: GeoPoint(-23.500, -46.630),
      b: GeoPoint(-23.500, -46.620),
      widthMeters: 50.0,
    ),
    sectorBoundaries: [
      TrackLine(
        a: GeoPoint(-23.490, -46.630),
        b: GeoPoint(-23.490, -46.620),
        widthMeters: 50.0,
      ),
      TrackLine(
        a: GeoPoint(-23.480, -46.630),
        b: GeoPoint(-23.480, -46.620),
        widthMeters: 50.0,
      ),
    ],
  );
}

// ── TESTES ────────────────────────────────────────────────────────────────────

void main() {
  group('LapDetector', () {
    group('cruzamento da linha S/C', () {
      test('emite LapCrossedEvent ao cruzar de sul para norte', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Sul da linha → norte da linha (cruza lat=-23.5); ±0.0004 ≈ 44m < 50m
        ctrl.add(_pos(-23.5004, -46.625)); // antes
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625)); // depois
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<LapCrossedEvent>());

        detector.dispose();
        await ctrl.close();
      });

      test('emite LapCrossedEvent ao cruzar de norte para sul', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<LapCrossedEvent>());

        detector.dispose();
        await ctrl.close();
      });

      test('não emite evento quando cruzamento ocorre fora dos limites do segmento', () async {
        final ctrl = StreamController<Position>();
        const trackFarAway = Track(
          id: 'far',
          name: 'Far Track',
          startFinishLine: TrackLine(
            a: GeoPoint(-23.5, -46.63),
            b: GeoPoint(-23.5, -46.62),
            widthMeters: 6.0,
          ),
        );
        final detector = _detectorWithStream(trackFarAway, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza em lng=-46.700, muito além do segmento [-46.63, -46.62]
        ctrl.add(_pos(-23.5004, -46.700));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.700));
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });

      test('não emite evento sem linha S/C definida', () async {
        final ctrl = StreamController<Position>();
        const trackNoLine = Track(id: 'no-line', name: 'No Line');
        final detector = _detectorWithStream(trackNoLine, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });

      test('primeira posição não emite evento (sem posição anterior)', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.4996, -46.625)); // apenas uma posição
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });
    });

    group('cruzamento de setores', () {
      test('emite SectorCrossedEvent(0) ao cruzar boundary S1', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithSectors();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza boundary do S1 em lat=-23.490; ±0.0004 ≈ 44m < 50m
        ctrl.add(_pos(-23.4904, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4896, -46.625));
        await Future.delayed(Duration.zero);

        final sectorEvents = events.whereType<SectorCrossedEvent>().toList();
        expect(sectorEvents, hasLength(1));
        expect(sectorEvents.first.sectorIndex, 0);

        detector.dispose();
        await ctrl.close();
      });

      test('emite SectorCrossedEvent(1) ao cruzar boundary S2', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithSectors();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza boundary do S2 em lat=-23.480; ±0.0004 ≈ 44m < 50m
        ctrl.add(_pos(-23.4804, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4796, -46.625));
        await Future.delayed(Duration.zero);

        final sectorEvents = events.whereType<SectorCrossedEvent>().toList();
        expect(sectorEvents, hasLength(1));
        expect(sectorEvents.first.sectorIndex, 1);

        detector.dispose();
        await ctrl.close();
      });
    });

    group('polilinha (middlePoints)', () {
      test('detecta cruzamento no sub-segmento intermediário da polilinha', () async {
        final ctrl = StreamController<Position>();
        const track = Track(
          id: 'poly',
          name: 'Poly Track',
          startFinishLine: TrackLine(
            a: GeoPoint(-23.500, -46.630),
            b: GeoPoint(-23.495, -46.620),
            middlePoints: [GeoPoint(-23.495, -46.630)],
            widthMeters: 50.0,
          ),
        );
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Cruza o sub-segmento horizontal em lat=-23.495 no lng=-46.625
        ctrl.add(_pos(-23.4954, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4946, -46.625));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<LapCrossedEvent>());

        detector.dispose();
        await ctrl.close();
      });

      test('não detecta cruzamento fora dos sub-segmentos da polilinha', () async {
        final ctrl = StreamController<Position>();
        const track = Track(
          id: 'poly-outside',
          name: 'Poly Outside Track',
          startFinishLine: TrackLine(
            a: GeoPoint(-23.500, -46.630),
            b: GeoPoint(-23.495, -46.620),
            middlePoints: [GeoPoint(-23.495, -46.630)],
            widthMeters: 6.0,
          ),
        );
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.4954, -46.700));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4946, -46.700));
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });

      test('não dispara dois eventos ao cruzar linha reta sem middlePoints (regressão)', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));

        detector.dispose();
        await ctrl.close();
      });
    });

    group('timestamp interpolado', () {
      test('timestamp do evento está entre os timestamps das duas posições GPS', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final t0 = DateTime(2026, 1, 1, 12, 0, 0);
        final t1 = DateTime(2026, 1, 1, 12, 0, 1); // 1s depois

        // Cruzamento exato em lat=-23.500: metade entre -23.5004 e -23.4996
        ctrl.add(_posAt(-23.5004, -46.625, t0));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t1));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        final event = events.first as LapCrossedEvent;
        // t ≈ 0.5 → crossingTime ≈ t0 + 500ms
        expect(event.timestamp.isAfter(t0), isTrue);
        expect(event.timestamp.isBefore(t1), isTrue);
        final delta = event.timestamp.difference(t0).inMilliseconds;
        expect(delta, greaterThan(450));
        expect(delta, lessThan(550));

        detector.dispose();
        await ctrl.close();
      });

      test('timestamp igual a prevTime quando cruzamento ocorre no início do vetor', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final t0 = DateTime(2026, 1, 1, 12, 0, 0);
        final t1 = DateTime(2026, 1, 1, 12, 0, 1);

        ctrl.add(_posAt(-23.50001, -46.625, t0));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t1));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        final event = events.first as LapCrossedEvent;
        expect(event.timestamp.isAfter(t0) || event.timestamp == t0, isTrue);
        expect(event.timestamp.isBefore(t1), isTrue);

        detector.dispose();
        await ctrl.close();
      });
    });

    group('stop e dispose', () {
      test('stop cancela a stream — sem novos eventos após stop', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        detector.stop();

        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });

      test('stop reseta posição anterior — primeiro evento após restart não dispara', () async {
        final ctrl = StreamController<Position>.broadcast();
        final track = _trackWithLine();
        final detector = LapDetector(
          track: track,
          positionStreamFactory: () => ctrl.stream,
          minLapMs: 5000,
        );
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        ctrl.add(_pos(-23.5004, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);
        expect(events, hasLength(1));

        detector.stop();
        detector.start();

        ctrl.add(_pos(-23.4996, -46.625));
        await Future.delayed(Duration.zero);
        expect(events, hasLength(1)); // ainda 1, sem novo evento

        detector.dispose();
        await ctrl.close();
      });
    });

    // ── NOVOS CENÁRIOS ────────────────────────────────────────────────────────

    group('cooldown (minLapMs)', () {
      test('cruza a linha no sentido correto → registra volta', () async {
        // Verifica que o comportamento normal continua funcionando.
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl, minLapMs: 5000);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final t0 = DateTime(2026, 1, 1, 12, 0, 0);
        ctrl.add(_posAt(-23.5004, -46.625, t0));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t0.add(const Duration(seconds: 1))));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<LapCrossedEvent>());

        detector.dispose();
        await ctrl.close();
      });

      test('segundo cruzamento antes do cooldown → rejeitado', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        // minLapMs = 60 000ms; segundo cruzamento a 2s → deve ser rejeitado
        final detector = _detectorWithStream(track, ctrl, minLapMs: 60000);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final t0 = DateTime(2026, 1, 1, 12, 0, 0);

        // Primeiro cruzamento (sul → norte)
        ctrl.add(_posAt(-23.5004, -46.625, t0));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t0.add(const Duration(seconds: 1))));
        await Future.delayed(Duration.zero);

        // Segundo cruzamento apenas 2s depois — dentro do cooldown de 60s
        ctrl.add(_posAt(-23.5004, -46.625, t0.add(const Duration(seconds: 2))));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t0.add(const Duration(seconds: 3))));
        await Future.delayed(Duration.zero);

        // Apenas o primeiro evento deve ter sido emitido
        expect(events, hasLength(1));

        detector.dispose();
        await ctrl.close();
      });

      test('segundo cruzamento após o cooldown → registrado normalmente', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl, minLapMs: 5000);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final t0 = DateTime(2026, 1, 1, 12, 0, 0);

        // Primeiro cruzamento
        ctrl.add(_posAt(-23.5004, -46.625, t0));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t0.add(const Duration(seconds: 1))));
        await Future.delayed(Duration.zero);

        // Simula kart circulando e voltando (10s depois, além dos 5s de cooldown)
        ctrl.add(_posAt(-23.5004, -46.625, t0.add(const Duration(seconds: 10))));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t0.add(const Duration(seconds: 11))));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(2));
        expect(events[1], isA<LapCrossedEvent>());

        detector.dispose();
        await ctrl.close();
      });
    });

    group('validação de direção', () {
      test('cruzamento no sentido contrário após referência → rejeitado', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl, minLapMs: 1000);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final t0 = DateTime(2026, 1, 1, 12, 0, 0);

        // Primeiro cruzamento sul→norte (estabelece referência de heading)
        ctrl.add(_posAt(-23.5004, -46.625, t0));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t0.add(const Duration(seconds: 1))));
        await Future.delayed(Duration.zero);

        // Segundo cruzamento norte→sul (180° oposto — deve ser rejeitado)
        ctrl.add(_posAt(-23.4996, -46.625, t0.add(const Duration(seconds: 10))));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.5004, -46.625, t0.add(const Duration(seconds: 11))));
        await Future.delayed(Duration.zero);

        // Apenas o primeiro cruzamento (referência) é aceito
        expect(events, hasLength(1));
        expect(events.first, isA<LapCrossedEvent>());

        detector.dispose();
        await ctrl.close();
      });

      test('cruzamento compatível com referência (mesmo sentido) → aceito', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl, minLapMs: 1000);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final t0 = DateTime(2026, 1, 1, 12, 0, 0);

        // Primeiro cruzamento sul→norte
        ctrl.add(_posAt(-23.5004, -46.625, t0));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t0.add(const Duration(seconds: 1))));
        await Future.delayed(Duration.zero);

        // Segundo cruzamento sul→norte (mesmo sentido, após cooldown)
        ctrl.add(_posAt(-23.5004, -46.625, t0.add(const Duration(seconds: 10))));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, t0.add(const Duration(seconds: 11))));
        await Future.delayed(Duration.zero);

        expect(events, hasLength(2));

        detector.dispose();
        await ctrl.close();
      });
    });

    group('interpolação de timestamp — base de cálculo de volta', () {
      test('tempo da volta calculado com timestamps GPS, não com relógio de parede', () async {
        // Reproduz o bug original: GPS a 0.2Hz (5s/update) com kart cruzando
        // a ~2.5s dentro do intervalo GPS. Sem fix, o app usaria t=GPS_fire.
        // Com fix (event.timestamp), o tempo da volta deve ser preciso.
        //
        // Setup:
        //   GPS0 @ t=0:   kart sul da linha
        //   GPS1 @ t=5:   kart norte da linha (cruzou a ~t=2.5, t_ratio≈0.5)
        //   GPS2 @ t=10:  kart sul da linha (cruzou a ~t=7.5, t_ratio≈0.5)
        //
        // Volta real: evento1.timestamp - evento0.timestamp ≈ 2.5s.
        // Sem fix: lapMs = clock_at_GPS2 - clock_at_GPS1 = 10 - 5 = 5s (errado).
        // Com fix: lapMs = crossingTime2 - crossingTime1 = 7.5 - 2.5 = 5s...
        //   Hmm, neste exemplo ambos dariam 5s. Vamos usar um caso mais claro:
        //   GPS a 5s, crossing em t=0.5 no 1o interval, e t=4.8 no 2o interval.

        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(track, ctrl, minLapMs: 1000);
        detector.start();

        final lapEvents = <LapCrossedEvent>[];
        detector.events.listen((e) {
          if (e is LapCrossedEvent) lapEvents.add(e);
        });

        final base = DateTime(2026, 1, 1, 12, 0, 0);

        // Intervalo 1: t=0 a t=5s. Kart cruza a lat=-23.5 quando está 10% do caminho.
        // prevLat=-23.5004 → currLat=-23.4996, crossing ≈ t≈0 + 0.5*5 = t≈2.5s
        // (cruzamento exato no meio: ≈t=2.5s)
        ctrl.add(_posAt(-23.5004, -46.625, base)); // t=0
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, base.add(const Duration(seconds: 5)))); // t=5
        await Future.delayed(Duration.zero);

        // Kart continua, simula posições intermediárias sem cruzar a linha
        ctrl.add(_posAt(-23.4990, -46.625, base.add(const Duration(seconds: 10))));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4985, -46.625, base.add(const Duration(seconds: 15))));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4980, -46.625, base.add(const Duration(seconds: 20))));
        await Future.delayed(Duration.zero);

        // Intervalo 2: t=25 a t=30s. Kart volta a cruzar a linha.
        // prevLat=-23.5006 → currLat=-23.4994, crossing ≈ t=25 + 0.5*5 = t=27.5s
        ctrl.add(_posAt(-23.5006, -46.625, base.add(const Duration(seconds: 25))));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4994, -46.625, base.add(const Duration(seconds: 30))));
        await Future.delayed(Duration.zero);

        expect(lapEvents, hasLength(2));

        final startTime = lapEvents[0].timestamp;
        final endTime = lapEvents[1].timestamp;

        // Ambos os timestamps devem ser interpolados (não nos múltiplos exatos de 5s)
        expect(startTime, isNot(equals(base))); // não é t=0
        expect(startTime, isNot(equals(base.add(const Duration(seconds: 5))))); // não é t=5

        // O tempo da volta calculado com os timestamps GPS = endTime - startTime
        final lapMs = endTime.difference(startTime).inMilliseconds;
        // Crossing1 ≈ t=2.5s, Crossing2 ≈ t=27.5s → lap ≈ 25s
        expect(lapMs, greaterThan(24000));
        expect(lapMs, lessThan(26000));

        detector.dispose();
        await ctrl.close();
      });
    });

    group('outlier (suspeito)', () {
      test('volta dentro da faixa normal → LapCrossedEvent (não suspeito)', () async {
        // Contexto: GPS a ~1Hz, kart cruzando sempre sul→norte.
        // Padrão: GPS(south, t=N) seguido por GPS(north, t=N+1)
        //   → cruzamento detectado em t≈N+0.5 (t_ratio≈0.5).
        // Laps de 60s:
        //   crossing0 ≈ 0.5s  (inicial, sem volta)
        //   crossing1 ≈ 60.5s → lap=60000ms
        //   crossing2 ≈ 120.5s → lap=60000ms
        //   ...
        //   crossing4 ≈ 240.5s → lap=60000ms  (mediana=60000)
        // Lap "normal": crossing em ≈302.5s (GPS em [302,303]) → lap=62000ms
        //   Desvio=2000ms < maxOutlierMs=5000ms → NÃO suspeita.
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(
          track, ctrl,
          minLapMs: 1000,
          maxOutlierFraction: 0.20,
          maxOutlierMs: 5000,
        );
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final base = DateTime(2026, 1, 1, 12, 0, 0);

        // 5 cruzamentos base (establece referência + 4 voltas de 60s na mediana)
        for (int i = 0; i < 5; i++) {
          final t = base.add(Duration(seconds: i * 60));
          ctrl.add(_posAt(-23.5004, -46.625, t));
          await Future.delayed(Duration.zero);
          ctrl.add(_posAt(-23.4996, -46.625, t.add(const Duration(seconds: 1))));
          await Future.delayed(Duration.zero);
        }
        // crossing4 ≈ 240.5s; mediana das 4 voltas = 60000ms

        // Volta "normal": GPS em [302, 303] → crossing ≈ 302.5s
        // lapMs = 302.5 - 240.5 = 62000ms → desvio=2000ms < 5000ms → normal
        final tNormal = base.add(const Duration(seconds: 302));
        ctrl.add(_posAt(-23.5004, -46.625, tNormal));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, tNormal.add(const Duration(seconds: 1))));
        await Future.delayed(Duration.zero);

        final suspectEvents = events.whereType<LapCrossedSuspectEvent>().toList();
        expect(suspectEvents, isEmpty);
        expect(events.whereType<LapCrossedEvent>(), isNotEmpty);

        detector.dispose();
        await ctrl.close();
      });

      test('volta muito fora da mediana → LapCrossedSuspectEvent', () async {
        // Padrão similar ao teste anterior. 4 cruzamentos → 3 voltas de ~30s.
        // Cruzamento N:  GPS(south, t=N*30), GPS(north, t=N*30+1)
        //   → crossing ≈ N*30 + 0.5s
        // crossing0≈0.5s, crossing1≈30.5s, crossing2≈60.5s, crossing3≈90.5s
        // Mediana das 3 voltas = 30000ms
        //
        // Volta anômala: GPS(south, t=120), GPS(north, t=210)
        //   → south crossing rejeitada (direção)
        //   → north crossing: t_ratio=0.5 → crossingAnomalo = 120 + 0.5*90 = 165s
        //   → lapMs = 165 - 90.5 = 74500ms
        //   → desvio = 44500ms >> maxOutlierMs=5000ms → SUSPEITA ✓
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(
          track, ctrl,
          minLapMs: 1000,
          maxOutlierFraction: 0.20,
          maxOutlierMs: 5000,
          recentLapsForMedian: 3,
        );
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final base = DateTime(2026, 1, 1, 12, 0, 0);

        // 4 cruzamentos base → 3 voltas de ~30s
        for (int i = 0; i < 4; i++) {
          final t = base.add(Duration(seconds: i * 30));
          ctrl.add(_posAt(-23.5004, -46.625, t));
          await Future.delayed(Duration.zero);
          ctrl.add(_posAt(-23.4996, -46.625, t.add(const Duration(seconds: 1))));
          await Future.delayed(Duration.zero);
        }

        // GPS(south, t=120) → crossing south rejeitada; GPS(north, t=210) → aceita
        // lapMs ≈ 74500ms (muito acima de maxOutlierMs=5000 da mediana≈30000ms)
        final tAnomaly = base.add(const Duration(seconds: 120));
        ctrl.add(_posAt(-23.5004, -46.625, tAnomaly));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, tAnomaly.add(const Duration(seconds: 90))));
        await Future.delayed(Duration.zero);

        final suspectEvents = events.whereType<LapCrossedSuspectEvent>().toList();
        expect(suspectEvents, hasLength(1));
        // lapMs ≈ 74500ms (calculado acima)
        expect(suspectEvents.first.lapMs, greaterThan(70000));
        expect(suspectEvents.first.medianMs, greaterThan(0));

        detector.dispose();
        await ctrl.close();
      });

      test('primeira volta nunca é suspeita (sem mediana ainda)', () async {
        final ctrl = StreamController<Position>();
        final track = _trackWithLine();
        final detector = _detectorWithStream(
          track, ctrl,
          minLapMs: 1000,
          maxOutlierFraction: 0.01, // limiar extremamente baixo
          maxOutlierMs: 100,
        );
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        final base = DateTime(2026, 1, 1, 12, 0, 0);

        // Dois cruzamentos (primeiro = start, segundo = fim da primeira volta)
        ctrl.add(_posAt(-23.5004, -46.625, base));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, base.add(const Duration(seconds: 1))));
        await Future.delayed(Duration.zero);

        ctrl.add(_posAt(-23.5004, -46.625, base.add(const Duration(seconds: 10))));
        await Future.delayed(Duration.zero);
        ctrl.add(_posAt(-23.4996, -46.625, base.add(const Duration(seconds: 11))));
        await Future.delayed(Duration.zero);

        // A primeira volta completa (segundo evento) não deve ser suspeita
        // (não há mediana ainda)
        final suspectEvents = events.whereType<LapCrossedSuspectEvent>().toList();
        expect(suspectEvents, isEmpty);
        expect(events, hasLength(2));

        detector.dispose();
        await ctrl.close();
      });
    });

    group('passa perto mas não cruza', () {
      test('GPS tangencia a linha sem cruzar → sem evento', () async {
        final ctrl = StreamController<Position>();
        // Linha em lat=-23.5, largura 6m (~0.000054 graus lat)
        const track = Track(
          id: 'narrow',
          name: 'Narrow',
          startFinishLine: TrackLine(
            a: GeoPoint(-23.5, -46.63),
            b: GeoPoint(-23.5, -46.62),
            widthMeters: 6.0,
          ),
        );
        final detector = _detectorWithStream(track, ctrl);
        detector.start();

        final events = <LapEvent>[];
        detector.events.listen(events.add);

        // Move paralelo à linha (mesmo lado a todo momento — não cruza)
        ctrl.add(_pos(-23.5050, -46.625));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.5050, -46.615));
        await Future.delayed(Duration.zero);
        ctrl.add(_pos(-23.5050, -46.605));
        await Future.delayed(Duration.zero);

        expect(events, isEmpty);

        detector.dispose();
        await ctrl.close();
      });
    });
  });
}
