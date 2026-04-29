import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/race_session.dart';
import '../models/race_session_record.dart';
import '../models/track.dart';
import '../repositories/race_session_repository.dart';
import '../services/delta_calculator.dart';
import '../services/lap_detector.dart';
import 'race_summary_screen.dart';

const _kBg = Color(0xFF0A0A0A);
const _kGreen = Color(0xFF00E676);
const _kPurple = Color(0xFFBF5AF2);
const _kRed = Color(0xFFFF3B30);
const _kS1 = Color(0xFF00B0FF);
const _kS2 = Color(0xFFFFD600);
const _kS3 = Color(0xFFFF6D00);

const _kBorderWidth = 10.0;
const _kFixedSectorColors = [_kS1, _kS2, _kS3];
const _kExtraSectorColors = [
  Color(0xFF1DE9B6), // teal
  Color(0xFFE040FB), // magenta
  Color(0xFFFF4081), // pink
  Color(0xFF40C4FF), // light blue
  Color(0xFFCCFF90), // lime
  Color(0xFFFFD180), // amber
  Color(0xFF82B1FF), // indigo
];

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
  Timer? _lapTimer;
  int _lapMs = 0;
  bool _hasStarted = false;
  int _lapNumber = 1;
  int? _bestLapMs;
  int? _deltaMs;
  RaceEventState _eventState = RaceEventState.neutral;
  late List<int?> _currentSectors;
  final List<LapResult> _completedLaps = [];

  late final LapDetector _detector;
  StreamSubscription<LapEvent>? _detectorSub;

  Timer? _resetBorderTimer;
  int _nextSectorIndex = 0;
  List<Color?> _sectorFeedbackColors = [];
  List<Timer?> _sectorFeedbackTimers = [];

  int get _totalRaceMs =>
      _completedLaps.fold(0, (sum, l) => sum + l.lapMs) +
      (_hasStarted ? _lapMs : 0);

  @override
  void initState() {
    super.initState();
    final sectorCount = widget.track.sectorBoundaries.length;
    _currentSectors = List.filled(sectorCount, null);
    _sectorFeedbackColors = List.filled(sectorCount, null);
    _sectorFeedbackTimers = List.filled(sectorCount, null);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
    _resetBorderTimer?.cancel();
    for (final t in _sectorFeedbackTimers) {
      t?.cancel();
    }
    _detectorSub?.cancel();
    _detector.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startLapTimer() {
    _lapTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && _hasStarted) setState(() => _lapMs += 50);
    });
  }

  void _startDetector() {
    _detectorSub = _detector.events.listen(_onLapEvent);
    _detector.start();
  }

  void _onLapEvent(LapEvent event) {
    if (event is LapCrossedEvent) {
      if (!_hasStarted) {
        setState(() => _hasStarted = true);
      } else {
        _onLapCompleted();
      }
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
        sectors: List<int?>.from(_currentSectors),
      ));
      _bestLapMs = result.newBestLapMs;
      _deltaMs = result.deltaMs;
      _eventState = result.eventState;
      _lapMs = 0;
      _lapNumber++;
      _nextSectorIndex = 0;
      for (int i = 0; i < _currentSectors.length; i++) {
        _currentSectors[i] = null;
        _sectorFeedbackColors[i] = null;
      }
    });

    _cancelSectorFeedbackTimers();

    _resetBorderTimer?.cancel();
    _resetBorderTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _eventState = RaceEventState.neutral);
    });
  }

  void _onSectorCompleted(int sectorIndex) {
    if (!_hasStarted) return;
    if (sectorIndex != _nextSectorIndex) return;
    if (sectorIndex >= _currentSectors.length) return;

    final sectorTime = _lapMs;
    final feedbackColor = _computeSectorFeedback(sectorIndex, sectorTime);

    setState(() {
      _currentSectors[sectorIndex] = sectorTime;
      _nextSectorIndex++;
      _sectorFeedbackColors[sectorIndex] = feedbackColor;
    });

    if (feedbackColor != null) {
      _scheduleSectorFeedbackReset(sectorIndex);
    }
  }

  Color? _computeSectorFeedback(int sectorIndex, int currentTime) {
    if (_completedLaps.isEmpty) return null;
    final prevTime = _prevLapSectorTime(sectorIndex);
    if (prevTime == null) return null;
    if (currentTime < prevTime) return _kGreen;
    if (currentTime > prevTime) return _kRed;
    return null;
  }

  int? _prevLapSectorTime(int sectorIndex) {
    final lap = _completedLaps.last;
    return sectorIndex < lap.sectors.length ? lap.sectors[sectorIndex] : null;
  }

  void _scheduleSectorFeedbackReset(int sectorIndex) {
    _sectorFeedbackTimers[sectorIndex]?.cancel();
    _sectorFeedbackTimers[sectorIndex] = Timer(
      const Duration(seconds: 5),
      () {
        if (mounted) setState(() => _sectorFeedbackColors[sectorIndex] = null);
      },
    );
  }

  void _cancelSectorFeedbackTimers() {
    for (int i = 0; i < _sectorFeedbackTimers.length; i++) {
      _sectorFeedbackTimers[i]?.cancel();
      _sectorFeedbackTimers[i] = null;
    }
  }

  void _endRaceImmediately() {
    unawaited(_saveAndNavigate());
  }

  Future<void> _saveAndNavigate() async {
    final now = DateTime.now();
    final record = RaceSessionRecord(
      id: const Uuid().v4(),
      trackId: widget.track.id,
      trackName: widget.track.name,
      date: now,
      laps: List.unmodifiable(_completedLaps),
      bestLapMs: _bestLapMs,
      createdAt: now,
    );
    await RaceSessionRepository().save(record);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RaceSummaryScreen(
          laps: List.unmodifiable(_completedLaps),
          bestLapMs: _bestLapMs,
          track: widget.track,
        ),
      ),
    );
  }

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
                _LeftColumn(lapNumber: _lapNumber),
                const SizedBox(width: 12),
                Expanded(
                  child: _CenterColumn(
                    lapMs: _lapMs,
                    eventState: _eventState,
                    deltaMs: _deltaMs,
                    sectors: List.unmodifiable(_currentSectors),
                    hasSectors: widget.track.sectorBoundaries.isNotEmpty,
                    sectorFeedbackColors: List.unmodifiable(_sectorFeedbackColors),
                  ),
                ),
                const SizedBox(width: 12),
                _RightColumn(
                  totalRaceMs: _totalRaceMs,
                  hasStarted: _hasStarted,
                  bestLapMs: _bestLapMs,
                  onEnd: _endRaceImmediately,
                ),
              ],
            ),
          ),
          _EventBorder(eventState: _eventState),
        ],
      ),
    );
  }
}

