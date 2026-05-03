// Seed de dados realistas para visualização em tela.
// Cria 3 pistas brasileiras reais (GPS aproximado) e 3 sessões de 12 voltas
// com tempos realistas de kart.
//
// Uso:
//   flutter test integration_test/seed_realistic_data_test.dart -d RXCXB09MSRN
//
// Idempotente: pode ser executado múltiplas vezes sem duplicar dados,
// pois usa IDs fixos e o repositório faz upsert.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapzy/main.dart' as app;
import 'package:lapzy/models/race_session.dart';
import 'package:lapzy/models/race_session_record.dart';
import 'package:lapzy/models/track.dart';
import 'package:lapzy/repositories/race_session_repository.dart';
import 'package:lapzy/repositories/track_repository.dart';

// ── IDs fixos para idempotência ───────────────────────────────────────────────

const _idGranjaViana   = 'a1b2c3d4-0001-4000-8000-seed00000001';
const _idSpeedPark     = 'a1b2c3d4-0002-4000-8000-seed00000002';
const _idCuritiba      = 'a1b2c3d4-0003-4000-8000-seed00000003';

const _idSessaoGranja  = 'b2c3d4e5-0001-4000-8000-seed00000001';
const _idSessaoSpeed   = 'b2c3d4e5-0002-4000-8000-seed00000002';
const _idSessaoCurit   = 'b2c3d4e5-0003-4000-8000-seed00000003';

// ── PISTAS ────────────────────────────────────────────────────────────────────

/// Kartódromo Ayrton Senna — Granja Viana, Cotia/SP
/// Pista com 3 setores, ~640m por volta. Referência GPS real.
final _granjaViana = Track(
  id: _idGranjaViana,
  name: 'Granja Viana',
  startFinishLine: const TrackLine(
    a: GeoPoint(-23.58972, -46.87115),
    b: GeoPoint(-23.58985, -46.87098),
    widthMeters: 7.0,
  ),
  sectorBoundaries: const [
    // S1→S2: saída da reta dos boxes, entrada no primeiro complexo de curvas
    TrackLine(
      a: GeoPoint(-23.58910, -46.87048),
      b: GeoPoint(-23.58924, -46.87033),
      widthMeters: 7.0,
    ),
    // S2→S3: saída da chicane, reta de fundo
    TrackLine(
      a: GeoPoint(-23.59018, -46.87182),
      b: GeoPoint(-23.59031, -46.87167),
      widthMeters: 7.0,
    ),
  ],
  createdAt: DateTime.utc(2026, 3, 10, 9, 0),
  updatedAt: DateTime.utc(2026, 3, 10, 9, 0),
);

/// Kartódromo Speed Park — Itapevi/SP
/// Pista com 2 setores, ~820m por volta. Traçado técnico com chicanes.
final _speedPark = Track(
  id: _idSpeedPark,
  name: 'Speed Park Itapevi',
  startFinishLine: const TrackLine(
    a: GeoPoint(-23.54132, -46.93512),
    b: GeoPoint(-23.54146, -46.93495),
    widthMeters: 8.0,
  ),
  sectorBoundaries: const [
    // S1→S2: metade do circuito, após a curva do lago
    TrackLine(
      a: GeoPoint(-23.54065, -46.93610),
      b: GeoPoint(-23.54080, -46.93593),
      widthMeters: 8.0,
    ),
  ],
  createdAt: DateTime.utc(2026, 3, 22, 10, 30),
  updatedAt: DateTime.utc(2026, 3, 22, 10, 30),
);

/// Kartódromo Internacional de Curitiba — Pinhais/PR
/// Pista com 3 setores, ~1.100m por volta. Referência GPS real.
final _curitiba = Track(
  id: _idCuritiba,
  name: 'Kartódromo Internacional de Curitiba',
  startFinishLine: const TrackLine(
    a: GeoPoint(-25.44887, -49.27588),
    b: GeoPoint(-25.44900, -49.27573),
    widthMeters: 9.0,
  ),
  sectorBoundaries: const [
    // S1→S2: após o complexo da piscina
    TrackLine(
      a: GeoPoint(-25.44820, -49.27678),
      b: GeoPoint(-25.44835, -49.27663),
      widthMeters: 9.0,
    ),
    // S2→S3: reta da volta, antes da última curva
    TrackLine(
      a: GeoPoint(-25.44968, -49.27728),
      b: GeoPoint(-25.44982, -49.27713),
      widthMeters: 9.0,
    ),
  ],
  createdAt: DateTime.utc(2026, 4, 5, 8, 0),
  updatedAt: DateTime.utc(2026, 4, 5, 8, 0),
);

