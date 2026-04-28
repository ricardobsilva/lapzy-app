import 'package:flutter/foundation.dart';

import '../models/race_session.dart';
import '../models/race_session_record.dart';
import '../models/track.dart';
import '../repositories/race_session_repository.dart';
import '../repositories/track_repository.dart';

// IDs fixos — seed é idempotente (upsert por id)
const _idGranjaViana = 'a1b2c3d4-0001-4000-8000-seed00000001';
const _idSpeedPark   = 'a1b2c3d4-0002-4000-8000-seed00000002';
const _idCuritiba    = 'a1b2c3d4-0003-4000-8000-seed00000003';
const _idSessaoG     = 'b2c3d4e5-0001-4000-8000-seed00000001';
const _idSessaoS     = 'b2c3d4e5-0002-4000-8000-seed00000002';
const _idSessaoC     = 'b2c3d4e5-0003-4000-8000-seed00000003';

/// Popula pistas e sessões realistas no dispositivo (apenas em debug).
/// Chamado em [main] antes do [runApp] — safe para rodar múltiplas vezes.
Future<void> seedDebugDataIfNeeded() async {
  if (!kDebugMode) return;
  // Evita re-seed se pistas seed já existem
  final alreadySeeded =
      TrackRepository().tracks.any((t) => t.id == _idGranjaViana);
  if (alreadySeeded) return;

  await _seedTracks();
  await _seedSessions();
}

Future<void> _seedTracks() async {
  // Kartódromo Ayrton Senna — Granja Viana, Cotia/SP
  await TrackRepository().save(Track(
    id: _idGranjaViana,
    name: 'Granja Viana',
    startFinishLine: const TrackLine(
      a: GeoPoint(-23.58972, -46.87115),
      b: GeoPoint(-23.58985, -46.87098),
      widthMeters: 7.0,
    ),
    sectorBoundaries: const [
      TrackLine(
        a: GeoPoint(-23.58910, -46.87048),
        b: GeoPoint(-23.58924, -46.87033),
        widthMeters: 7.0,
      ),
      TrackLine(
        a: GeoPoint(-23.59018, -46.87182),
        b: GeoPoint(-23.59031, -46.87167),
        widthMeters: 7.0,
      ),
    ],
    createdAt: DateTime.utc(2026, 3, 10, 9, 0),
    updatedAt: DateTime.utc(2026, 3, 10, 9, 0),
  ));

  // Kartódromo Speed Park — Itapevi/SP
  await TrackRepository().save(Track(
    id: _idSpeedPark,
    name: 'Speed Park Itapevi',
    startFinishLine: const TrackLine(
      a: GeoPoint(-23.54132, -46.93512),
      b: GeoPoint(-23.54146, -46.93495),
      widthMeters: 8.0,
    ),
    sectorBoundaries: const [
      TrackLine(
        a: GeoPoint(-23.54065, -46.93610),
        b: GeoPoint(-23.54080, -46.93593),
        widthMeters: 8.0,
      ),
    ],
    createdAt: DateTime.utc(2026, 3, 22, 10, 30),
    updatedAt: DateTime.utc(2026, 3, 22, 10, 30),
  ));

  // Kartódromo Internacional de Curitiba — Pinhais/PR
  await TrackRepository().save(Track(
    id: _idCuritiba,
    name: 'Kartódromo Internacional de Curitiba',
    startFinishLine: const TrackLine(
      a: GeoPoint(-25.44887, -49.27588),
      b: GeoPoint(-25.44900, -49.27573),
      widthMeters: 9.0,
    ),
    sectorBoundaries: const [
      TrackLine(
        a: GeoPoint(-25.44820, -49.27678),
        b: GeoPoint(-25.44835, -49.27663),
        widthMeters: 9.0,
      ),
      TrackLine(
        a: GeoPoint(-25.44968, -49.27728),
        b: GeoPoint(-25.44982, -49.27713),
        widthMeters: 9.0,
      ),
    ],
    createdAt: DateTime.utc(2026, 4, 5, 8, 0),
    updatedAt: DateTime.utc(2026, 4, 5, 8, 0),
  ));
}