class _EventBorder extends StatefulWidget {
  final RaceEventState eventState;

  const _EventBorder({required this.eventState});

  @override
  State<_EventBorder> createState() => _EventBorderState();
}

class _EventBorderState extends State<_EventBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_EventBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventState != widget.eventState) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.eventState == RaceEventState.personalRecord) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color? get _color {
    return switch (widget.eventState) {
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

    final container = IgnorePointer(
      child: Container(
        key: const Key('race_event_border'),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: _kBorderWidth),
        ),
      ),
    );

    // CA-RACE-004-03: animação de pulso exclusiva do estado Personal Record.
    if (widget.eventState == RaceEventState.personalRecord) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Opacity(
          opacity: _pulseAnim.value,
          child: container,
        ),
      );
    }

    return container;
  }
}

class _LeftColumn extends StatelessWidget {
  final int lapNumber;

  const _LeftColumn({required this.lapNumber});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LapCounter(lapNumber: lapNumber),
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

class _SectorGrid extends StatelessWidget {
  final List<int?> sectors;
  final RaceEventState eventState;
  final List<Color?> sectorFeedbackColors;

  const _SectorGrid({
    required this.sectors,
    required this.eventState,
    required this.sectorFeedbackColors,
  });

  bool get _isMelhorVolta => eventState == RaceEventState.melhorVolta;

  static Color _colorForIndex(int i) {
    if (i < _kFixedSectorColors.length) return _kFixedSectorColors[i];
    return _kExtraSectorColors[
        (i - _kFixedSectorColors.length) % _kExtraSectorColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: List.generate(
        sectors.length,
        (i) => _SectorCell(
          label: 'S${i + 1}',
          timeMs: sectors[i],
          color: _isMelhorVolta ? _kPurple : _colorForIndex(i),
          borderFeedbackColor: sectorFeedbackColors[i],
        ),
      ),
    );
  }
}

class _SectorCell extends StatelessWidget {
  final String label;
  final int? timeMs;
  final Color color;
  final Color? borderFeedbackColor;

