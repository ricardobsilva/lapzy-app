import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/race_session.dart';
import '../models/track.dart';
import '../services/delta_calculator.dart';
import '../services/lap_detector.dart';

// ── CORES ─────────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF0A0A0A);
const _kGreen = Color(0xFF00E676);
const _kPurple = Color(0xFFBF5AF2);
const _kRed = Color(0xFFFF3B30);
const _kS1 = Color(0xFF00B0FF);
const _kS2 = Color(0xFFFFD600);
const _kS3 = Color(0xFFFF6D00);

const _kBorderWidth = 7.0;

// Número máximo de setores suportados na tela (S1/S2/S3 fixos + extras).
const _kMaxSectors = 3;

// ── TELA PRINCIPAL ────────────────────────────────────────────────────────────

class RaceScreen extends StatefulWidget {
  final Track track;

  /// Threshold de personal record em ms. null = PR desabilitado.
  final int? prThresholdMs;

  /// Fábrica do LapDetector — injetável para testes.
  final LapDetector Function(Track)? detectorFactory;

  const RaceScreen({
    required this.track,
    this.prThresholdMs,
    this.detectorFactory,
    super.key,
  });

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  // ── TIMER ──────────────────────────────────────────────────────────────────
  Timer? _lapTimer;
  int _lapMs = 0;

  // ── SESSÃO ─────────────────────────────────────────────────────────────────
  int _lapNumber = 1;
  int? _bestLapMs;
  int? _deltaMs;
  RaceEventState _eventState = RaceEventState.neutral;
  final List<int?> _currentSectors = List.filled(_kMaxSectors, null);
  final List<LapResult> _completedLaps = [];

  // ── GPS ────────────────────────────────────────────────────────────────────
  late final LapDetector _detector;
  StreamSubscription<LapEvent>? _detectorSub;

  // ── SETOR AGUARDADO (próximo setor a ser completado) ───────────────────────
  int _nextSectorIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    _detector = widget.detectorFactory != null
        ? widget.detectorFactory!(widget.track)
        : LapDetector(track: widget.track);
    _startLapTimer();
    _startDetector();
  }

  @override
  void dispose() {
    _lapTimer?.cancel();
    _detectorSub?.cancel();
    _detector.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── TIMER ──────────────────────────────────────────────────────────────────

  void _startLapTimer() {
    _lapTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() => _lapMs += 50);
    });
  }

  // ── DETECTOR ──────────────────────────────────────────────────────────────

  void _startDetector() {
    _detectorSub = _detector.events.listen(_onLapEvent);
    _detector.start();
  }

  void _onLapEvent(LapEvent event) {
    if (event is LapCrossedEvent) {
      _onLapCompleted();
    } else if (event is SectorCrossedEvent) {
      _onSectorCompleted(event.sectorIndex);
    }
  }

  void _onLapCompleted() {
    final lapMs = _lapMs;
    final result = DeltaCalculator.compute(
      lapMs: lapMs,
      previousBestMs: _bestLapMs,
      prThresholdMs: widget.prThresholdMs,
    );

    setState(() {
      _completedLaps.add(LapResult(
        lapMs: lapMs,
        s1Ms: _currentSectors.isNotEmpty ? _currentSectors[0] : null,
        s2Ms: _currentSectors.length > 1 ? _currentSectors[1] : null,
        s3Ms: _currentSectors.length > 2 ? _currentSectors[2] : null,
      ));
      _bestLapMs = result.newBestLapMs;
      _deltaMs = result.deltaMs;
      _eventState = result.eventState;
      _lapMs = 0;
      _lapNumber++;
      _nextSectorIndex = 0;
      for (int i = 0; i < _kMaxSectors; i++) {
        _currentSectors[i] = null;
      }
    });
  }

  void _onSectorCompleted(int sectorIndex) {
    if (sectorIndex != _nextSectorIndex) return;
    if (sectorIndex >= _kMaxSectors) return;
    setState(() {
      _currentSectors[sectorIndex] = _lapMs;
      _nextSectorIndex++;
    });
  }

  // ── FINALIZAR ──────────────────────────────────────────────────────────────

  Future<void> _confirmEnd() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha(153),
      builder: (ctx) => _EndRaceDialog(onConfirm: () => Navigator.of(ctx).pop(true)),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(_buildSessionResult());
    }
  }

  Map<String, dynamic> _buildSessionResult() {
    return {
      'laps': List<LapResult>.unmodifiable(_completedLaps),
      'bestLapMs': _bestLapMs,
      'track': widget.track,
    };
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LeftColumn(
                  lapNumber: _lapNumber,
                  sectors: List.unmodifiable(_currentSectors),
                  eventState: _eventState,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CenterColumn(
                    lapMs: _lapMs,
                    eventState: _eventState,
                    deltaMs: _deltaMs,
                  ),
                ),
                const SizedBox(width: 12),
                _RightColumn(
                  bestLapMs: _bestLapMs,
                  onEnd: _confirmEnd,
                ),
              ],
            ),
          ),
          // Borda colorida sobreposta
          _EventBorder(eventState: _eventState),
        ],
      ),
    );
  }
}

// ── BORDA DO EVENTO ───────────────────────────────────────────────────────────

class _EventBorder extends StatelessWidget {
  final RaceEventState eventState;

  const _EventBorder({required this.eventState});

  Color? get _color {
    return switch (eventState) {
      RaceEventState.neutral => null,
      RaceEventState.melhorVolta => _kPurple,
      RaceEventState.voltaMelhor => _kGreen,
      RaceEventState.voltaPior => _kRed,
      RaceEventState.personalRecord => _kGreen,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    if (color == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        key: const Key('race_event_border'),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: _kBorderWidth),
        ),
      ),
    );
  }
}