// ── SESSÕES ───────────────────────────────────────────────────────────────────

/// Sessão Granja Viana — 15/04/2026
/// 12 voltas, 3 setores. Melhor volta: 54.890 (V5).
/// Progressão realista: aquecimento → pico → leve degradação → recuperação.
final _sessaoGranja = RaceSessionRecord(
  id: _idSessaoGranja,
  trackId: _idGranjaViana,
  trackName: 'Granja Viana',
  date: DateTime.utc(2026, 4, 15, 13, 0),
  bestLapMs: 54890,
  createdAt: DateTime.utc(2026, 4, 15, 13, 48),
  laps: const [
    // V1 — pneus frios, ritmo cauteloso
    LapResult(lapMs: 59820, sectors: [23200, 20300, 16320]),
    // V2 — aquecimento
    LapResult(lapMs: 57340, sectors: [22240, 19390, 15710]),
    // V3 — entrando no ritmo
    LapResult(lapMs: 56120, sectors: [21790, 18960, 15370]),
    // V4 — consistência crescendo
    LapResult(lapMs: 55480, sectors: [21480, 18730, 15270]),
    // V5 — MELHOR VOLTA
    LapResult(lapMs: 54890, sectors: [21270, 18460, 15160]),
    // V6 — levemente acima do best
    LapResult(lapMs: 54920, sectors: [21280, 18460, 15180]),
    // V7 — pneus começando a cair
    LapResult(lapMs: 55100, sectors: [21350, 18510, 15240]),
    // V8 — queda de ritmo
    LapResult(lapMs: 55640, sectors: [21540, 18780, 15320]),
    // V9 — degradação continuando
    LapResult(lapMs: 55980, sectors: [21680, 18900, 15400]),
    // V10 — fundo do poço
    LapResult(lapMs: 56230, sectors: [21790, 19010, 15430]),
    // V11 — recuperação
    LapResult(lapMs: 55870, sectors: [21640, 18860, 15370]),
    // V12 — final forte
    LapResult(lapMs: 55420, sectors: [21470, 18700, 15250]),
  ],
);

/// Sessão Speed Park — 20/04/2026
/// 12 voltas, 2 setores. Melhor volta: 1:04.420 (V5).
/// Pista técnica — consistência é chave.
final _sessaoSpeedPark = RaceSessionRecord(
  id: _idSessaoSpeed,
  trackId: _idSpeedPark,
  trackName: 'Speed Park Itapevi',
  date: DateTime.utc(2026, 4, 20, 15, 30),
  bestLapMs: 64420,
  createdAt: DateTime.utc(2026, 4, 20, 16, 22),
  laps: const [
    // V1 — saída lenta, pista desconhecida no início
    LapResult(lapMs: 68450, sectors: [33840, 34610]),
    // V2 — melhorando trajetória nas chicanes
    LapResult(lapMs: 66230, sectors: [32740, 33490]),
    // V3 — ritmo chegando
    LapResult(lapMs: 65180, sectors: [32230, 32950]),
    // V4 — acertando a frenagem na curva do lago
    LapResult(lapMs: 64870, sectors: [32080, 32790]),
    // V5 — MELHOR VOLTA
    LapResult(lapMs: 64420, sectors: [31860, 32560]),
    // V6 — levemente acima
    LapResult(lapMs: 64650, sectors: [31970, 32680]),
    // V7 — muito próximo do best
    LapResult(lapMs: 64580, sectors: [31930, 32650]),
    // V8 — pneu traseiro perdendo agarre
    LapResult(lapMs: 65120, sectors: [32200, 32920]),
    // V9 — degradação confirmada
    LapResult(lapMs: 65340, sectors: [32310, 33030]),
    // V10 — ritmo caiu
    LapResult(lapMs: 65780, sectors: [32530, 33250]),
    // V11 — recuperação moderada
    LapResult(lapMs: 65230, sectors: [32260, 32970]),
    // V12 — última volta, empurrando
    LapResult(lapMs: 64960, sectors: [32130, 32830]),
  ],
);