  const _SectorCell({
    required this.label,
    required this.timeMs,
    required this.color,
    this.borderFeedbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final filled = timeMs != null;
    final borderColor = borderFeedbackColor ?? (filled ? color.withAlpha(180) : color.withAlpha(60));
    final borderWidth = borderFeedbackColor != null ? 2.5 : (filled ? 2.0 : 1.5);
    return Container(
      key: Key('sector_cell_${label.toLowerCase()}'),
      width: 84,
      height: 78,
      decoration: BoxDecoration(
        color: filled ? color.withAlpha(51) : color.withAlpha(13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: filled ? color : color.withAlpha(120),
            ),
          ),
          if (filled) ...[
            const SizedBox(height: 2),
            Text(
              (timeMs! / 1000).toStringAsFixed(3),
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CenterColumn extends StatelessWidget {
  final int lapMs;
  final RaceEventState eventState;
  final int? deltaMs;
  final List<int?> sectors;
  final bool hasSectors;
  final List<Color?> sectorFeedbackColors;

  const _CenterColumn({
    required this.lapMs,
    required this.eventState,
    required this.deltaMs,
    required this.sectors,
    required this.hasSectors,
    required this.sectorFeedbackColors,
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
          key: const Key('race_lap_time'),
          style: GoogleFonts.rajdhani(
            fontSize: 88,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        _DeltaPill(eventState: eventState, deltaMs: deltaMs),
        if (hasSectors) ...[
          const SizedBox(height: 16),
          _SectorGrid(
            sectors: sectors,
            eventState: eventState,
            sectorFeedbackColors: sectorFeedbackColors,
          ),
        ],
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

class _RightColumn extends StatelessWidget {
  final int totalRaceMs;
  final bool hasStarted;
  final int? bestLapMs;
  final VoidCallback onEnd;

  const _RightColumn({
    required this.totalRaceMs,
    required this.hasStarted,
    required this.bestLapMs,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TotalTime(totalRaceMs: totalRaceMs, hasStarted: hasStarted),
              const SizedBox(height: 16),
              _BestLap(bestLapMs: bestLapMs),
            ],
          ),
          _EndButton(onEnd: onEnd),
        ],
      ),
    );
  }
}

class _TotalTime extends StatelessWidget {
  final int totalRaceMs;
  final bool hasStarted;

  const _TotalTime({required this.totalRaceMs, required this.hasStarted});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'TOTAL',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Colors.white.withAlpha(71),
          ),
        ),
        Text(
          hasStarted ? _formatMs(totalRaceMs) : '—',
          key: const Key('race_total_time'),
          style: GoogleFonts.rajdhani(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white.withAlpha(153),
          ),
        ),
      ],
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

class _EndButton extends StatefulWidget {
  final VoidCallback onEnd;

  const _EndButton({required this.onEnd});

  @override
  State<_EndButton> createState() => _EndButtonState();
}

class _EndButtonState extends State<_EndButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fillCtrl;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _fillCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completed) {
        _completed = true;
        widget.onEnd();
      }
    });
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    super.dispose();
  }

  void _onPressStart(TapDownDetails _) {
    _completed = false;
    _fillCtrl.forward();
  }

  void _onPressEnd(TapUpDetails _) {
    if (!_completed) _fillCtrl.reverse();
  }

  void _onPressCancel() {
    if (!_completed) _fillCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onPressStart,
      onTapUp: _onPressEnd,
      onTapCancel: _onPressCancel,
      child: AnimatedBuilder(
        animation: _fillCtrl,
        builder: (context, _) => Container(
          key: const Key('end_button'),
          width: double.infinity,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kRed.withAlpha(89), width: 1),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: _kRed.withAlpha(51)),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _fillCtrl.value,
                    child: Container(color: _kRed),
                  ),
                ),
              ),
              Positioned.fill(
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
            ],
          ),
        ),
      ),
    );
  }
}


String _formatMs(int ms) {
  final m = ms ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final h = ms % 1000;
  return '$m:${s.toString().padLeft(2, '0')}.${h.toString().padLeft(3, '0')}';
}

String _formatDelta(int ms) {
  return (ms / 1000).toStringAsFixed(3);
}