Future<void> _seedSessions() async {
  // Sessão Granja Viana — 15/04/2026 — 12 voltas — best: 54.890 (V5)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessaoG,
    trackId: _idGranjaViana,
    trackName: 'Granja Viana',
    date: DateTime.utc(2026, 4, 15, 13, 0),
    bestLapMs: 54890,
    createdAt: DateTime.utc(2026, 4, 15, 13, 48),
    laps: const [
      LapResult(lapMs: 59820, sectors: [23200, 20300, 16320]),
      LapResult(lapMs: 57340, sectors: [22240, 19390, 15710]),
      LapResult(lapMs: 56120, sectors: [21790, 18960, 15370]),
      LapResult(lapMs: 55480, sectors: [21480, 18730, 15270]),
      LapResult(lapMs: 54890, sectors: [21270, 18460, 15160]), // BEST
      LapResult(lapMs: 54920, sectors: [21280, 18460, 15180]),
      LapResult(lapMs: 55100, sectors: [21350, 18510, 15240]),
      LapResult(lapMs: 55640, sectors: [21540, 18780, 15320]),
      LapResult(lapMs: 55980, sectors: [21680, 18900, 15400]),
      LapResult(lapMs: 56230, sectors: [21790, 19010, 15430]),
      LapResult(lapMs: 55870, sectors: [21640, 18860, 15370]),
      LapResult(lapMs: 55420, sectors: [21470, 18700, 15250]),
    ],
  ));

  // Sessão Speed Park — 20/04/2026 — 12 voltas — best: 1:04.420 (V5)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessaoS,
    trackId: _idSpeedPark,
    trackName: 'Speed Park Itapevi',
    date: DateTime.utc(2026, 4, 20, 15, 30),
    bestLapMs: 64420,
    createdAt: DateTime.utc(2026, 4, 20, 16, 22),
    laps: const [
      LapResult(lapMs: 68450, sectors: [33840, 34610]),
      LapResult(lapMs: 66230, sectors: [32740, 33490]),
      LapResult(lapMs: 65180, sectors: [32230, 32950]),
      LapResult(lapMs: 64870, sectors: [32080, 32790]),
      LapResult(lapMs: 64420, sectors: [31860, 32560]), // BEST
      LapResult(lapMs: 64650, sectors: [31970, 32680]),
      LapResult(lapMs: 64580, sectors: [31930, 32650]),
      LapResult(lapMs: 65120, sectors: [32200, 32920]),
      LapResult(lapMs: 65340, sectors: [32310, 33030]),
      LapResult(lapMs: 65780, sectors: [32530, 33250]),
      LapResult(lapMs: 65230, sectors: [32260, 32970]),
      LapResult(lapMs: 64960, sectors: [32130, 32830]),
    ],
  ));

  // Sessão Curitiba — 25/04/2026 — 12 voltas — best: 53.180 (V6)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessaoC,
    trackId: _idCuritiba,
    trackName: 'Kartódromo Internacional de Curitiba',
    date: DateTime.utc(2026, 4, 25, 10, 0),
    bestLapMs: 53180,
    createdAt: DateTime.utc(2026, 4, 25, 10, 52),
    laps: const [
      LapResult(lapMs: 58340, sectors: [22450, 20180, 15710]),
      LapResult(lapMs: 56120, sectors: [21600, 19430, 15090]),
      LapResult(lapMs: 54870, sectors: [21110, 18990, 14770]),
      LapResult(lapMs: 53980, sectors: [20760, 18690, 14530]),
      LapResult(lapMs: 53420, sectors: [20540, 18430, 14450]),
      LapResult(lapMs: 53180, sectors: [20450, 18310, 14420]), // BEST
      LapResult(lapMs: 53290, sectors: [20500, 18350, 14440]),
      LapResult(lapMs: 53560, sectors: [20600, 18490, 14470]),
      LapResult(lapMs: 53840, sectors: [20710, 18620, 14510]),
      LapResult(lapMs: 54120, sectors: [20820, 18750, 14550]),
      LapResult(lapMs: 53790, sectors: [20680, 18580, 14530]),
      LapResult(lapMs: 53450, sectors: [20560, 18440, 14450]),
    ],
  ));
}
