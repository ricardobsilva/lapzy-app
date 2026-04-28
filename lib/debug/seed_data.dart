import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/race_session.dart';
import '../models/race_session_record.dart';
import '../models/track.dart';
import '../repositories/race_session_repository.dart';
import '../repositories/track_repository.dart';

// Versão do seed — incrementar aqui força re-seed em instâncias já populadas
const _kSeedVersion = 2;
const _kSeedVersionKey = 'lapzy_seed_version';

// IDs fixos de pistas
const _idGranjaViana = 'a1b2c3d4-0001-4000-8000-seed00000001';
const _idInterlagos  = 'a1b2c3d4-0002-4000-8000-seed00000002';
const _idCuritiba    = 'a1b2c3d4-0003-4000-8000-seed00000003';
const _idCascavel    = 'a1b2c3d4-0004-4000-8000-seed00000004';
const _idGoiania     = 'a1b2c3d4-0005-4000-8000-seed00000005';
const _idBH          = 'a1b2c3d4-0006-4000-8000-seed00000006';
const _idLondrina    = 'a1b2c3d4-0007-4000-8000-seed00000007';
const _idBetoCarrero = 'a1b2c3d4-0008-4000-8000-seed00000008';

// IDs fixos de sessões
const _idSessao1 = 'b2c3d4e5-0001-4000-8000-seed00000001';
const _idSessao2 = 'b2c3d4e5-0002-4000-8000-seed00000002';
const _idSessao3 = 'b2c3d4e5-0003-4000-8000-seed00000003';
const _idSessao4 = 'b2c3d4e5-0004-4000-8000-seed00000004';
const _idSessao5 = 'b2c3d4e5-0005-4000-8000-seed00000005';
const _idSessao6 = 'b2c3d4e5-0006-4000-8000-seed00000006';
const _idSessao7 = 'b2c3d4e5-0007-4000-8000-seed00000007';
const _idSessao8 = 'b2c3d4e5-0008-4000-8000-seed00000008';

DateTime _dt(int y, int m, int d, int h, int min) =>
    DateTime.utc(y, m, d, h, min);

/// Popula pistas e sessões realistas no dispositivo (apenas em debug).
/// Chamado em [main] antes do [runApp] — safe para rodar múltiplas vezes.
/// Usa versionamento: incrementar [_kSeedVersion] força re-seed completo.
Future<void> seedDebugDataIfNeeded() async {
  if (!kDebugMode) return;
  final prefs = await SharedPreferences.getInstance();
  final storedVersion = prefs.getInt(_kSeedVersionKey) ?? 0;
  if (storedVersion >= _kSeedVersion) return;

  await _clearSeedData();
  await _seedTracks();
  await _seedSessions();
  await prefs.setInt(_kSeedVersionKey, _kSeedVersion);
}

Future<void> _clearSeedData() async {
  final trackIds = [
    _idGranjaViana, _idInterlagos, _idCuritiba, _idCascavel,
    _idGoiania, _idBH, _idLondrina, _idBetoCarrero,
  ];
  final sessionIds = [
    _idSessao1, _idSessao2, _idSessao3, _idSessao4,
    _idSessao5, _idSessao6, _idSessao7, _idSessao8,
  ];
  for (final id in trackIds) {
    await TrackRepository().remove(id);
  }
  for (final id in sessionIds) {
    await RaceSessionRepository().delete(id);
  }
}