// ── COLUNA ESQUERDA ───────────────────────────────────────────────────────────

class _LeftColumn extends StatelessWidget {
  final int lapNumber;
  final List<int?> sectors;
  final RaceEventState eventState;

  const _LeftColumn({
    required this.lapNumber,
    required this.sectors,
    required this.eventState,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _LapCounter(lapNumber: lapNumber),
          _SectorBadges(sectors: sectors, eventState: eventState),
        ],
      ),
    );
  }
}

class _LapCounter extends StatelessWidget {
  final int lapNumber;

  const _LapCounter({required this.lapNumber});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOLTA',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Colors.white.withAlpha(71),
          ),
        ),
        Text(
          '$lapNumber',
          style: GoogleFonts.rajdhani(
            fontSize: 60,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _SectorBadges extends StatelessWidget {
  final List<int?> sectors;
  final RaceEventState eventState;

  const _SectorBadges({required this.sectors, required this.eventState});

  bool get _isMelhorVolta => eventState == RaceEventState.melhorVolta;

  static const _sectorColors = [_kS1, _kS2, _kS3];
  static const _sectorLabels = ['S1', 'S2', 'S3'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SETORES',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Colors.white.withAlpha(71),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(
            _sectorLabels.length,
            (i) => _SectorBadge(
              label: _sectorLabels[i],
              timeMs: sectors.isNotEmpty && i < sectors.length ? sectors[i] : null,
              color: _isMelhorVolta ? _kPurple : _sectorColors[i],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectorBadge extends StatelessWidget {
  final String label;
  final int? timeMs;
  final Color color;

  const _SectorBadge({
    required this.label,
    required this.timeMs,
    required this.color,
  });

  String get _timeText {
    if (timeMs == null) return '—';
    final s = (timeMs! / 1000).toStringAsFixed(3);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(115), width: 1.5),
      ),
      constraints: const BoxConstraints(minWidth: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: color.withAlpha(191),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _timeText,
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── COLUNA CENTRAL ────────────────────────────────────────────────────────────

class _CenterColumn extends StatelessWidget {
  final int lapMs;
  final RaceEventState eventState;
  final int? deltaMs;

  const _CenterColumn({
    required this.lapMs,
    required this.eventState,
    required this.deltaMs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (eventState == RaceEventState.personalRecord) ...[
          _PrBanner(),
          const SizedBox(height: 8),
        ],
        Text(
          'TEMPO DA VOLTA',
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Colors.white.withAlpha(71),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatMs(lapMs),
          style: GoogleFonts.rajdhani(
            fontSize: 80,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        _DeltaPill(eventState: eventState, deltaMs: deltaMs),
      ],
    );
  }
}

class _PrBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: _kGreen.withAlpha(20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _kGreen.withAlpha(89), width: 1),
      ),
      child: Text(
        'PERSONAL RECORD',
        style: GoogleFonts.rajdhani(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: _kGreen,
        ),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final RaceEventState eventState;
  final int? deltaMs;

  const _DeltaPill({required this.eventState, required this.deltaMs});

  @override
  Widget build(BuildContext context) {
    return switch (eventState) {
      RaceEventState.neutral => const SizedBox(height: 36),
      RaceEventState.melhorVolta => _pill(
          text: 'MELHOR',
          color: _kPurple,
          bgAlpha: 26,
        ),
      RaceEventState.voltaMelhor => _pill(
          text: '▲ +${_formatDelta(deltaMs ?? 0)}',
          color: _kGreen,
          bgAlpha: 26,
        ),
      RaceEventState.voltaPior => _pill(
          text: '▼ −${_formatDelta((-(deltaMs ?? 0)).abs())}',
          color: _kRed,
          bgAlpha: 26,
        ),
      RaceEventState.personalRecord => _pill(
          text: '▲ +${_formatDelta(deltaMs ?? 0)}',
          color: _kGreen,
          bgAlpha: 26,
        ),
    };
  }

  Widget _pill({required String text, required Color color, required int bgAlpha}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(bgAlpha),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.rajdhani(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── COLUNA DIREITA ────────────────────────────────────────────────────────────

class _RightColumn extends StatelessWidget {
  final int? bestLapMs;
  final VoidCallback onEnd;

  const _RightColumn({required this.bestLapMs, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BestLap(bestLapMs: bestLapMs),
          _EndButton(onTap: onEnd),
        ],
      ),
    );
  }
}

class _BestLap extends StatelessWidget {
  final int? bestLapMs;

  const _BestLap({required this.bestLapMs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'MELHOR VOLTA',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Colors.white.withAlpha(71),
          ),
        ),
        Text(
          bestLapMs != null ? _formatMs(bestLapMs!) : '—',
          style: GoogleFonts.rajdhani(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _kPurple,
          ),
        ),
      ],
    );
  }
}

class _EndButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EndButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _kRed.withAlpha(230),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'FINALIZAR',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── DIALOG DE CONFIRMAÇÃO ─────────────────────────────────────────────────────

class _EndRaceDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const _EndRaceDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FINALIZAR CORRIDA?',
              style: GoogleFonts.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A sessão será encerrada.',
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                color: Colors.white.withAlpha(115),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withAlpha(31),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'CONTINUAR',
                          style: GoogleFonts.rajdhani(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white.withAlpha(179),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _kRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'FINALIZAR',
                          style: GoogleFonts.rajdhani(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── UTILS ─────────────────────────────────────────────────────────────────────

String _formatMs(int ms) {
  final m = ms ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final h = ms % 1000;
  return '$m:${s.toString().padLeft(2, '0')}.${h.toString().padLeft(3, '0')}';
}

String _formatDelta(int ms) {
  return (ms / 1000).toStringAsFixed(3);
}