/// Sessão Curitiba — 25/04/2026
/// 12 voltas, 3 setores. Melhor volta: 53.180 (V6).
/// Pista longa — evolução gradual, pico no meio da sessão.
final _sessaoCuritiba = RaceSessionRecord(
  id: _idSessaoCurit,
  trackId: _idCuritiba,
  trackName: 'Kartódromo Internacional de Curitiba',
  date: DateTime.utc(2026, 4, 25, 10, 0),
  bestLapMs: 53180,
  createdAt: DateTime.utc(2026, 4, 25, 10, 52),
  laps: const [
    // V1 — primeiro contato com a pista
    LapResult(lapMs: 58340, sectors: [22450, 20180, 15710]),
    // V2 — aprendendo os pontos de frenagem
    LapResult(lapMs: 56120, sectors: [21600, 19430, 15090]),
    // V3 — entrada na chicane da piscina melhorou
    LapResult(lapMs: 54870, sectors: [21110, 18990, 14770]),
    // V4 — consistência crescente
    LapResult(lapMs: 53980, sectors: [20760, 18690, 14530]),
    // V5 — próximo do best
    LapResult(lapMs: 53420, sectors: [20540, 18430, 14450]),
    // V6 — MELHOR VOLTA
    LapResult(lapMs: 53180, sectors: [20450, 18310, 14420]),
    // V7 — pequena variação
    LapResult(lapMs: 53290, sectors: [20500, 18350, 14440]),
    // V8 — pneus começando a cair
    LapResult(lapMs: 53560, sectors: [20600, 18490, 14470]),
    // V9 — queda de ritmo
    LapResult(lapMs: 53840, sectors: [20710, 18620, 14510]),
    // V10 — degradação
    LapResult(lapMs: 54120, sectors: [20820, 18750, 14550]),
    // V11 — ajuste de trajetória, melhora
    LapResult(lapMs: 53790, sectors: [20680, 18580, 14530]),
    // V12 — última volta empurrada
    LapResult(lapMs: 53450, sectors: [20560, 18440, 14450]),
  ],
);

// ── TESTE ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed: cria pistas e corridas realistas no dispositivo',
      (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // Salva as 3 pistas (upsert — seguro rodar múltiplas vezes)
    await TrackRepository().save(_granjaViana);
    await TrackRepository().save(_speedPark);
    await TrackRepository().save(_curitiba);

    // Salva as 3 sessões de corrida (upsert)
    await RaceSessionRepository().save(_sessaoGranja);
    await RaceSessionRepository().save(_sessaoSpeedPark);
    await RaceSessionRepository().save(_sessaoCuritiba);

    // Verifica que os dados estão presentes
    final tracks = TrackRepository().tracks;
    final sessions = RaceSessionRepository().sessions;

    final hasGranja = tracks.any((t) => t.id == _idGranjaViana);
    final hasSpeed  = tracks.any((t) => t.id == _idSpeedPark);
    final hasCurit  = tracks.any((t) => t.id == _idCuritiba);

    final hasSessaoG = sessions.any((s) => s.id == _idSessaoGranja);
    final hasSessaoS = sessions.any((s) => s.id == _idSessaoSpeed);
    final hasSessaoC = sessions.any((s) => s.id == _idSessaoCurit);

    expect(hasGranja, isTrue,  reason: 'Granja Viana deve estar no storage');
    expect(hasSpeed,  isTrue,  reason: 'Speed Park deve estar no storage');
    expect(hasCurit,  isTrue,  reason: 'Curitiba deve estar no storage');
    expect(hasSessaoG, isTrue, reason: 'Sessão Granja deve estar no storage');
    expect(hasSessaoS, isTrue, reason: 'Sessão Speed Park deve estar no storage');
    expect(hasSessaoC, isTrue, reason: 'Sessão Curitiba deve estar no storage');

    // Valida integridade dos tempos: setores somam a volta
    for (final session in [_sessaoGranja, _sessaoSpeedPark, _sessaoCuritiba]) {
      for (var i = 0; i < session.laps.length; i++) {
        final lap = session.laps[i];
        final sumSectors = lap.sectors.whereType<int>().fold(0, (a, b) => a + b);
        expect(
          sumSectors,
          equals(lap.lapMs),
          reason:
              '${session.trackName} V${i + 1}: setores ($sumSectors) devem somar a volta (${lap.lapMs})',
        );
      }
    }
  });
}