Future<void> _seedTracks() async {
  // ── 1. Kartódromo Ayrton Senna — Granja Viana, Cotia/SP ──────────────────
  // Pista ~680m com 6 setores. Layout em S duplo à beira do autódromo.
  await TrackRepository().save(Track(
    id: _idGranjaViana,
    name: 'Kartódromo Ayrton Senna',
    startFinishLine: const TrackLine(
      a: GeoPoint(-23.58972, -46.87115),
      b: GeoPoint(-23.58985, -46.87098),
      widthMeters: 7.0,
    ),
    sectorBoundaries: const [
      TrackLine(a: GeoPoint(-23.58910, -46.87048), b: GeoPoint(-23.58924, -46.87033), widthMeters: 7.0),
      TrackLine(a: GeoPoint(-23.58855, -46.86985), b: GeoPoint(-23.58869, -46.86970), widthMeters: 7.0),
      TrackLine(a: GeoPoint(-23.58960, -46.86942), b: GeoPoint(-23.58975, -46.86927), widthMeters: 7.0),
      TrackLine(a: GeoPoint(-23.59042, -46.87012), b: GeoPoint(-23.59056, -46.86997), widthMeters: 7.0),
      TrackLine(a: GeoPoint(-23.59018, -46.87093), b: GeoPoint(-23.59031, -46.87078), widthMeters: 7.0),
    ],
    createdAt: _dt(2026, 1, 15, 8, 0),
    updatedAt: _dt(2026, 1, 15, 8, 0),
  ));

  // ── 2. Speed Park Interlagos — São Paulo/SP ───────────────────────────────
  // Pista ~920m com 7 setores. Complexo ao lado do Autódromo de Interlagos.
  await TrackRepository().save(Track(
    id: _idInterlagos,
    name: 'Speed Park Interlagos',
    startFinishLine: const TrackLine(
      a: GeoPoint(-23.70148, -46.69682),
      b: GeoPoint(-23.70162, -46.69665),
      widthMeters: 8.0,
    ),
    sectorBoundaries: const [
      TrackLine(a: GeoPoint(-23.70088, -46.69610), b: GeoPoint(-23.70102, -46.69593), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-23.70025, -46.69548), b: GeoPoint(-23.70040, -46.69531), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-23.70068, -46.69468), b: GeoPoint(-23.70083, -46.69451), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-23.70145, -46.69428), b: GeoPoint(-23.70160, -46.69411), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-23.70212, -46.69488), b: GeoPoint(-23.70227, -46.69471), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-23.70198, -46.69580), b: GeoPoint(-23.70213, -46.69563), widthMeters: 8.0),
    ],
    createdAt: _dt(2026, 1, 28, 9, 30),
    updatedAt: _dt(2026, 1, 28, 9, 30),
  ));

  // ── 3. Kartódromo Internacional de Curitiba — Pinhais/PR ─────────────────
  // Pista ~980m com 6 setores. Uma das mais técnicas do Brasil.
  await TrackRepository().save(Track(
    id: _idCuritiba,
    name: 'Kartódromo Internacional de Curitiba',
    startFinishLine: const TrackLine(
      a: GeoPoint(-25.44887, -49.27588),
      b: GeoPoint(-25.44900, -49.27573),
      widthMeters: 9.0,
    ),
    sectorBoundaries: const [
      TrackLine(a: GeoPoint(-25.44820, -49.27678), b: GeoPoint(-25.44835, -49.27663), widthMeters: 9.0),
      TrackLine(a: GeoPoint(-25.44762, -49.27762), b: GeoPoint(-25.44777, -49.27747), widthMeters: 9.0),
      TrackLine(a: GeoPoint(-25.44850, -49.27822), b: GeoPoint(-25.44865, -49.27807), widthMeters: 9.0),
      TrackLine(a: GeoPoint(-25.44948, -49.27778), b: GeoPoint(-25.44963, -49.27763), widthMeters: 9.0),
      TrackLine(a: GeoPoint(-25.44968, -49.27688), b: GeoPoint(-25.44982, -49.27673), widthMeters: 9.0),
    ],
    createdAt: _dt(2026, 2, 10, 7, 45),
    updatedAt: _dt(2026, 2, 10, 7, 45),
  ));

  // ── 4. Kartódromo de Cascavel — Cascavel/PR ───────────────────────────────
  // Pista ~840m com 8 setores. Tradicional palco do Campeonato Paranaense.
  await TrackRepository().save(Track(
    id: _idCascavel,
    name: 'Kartódromo de Cascavel',
    startFinishLine: const TrackLine(
      a: GeoPoint(-24.96438, -53.45418),
      b: GeoPoint(-24.96452, -53.45401),
      widthMeters: 7.5,
    ),
    sectorBoundaries: const [
      TrackLine(a: GeoPoint(-24.96372, -53.45355), b: GeoPoint(-24.96386, -53.45338), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-24.96318, -53.45295), b: GeoPoint(-24.96332, -53.45278), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-24.96348, -53.45218), b: GeoPoint(-24.96362, -53.45201), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-24.96415, -53.45178), b: GeoPoint(-24.96429, -53.45161), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-24.96488, -53.45215), b: GeoPoint(-24.96502, -53.45198), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-24.96522, -53.45302), b: GeoPoint(-24.96536, -53.45285), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-24.96492, -53.45378), b: GeoPoint(-24.96506, -53.45361), widthMeters: 7.5),
    ],
    createdAt: _dt(2026, 2, 22, 10, 0),
    updatedAt: _dt(2026, 2, 22, 10, 0),
  ));

  // ── 5. Kartódromo Adilson Pinheiro — Goiânia/GO ──────────────────────────
  // Pista ~720m com 7 setores. Principal pista do Centro-Oeste brasileiro.
  await TrackRepository().save(Track(
    id: _idGoiania,
    name: 'Kartódromo Adilson Pinheiro',
    startFinishLine: const TrackLine(
      a: GeoPoint(-16.68688, -49.26478),
      b: GeoPoint(-16.68702, -49.26461),
      widthMeters: 8.0,
    ),
    sectorBoundaries: const [
      TrackLine(a: GeoPoint(-16.68625, -49.26412), b: GeoPoint(-16.68639, -49.26395), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-16.68572, -49.26352), b: GeoPoint(-16.68586, -49.26335), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-16.68598, -49.26278), b: GeoPoint(-16.68612, -49.26261), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-16.68668, -49.26238), b: GeoPoint(-16.68682, -49.26221), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-16.68738, -49.26285), b: GeoPoint(-16.68752, -49.26268), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-16.68748, -49.26378), b: GeoPoint(-16.68762, -49.26361), widthMeters: 8.0),
    ],
    createdAt: _dt(2026, 3, 5, 8, 30),
    updatedAt: _dt(2026, 3, 5, 8, 30),
  ));

  // ── 6. Kartódromo Minas Gerais — Belo Horizonte/MG ───────────────────────
  // Pista ~620m com 6 setores. Localizado próximo ao Mineirão.
  await TrackRepository().save(Track(
    id: _idBH,
    name: 'Kartódromo Minas Gerais',
    startFinishLine: const TrackLine(
      a: GeoPoint(-19.86558, -43.97112),
      b: GeoPoint(-19.86572, -43.97095),
      widthMeters: 7.0,
    ),
    sectorBoundaries: const [
      TrackLine(a: GeoPoint(-19.86495, -43.97055), b: GeoPoint(-19.86509, -43.97038), widthMeters: 7.0),
      TrackLine(a: GeoPoint(-19.86445, -43.96998), b: GeoPoint(-19.86459, -43.96981), widthMeters: 7.0),
      TrackLine(a: GeoPoint(-19.86488, -43.96938), b: GeoPoint(-19.86502, -43.96921), widthMeters: 7.0),
      TrackLine(a: GeoPoint(-19.86558, -43.96912), b: GeoPoint(-19.86572, -43.96895), widthMeters: 7.0),
      TrackLine(a: GeoPoint(-19.86615, -43.96972), b: GeoPoint(-19.86629, -43.96955), widthMeters: 7.0),
    ],
    createdAt: _dt(2026, 3, 18, 9, 0),
    updatedAt: _dt(2026, 3, 18, 9, 0),
  ));

  // ── 7. Kartódromo de Londrina — Londrina/PR ───────────────────────────────
  // Pista ~660m com 6 setores. Palco da Copa São Paulo de Kart.
  await TrackRepository().save(Track(
    id: _idLondrina,
    name: 'Kartódromo de Londrina',
    startFinishLine: const TrackLine(
      a: GeoPoint(-23.30448, -51.16958),
      b: GeoPoint(-23.30462, -51.16941),
      widthMeters: 7.5,
    ),
    sectorBoundaries: const [
      TrackLine(a: GeoPoint(-23.30385, -51.16898), b: GeoPoint(-23.30399, -51.16881), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-23.30338, -51.16838), b: GeoPoint(-23.30352, -51.16821), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-23.30372, -51.16768), b: GeoPoint(-23.30386, -51.16751), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-23.30448, -51.16738), b: GeoPoint(-23.30462, -51.16721), widthMeters: 7.5),
      TrackLine(a: GeoPoint(-23.30508, -51.16808), b: GeoPoint(-23.30522, -51.16791), widthMeters: 7.5),
    ],
    createdAt: _dt(2026, 3, 30, 8, 0),
    updatedAt: _dt(2026, 3, 30, 8, 0),
  ));

  // ── 8. Kartódromo Beto Carrero — Penha/SC ────────────────────────────────
  // Pista ~760m com 7 setores. Localizado no complexo do parque temático.
  await TrackRepository().save(Track(
    id: _idBetoCarrero,
    name: 'Kartódromo Beto Carrero',
    startFinishLine: const TrackLine(
      a: GeoPoint(-26.80368, -48.64872),
      b: GeoPoint(-26.80382, -48.64855),
      widthMeters: 8.0,
    ),
    sectorBoundaries: const [
      TrackLine(a: GeoPoint(-26.80302, -48.64808), b: GeoPoint(-26.80316, -48.64791), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-26.80248, -48.64748), b: GeoPoint(-26.80262, -48.64731), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-26.80275, -48.64672), b: GeoPoint(-26.80289, -48.64655), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-26.80352, -48.64632), b: GeoPoint(-26.80366, -48.64615), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-26.80418, -48.64692), b: GeoPoint(-26.80432, -48.64675), widthMeters: 8.0),
      TrackLine(a: GeoPoint(-26.80412, -48.64782), b: GeoPoint(-26.80426, -48.64765), widthMeters: 8.0),
    ],
    createdAt: _dt(2026, 4, 8, 10, 0),
    updatedAt: _dt(2026, 4, 8, 10, 0),
  ));
}

Future<void> _seedSessions() async {
  // ── Sessão 1: Kartódromo Ayrton Senna (Granja Viana) — 12 abr 2026 ───────
  // 6 setores, 12 voltas, best 55.210 (V7)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessao1,
    trackId: _idGranjaViana,
    trackName: 'Kartódromo Ayrton Senna',
    date: _dt(2026, 4, 12, 14, 32),
    bestLapMs: 55210,
    createdAt: _dt(2026, 4, 12, 15, 20),
    laps: const [
      LapResult(lapMs: 61480, sectors: [11820, 10940, 9650, 10280, 9840, 8950]),
      LapResult(lapMs: 58920, sectors: [11340, 10480, 9240, 9880, 9420, 8560]),
      LapResult(lapMs: 57340, sectors: [11040, 10190, 8980, 9620, 9160, 8350]),
      LapResult(lapMs: 56280, sectors: [10820, 9980, 8780, 9430, 8980, 8290]),
      LapResult(lapMs: 55870, sectors: [10720, 9880, 8680, 9330, 8890, 8370]),
      LapResult(lapMs: 55540, sectors: [10660, 9820, 8620, 9270, 8830, 8340]),
      LapResult(lapMs: 55210, sectors: [10590, 9760, 8570, 9210, 8780, 8300]),
      LapResult(lapMs: 55380, sectors: [10620, 9790, 8600, 9240, 8810, 8320]),
      LapResult(lapMs: 55620, sectors: [10670, 9840, 8640, 9280, 8850, 8340]),
      LapResult(lapMs: 56040, sectors: [10750, 9920, 8710, 9360, 8920, 8380]),
      LapResult(lapMs: 55780, sectors: [10700, 9860, 8660, 9300, 8870, 8390]),
      LapResult(lapMs: 55450, sectors: [10640, 9800, 8610, 9240, 8830, 8330]),
    ],
  ));

  // ── Sessão 2: Speed Park Interlagos — 03 abr 2026 ────────────────────────
  // 7 setores, 14 voltas, best 1:08.540 (V8)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessao2,
    trackId: _idInterlagos,
    trackName: 'Speed Park Interlagos',
    date: _dt(2026, 4, 3, 9, 15),
    bestLapMs: 68540,
    createdAt: _dt(2026, 4, 3, 10, 48),
    laps: const [
      LapResult(lapMs: 75620, sectors: [11840, 10980, 9820, 10650, 11230, 10940, 10160]),
      LapResult(lapMs: 72880, sectors: [11420, 10580, 9460, 10270, 10840, 10540, 9770]),
      LapResult(lapMs: 71240, sectors: [11160, 10340, 9250, 10060, 10620, 10320, 9490]),
      LapResult(lapMs: 70180, sectors: [10990, 10180, 9120, 9900, 10460, 10160, 9370]),
      LapResult(lapMs: 69620, sectors: [10900, 10090, 9050, 9820, 10380, 10080, 9300]),
      LapResult(lapMs: 69140, sectors: [10830, 10020, 8990, 9750, 10310, 10010, 9230]),
      LapResult(lapMs: 68820, sectors: [10780, 9970, 8950, 9700, 10260, 9960, 9200]),
      LapResult(lapMs: 68540, sectors: [10730, 9920, 8910, 9650, 10210, 9910, 9210]),
      LapResult(lapMs: 68710, sectors: [10760, 9950, 8930, 9680, 10240, 9940, 9210]),
      LapResult(lapMs: 68980, sectors: [10800, 9990, 8960, 9720, 10280, 9980, 9250]),
      LapResult(lapMs: 69320, sectors: [10850, 10040, 9000, 9770, 10330, 10030, 9300]),
      LapResult(lapMs: 69080, sectors: [10810, 10000, 8970, 9730, 10290, 9990, 9280]),
      LapResult(lapMs: 68780, sectors: [10770, 9960, 8940, 9690, 10250, 9950, 9220]),
      LapResult(lapMs: 68620, sectors: [10740, 9930, 8920, 9660, 10220, 9920, 9230]),
    ],
  ));

  // ── Sessão 3: Curitiba Internacional — 28 mar 2026 ───────────────────────
  // 6 setores, 13 voltas, best 53.180 (V7)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessao3,
    trackId: _idCuritiba,
    trackName: 'Kartódromo Internacional de Curitiba',
    date: _dt(2026, 3, 28, 16, 48),
    bestLapMs: 53180,
    createdAt: _dt(2026, 3, 28, 17, 55),
    laps: const [
      LapResult(lapMs: 59640, sectors: [10820, 9750, 9280, 10140, 9960, 9690]),
      LapResult(lapMs: 57180, sectors: [10390, 9360, 8880, 9720, 9540, 9290]),
      LapResult(lapMs: 55820, sectors: [10140, 9130, 8660, 9490, 9310, 9090]),
      LapResult(lapMs: 54620, sectors: [9920, 8930, 8480, 9270, 9090, 8930]),
      LapResult(lapMs: 53980, sectors: [9800, 8820, 8370, 9160, 8980, 8850]),
      LapResult(lapMs: 53480, sectors: [9710, 8740, 8300, 9080, 8900, 8750]),
      LapResult(lapMs: 53180, sectors: [9650, 8690, 8250, 9030, 8850, 8710]),
      LapResult(lapMs: 53340, sectors: [9680, 8710, 8270, 9050, 8870, 8760]),
      LapResult(lapMs: 53620, sectors: [9720, 8750, 8300, 9090, 8910, 8850]),
      LapResult(lapMs: 53980, sectors: [9790, 8820, 8360, 9160, 8980, 8870]),
      LapResult(lapMs: 54240, sectors: [9840, 8870, 8400, 9210, 9030, 8890]),
      LapResult(lapMs: 53860, sectors: [9770, 8800, 8340, 9140, 8960, 8850]),
      LapResult(lapMs: 53480, sectors: [9710, 8740, 8290, 9080, 8900, 8760]),
    ],
  ));

  // ── Sessão 4: Kartódromo de Cascavel — 15 mar 2026 ───────────────────────
  // 8 setores, 11 voltas, best 1:03.840 (V6)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessao4,
    trackId: _idCascavel,
    trackName: 'Kartódromo de Cascavel',
    date: _dt(2026, 3, 15, 11, 5),
    bestLapMs: 63840,
    createdAt: _dt(2026, 3, 15, 12, 0),
    laps: const [
      LapResult(lapMs: 70280, sectors: [9840, 8920, 8450, 7980, 8760, 9120, 8640, 8570]),
      LapResult(lapMs: 67540, sectors: [9460, 8580, 8110, 7660, 8430, 8780, 8310, 8210]),
      LapResult(lapMs: 65820, sectors: [9210, 8350, 7880, 7440, 8200, 8540, 8080, 8120]),
      LapResult(lapMs: 64780, sectors: [9070, 8220, 7760, 7320, 8070, 8410, 7950, 7980]),
      LapResult(lapMs: 64220, sectors: [8990, 8140, 7690, 7250, 8000, 8340, 7880, 7920]),
      LapResult(lapMs: 63840, sectors: [8930, 8090, 7640, 7200, 7950, 8290, 7840, 7900]),
      LapResult(lapMs: 64020, sectors: [8960, 8110, 7660, 7220, 7970, 8310, 7860, 7930]),
      LapResult(lapMs: 64380, sectors: [9010, 8160, 7700, 7260, 8020, 8360, 7900, 7970]),
      LapResult(lapMs: 64720, sectors: [9060, 8210, 7750, 7300, 8060, 8400, 7940, 8000]),
      LapResult(lapMs: 64180, sectors: [8980, 8130, 7680, 7240, 7980, 8320, 7870, 7980]),
      LapResult(lapMs: 63980, sectors: [8950, 8100, 7650, 7210, 7960, 8300, 7850, 7960]),
    ],
  ));

  // ── Sessão 5: Kartódromo Adilson Pinheiro (Goiânia) — 02 mar 2026 ────────
  // 7 setores, 15 voltas, best 57.620 (V9)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessao5,
    trackId: _idGoiania,
    trackName: 'Kartódromo Adilson Pinheiro',
    date: _dt(2026, 3, 2, 8, 20),
    bestLapMs: 57620,
    createdAt: _dt(2026, 3, 2, 9, 45),
    laps: const [
      LapResult(lapMs: 64340, sectors: [10120, 9340, 8760, 9280, 8850, 9420, 8570]),
      LapResult(lapMs: 62180, sectors: [9780, 9020, 8460, 8960, 8540, 9100, 8320]),
      LapResult(lapMs: 60840, sectors: [9570, 8820, 8270, 8760, 8350, 8900, 8170]),
      LapResult(lapMs: 59720, sectors: [9390, 8660, 8110, 8600, 8200, 8740, 8020]),
      LapResult(lapMs: 59040, sectors: [9280, 8560, 8010, 8490, 8100, 8630, 7970]),
      LapResult(lapMs: 58480, sectors: [9190, 8470, 7940, 8410, 8020, 8550, 7900]),
      LapResult(lapMs: 58020, sectors: [9120, 8400, 7880, 8350, 7960, 8490, 7820]),
      LapResult(lapMs: 57780, sectors: [9080, 8360, 7850, 8310, 7920, 8450, 7810]),
      LapResult(lapMs: 57620, sectors: [9050, 8330, 7820, 8280, 7900, 8420, 7820]),
      LapResult(lapMs: 57740, sectors: [9070, 8350, 7840, 8300, 7920, 8440, 7820]),
      LapResult(lapMs: 57960, sectors: [9110, 8390, 7870, 8330, 7950, 8470, 7840]),
      LapResult(lapMs: 58280, sectors: [9160, 8440, 7910, 8380, 7990, 8520, 7880]),
      LapResult(lapMs: 58020, sectors: [9120, 8400, 7880, 8350, 7960, 8490, 7820]),
      LapResult(lapMs: 57780, sectors: [9080, 8360, 7850, 8310, 7920, 8450, 7810]),
      LapResult(lapMs: 57640, sectors: [9060, 8340, 7830, 8290, 7910, 8430, 7780]),
    ],
  ));

  // ── Sessão 6: Kartódromo Minas Gerais (BH) — 18 fev 2026 ─────────────────
  // 6 setores, 10 voltas, best 49.380 (V5)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessao6,
    trackId: _idBH,
    trackName: 'Kartódromo Minas Gerais',
    date: _dt(2026, 2, 18, 15, 0),
    bestLapMs: 49380,
    createdAt: _dt(2026, 2, 18, 15, 52),
    laps: const [
      LapResult(lapMs: 54680, sectors: [10120, 9240, 8660, 9180, 8850, 8630]),
      LapResult(lapMs: 52340, sectors: [9700, 8860, 8300, 8820, 8490, 8170]),
      LapResult(lapMs: 51020, sectors: [9450, 8640, 8090, 8600, 8270, 7970]),
      LapResult(lapMs: 50180, sectors: [9310, 8510, 7970, 8470, 8150, 7770]),
      LapResult(lapMs: 49380, sectors: [9160, 8380, 7840, 8330, 8020, 7650]),
      LapResult(lapMs: 49580, sectors: [9200, 8410, 7870, 8360, 8050, 7690]),
      LapResult(lapMs: 49820, sectors: [9240, 8450, 7900, 8400, 8090, 7740]),
      LapResult(lapMs: 50140, sectors: [9300, 8500, 7950, 8450, 8140, 7800]),
      LapResult(lapMs: 49860, sectors: [9250, 8460, 7910, 8410, 8100, 7730]),
      LapResult(lapMs: 49540, sectors: [9190, 8400, 7860, 8350, 8040, 7700]),
    ],
  ));

  // ── Sessão 7: Kartódromo de Londrina — 05 fev 2026 ───────────────────────
  // 6 setores, 12 voltas, best 51.740 (V6)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessao7,
    trackId: _idLondrina,
    trackName: 'Kartódromo de Londrina',
    date: _dt(2026, 2, 5, 9, 40),
    bestLapMs: 51740,
    createdAt: _dt(2026, 2, 5, 10, 42),
    laps: const [
      LapResult(lapMs: 57480, sectors: [10580, 9640, 9020, 9580, 9280, 9380]),
      LapResult(lapMs: 55120, sectors: [10160, 9260, 8660, 9200, 8900, 8940]),
      LapResult(lapMs: 53760, sectors: [9900, 9020, 8440, 8960, 8680, 8760]),
      LapResult(lapMs: 52840, sectors: [9730, 8870, 8300, 8820, 8540, 8580]),
      LapResult(lapMs: 52280, sectors: [9640, 8790, 8230, 8740, 8470, 8410]),
      LapResult(lapMs: 51740, sectors: [9540, 8700, 8140, 8650, 8380, 8330]),
      LapResult(lapMs: 51920, sectors: [9570, 8720, 8160, 8670, 8400, 8400]),
      LapResult(lapMs: 52180, sectors: [9610, 8760, 8190, 8710, 8440, 8470]),
      LapResult(lapMs: 52540, sectors: [9670, 8820, 8240, 8760, 8490, 8560]),
      LapResult(lapMs: 52180, sectors: [9610, 8760, 8190, 8710, 8440, 8470]),
      LapResult(lapMs: 51980, sectors: [9580, 8730, 8170, 8680, 8410, 8430]),
      LapResult(lapMs: 51820, sectors: [9550, 8710, 8150, 8660, 8390, 8360]),
    ],
  ));

  // ── Sessão 8: Kartódromo Beto Carrero (Penha/SC) — 22 jan 2026 ───────────
  // 7 setores, 13 voltas, best 1:01.580 (V7)
  await RaceSessionRepository().save(RaceSessionRecord(
    id: _idSessao8,
    trackId: _idBetoCarrero,
    trackName: 'Kartódromo Beto Carrero',
    date: _dt(2026, 1, 22, 14, 10),
    bestLapMs: 61580,
    createdAt: _dt(2026, 1, 22, 15, 28),
    laps: const [
      LapResult(lapMs: 68420, sectors: [10840, 9920, 9380, 9740, 9580, 9960, 9000]),
      LapResult(lapMs: 65780, sectors: [10430, 9540, 9020, 9370, 9220, 9580, 8620]),
      LapResult(lapMs: 64120, sectors: [10180, 9310, 8800, 9140, 8990, 9350, 8350]),
      LapResult(lapMs: 63180, sectors: [10030, 9170, 8670, 9000, 8850, 9210, 8250]),
      LapResult(lapMs: 62540, sectors: [9930, 9080, 8590, 8910, 8760, 9120, 8150]),
      LapResult(lapMs: 61960, sectors: [9830, 8990, 8510, 8830, 8680, 9040, 8080]),
      LapResult(lapMs: 61580, sectors: [9770, 8940, 8460, 8770, 8630, 8980, 8030]),
      LapResult(lapMs: 61740, sectors: [9800, 8960, 8480, 8790, 8650, 9000, 8060]),
      LapResult(lapMs: 62020, sectors: [9840, 9000, 8510, 8830, 8690, 9040, 8110]),
      LapResult(lapMs: 62380, sectors: [9890, 9050, 8560, 8880, 8740, 9090, 8170]),
      LapResult(lapMs: 62080, sectors: [9850, 9010, 8520, 8840, 8700, 9050, 8110]),
      LapResult(lapMs: 61780, sectors: [9810, 8970, 8490, 8810, 8660, 9010, 8030]),
      LapResult(lapMs: 61620, sectors: [9780, 8950, 8470, 8790, 8640, 8990, 8000]),
    ],
  ));
}
