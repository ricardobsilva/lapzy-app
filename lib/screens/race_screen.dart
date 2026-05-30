import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../widgets/pressable.dart';

import '../models/race_session.dart';
import '../models/race_session_record.dart';
import '../models/track.dart';
import '../repositories/race_session_repository.dart';
import '../services/delta_calculator.dart';
import '../services/foreground_location_service.dart';
import '../services/gps_source_manager.dart';
import '../services/lap_detector.dart';
import '../services/telemetry_service.dart';
import 'race_summary_screen.dart';

const _kGreen = Color(0xFF00E676);
const _kPurple = Color(0xFFBF5AF2);
const _kRed = Color(0xFFFF3B30);
const _kS1 = Color(0xFF00B0FF);
const _kS2 = Color(0xFFFFD600);
const _kS3 = Color(0xFFFF6D00);

const _kBorderWidth = 10.0;
const _kFixedSectorColors = [_kS1, _kS2, _kS3];

/// Altura reservada para o slot do banner PR — sempre ocupada, banner ou vazio.
/// Garante que o cronômetro não mude de posição ao aparecer/desaparecer o badge.
const _kPrBannerHeight = 22.0;

// ── TEMAS DE COR ──────────────────────────────────────────────────────────────

class _RaceThemeData {
  final Color bg;
  final Color textPrimary;
  final Color textDim;      // valores secundários (total, melhor volta)
  final Color textVeryDim;  // labels de seção (VOLTA, TOTAL, TEMPO DA VOLTA)
  final String name;

  const _RaceThemeData({
    required this.bg,
    required this.textPrimary,
    required this.textDim,
    required this.textVeryDim,
    required this.name,
  });
}

const _kThemeDark = _RaceThemeData(
  bg: Color(0xFF0A0A0A),
  textPrimary: Colors.white,
  textDim: Color(0x99FFFFFF),
  textVeryDim: Color(0x47FFFFFF),
  name: 'ESCURO',
);

/// Fundo azul cobalto saturado — chamativo em condições variadas.
const _kThemeBlue = _RaceThemeData(
  bg: Color(0xFF0E2BA8),
  textPrimary: Colors.white,
  textDim: Color(0xB3FFFFFF),
  textVeryDim: Color(0x80FFFFFF),
  name: 'AZUL',
);

/// Tema claro para sol forte — máximo contraste em pista a céu aberto.
const _kThemeDay = _RaceThemeData(
  bg: Color(0xFFF0F0F0),
  textPrimary: Color(0xFF0D0D0D),
  textDim: Color(0x990D0D0D),
  textVeryDim: Color(0x720D0D0D),
  name: 'DIA',
);

const _kRaceThemes = [_kThemeDark, _kThemeBlue, _kThemeDay];

/// Propaga o tema de cor ativo para todos os sub-widgets sem passagem
/// explícita de parâmetro por toda a árvore.
class _RaceThemeScope extends InheritedWidget {
  final _RaceThemeData theme;

  const _RaceThemeScope({
    required this.theme,
    required super.child,
  });

  static _RaceThemeData of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_RaceThemeScope>()!
        .theme;
  }

  @override
  bool updateShouldNotify(_RaceThemeScope old) => old.theme.name != theme.name;
}
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

  /// Fonte de tempo — injetável para testes. Padrão: DateTime.now.
  final DateTime Function()? clockFactory;

  const RaceScreen({
    required this.track,
    this.prThresholdMs,
    this.detectorFactory,
    this.clockFactory,
    super.key,
  });

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  Timer? _lapTimer;
  DateTime? _lapStartTime;
  bool _hasStarted = false;
  late final DateTime Function() _clock;
  int _lapNumber = 1;
  int? _bestLapMs;
  int? _deltaMs;
  RaceEventState _eventState = RaceEventState.neutral;
  late List<int?> _currentSectors;
  final List<LapResult> _completedLaps = [];

  late final LapDetector _detector;
  StreamSubscription<LapEvent>? _detectorSub;
  StreamSubscription<Position>? _speedSub;
  double? _speedKmh;

  Timer? _resetBorderTimer;
  int _nextSectorIndex = 0;
  int _lapMsAtLastSector = 0;
  List<Color?> _sectorFeedbackColors = [];
  List<Timer?> _sectorFeedbackTimers = [];

  /// Melhor tempo de cada setor na corrida — base para detecção de roxo (novo recorde de setor).
  List<int?> _bestSectorTimes = [];

  late final String _telemetrySessionId;

  int _themeIndex = 0;
  bool _showThemeHint = false;
  Timer? _hintShowTimer;
  Timer? _hintDismissTimer;
  static const _kHintPrefKey = 'race_theme_hint_dismissed';

  /// Tempo decorrido na volta atual em ms, baseado no relógio injetado.
  /// Resolução de ~1ms, sem deriva do timer periódico.
  int get _lapMs =>
      _lapStartTime == null ? 0 : _clock().difference(_lapStartTime!).inMilliseconds;

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
    _bestSectorTimes = List.filled(sectorCount, null);
    _clock = widget.clockFactory ?? DateTime.now;
    _telemetrySessionId = const Uuid().v4();
    final gpsInfo = GpsSourceManager.instance.activeSource.info;
    TelemetryService.instance.startSession(
      sessionId: _telemetrySessionId,
      trackId: widget.track.id,
      trackName: widget.track.name,
      gpsSource: gpsInfo.connectionType.name,
      gpsSourceName: gpsInfo.name,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    unawaited(ForegroundLocationService.start());
    _detector = widget.detectorFactory != null
        ? widget.detectorFactory!(widget.track)
        : LapDetector(
            track: widget.track,
            positionStreamFactory: () =>
                GpsSourceManager.instance.positionStream,
          );
    GpsSourceManager.instance.notifyScreenAttached('RaceScreen');
    _startLapTimer();
    _startDetector();
    _startSpeedListener();
    unawaited(_checkThemeHint());
  }

  void _startSpeedListener() {
    debugPrint('[LAPZY/UI] _startSpeedListener iniciado');
    DateTime? lastSpeedUpdate;
    _speedSub = GpsSourceManager.instance.positionStream.listen((pos) {
      final now = DateTime.now();
      final deltaMs = lastSpeedUpdate != null
          ? now.difference(lastSpeedUpdate!).inMilliseconds
          : null;
      lastSpeedUpdate = now;
      final hz = deltaMs != null && deltaMs > 0
          ? (1000 / deltaMs).toStringAsFixed(2)
          : '?';
      final raw = pos.speed * 3.6;
      final kmh = raw < 0 ? 0.0 : raw;
      debugPrint(
        '[LAPZY/UI] velocidade=${kmh.toStringAsFixed(1)}km/h '
        'Δ=${deltaMs ?? '?'}ms hz=$hz',
      );
      if (mounted) setState(() => _speedKmh = kmh);
    });
  }

  @override
  void dispose() {
    _hintShowTimer?.cancel();
    _hintDismissTimer?.cancel();
    _lapTimer?.cancel();
    _resetBorderTimer?.cancel();
    for (final t in _sectorFeedbackTimers) {
      t?.cancel();
    }
    _speedSub?.cancel();
    _detectorSub?.cancel();
    _detector.dispose();
    GpsSourceManager.instance.notifyScreenDetached('RaceScreen');
    TelemetryService.instance.endSession(note: 'screen_disposed');
    WakelockPlus.disable();
    unawaited(ForegroundLocationService.stop());
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _startLapTimer() {
    // Apenas dispara rebuild — _lapMs é computado do relógio injetado.
    _lapTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && _hasStarted) setState(() {});
    });
  }

  void _startDetector() {
    debugPrint('[LAPZY/UI] _startDetector iniciado — track="${widget.track.name}"');
    _detectorSub = _detector.events.listen(_onLapEvent);
    _detector.start();
  }

  void _onLapEvent(LapEvent event) {
    if (event is LapCrossedEvent) {
      if (!_hasStarted) {
        setState(() {
          // Usa o timestamp GPS interpolado como âncora da volta —
          // evita o drift de até ±2.5s causado por latência de callback.
          _lapStartTime = event.timestamp;
          _hasStarted = true;
        });
      } else {
        _onLapCompleted(event.timestamp, suspect: false);
      }
    } else if (event is LapCrossedSuspectEvent) {
      if (!_hasStarted) {
        setState(() {
          _lapStartTime = event.timestamp;
          _hasStarted = true;
        });
      } else {
        _onLapCompleted(event.timestamp, suspect: true);
      }
    } else if (event is SectorCrossedEvent) {
      _onSectorCompleted(event);
    }
  }

  /// [crossingTime] é o timestamp GPS interpolado do cruzamento da S/C.
  /// [suspect] indica que o LapDetector classificou esta volta como outlier.
  void _onLapCompleted(DateTime crossingTime, {required bool suspect}) {
    // Tempo calculado a partir dos timestamps GPS interpolados —
    // preciso mesmo com GPS a 0.2 Hz (Samsung A35).
    final lapMs = crossingTime.difference(_lapStartTime!).inMilliseconds;
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
      _eventState = suspect ? RaceEventState.neutral : result.eventState;
      _lapStartTime = crossingTime;
      _lapNumber++;
      _nextSectorIndex = 0;
      _lapMsAtLastSector = 0;
      // Atualiza o melhor setor da corrida para a lógica de roxo.
      final justCompleted = _completedLaps.last;
      for (int i = 0; i < justCompleted.sectors.length; i++) {
        final t = justCompleted.sectors[i];
        if (t == null) continue;
        if (_bestSectorTimes[i] == null || t < _bestSectorTimes[i]!) {
          _bestSectorTimes[i] = t;
        }
      }
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

  void _onSectorCompleted(SectorCrossedEvent event) {
    final sectorIndex = event.sectorIndex;
    if (!_hasStarted) return;
    if (sectorIndex != _nextSectorIndex) return;
    if (sectorIndex >= _currentSectors.length) return;

    // Split do setor usando timestamp GPS interpolado, não relógio de parede.
    // Garante que S1+S2+S3 usem a mesma base de tempo que o lapMs final.
    final crossingMs =
        event.timestamp.difference(_lapStartTime!).inMilliseconds;
    final sectorTime = crossingMs - _lapMsAtLastSector;

    // CA-BUG-001-02: rejeita tempos < 1s — indica bug de timestamp ou
    // double-fire que passou pelo cooldown do LapDetector.
    if (sectorTime < 1000) {
      debugPrint(
        '[RaceScreen] Setor $sectorIndex rejeitado (tempo < 1s): ${sectorTime}ms',
      );
      return;
    }

    _lapMsAtLastSector = crossingMs;
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

  /// Feedback de setor comparado à volta anterior:
  /// - Roxo  → melhor setor da corrida até agora (novo recorde de setor)
  /// - Verde → melhor que o mesmo setor na volta anterior
  /// - Vermelho → pior que o mesmo setor na volta anterior
  Color? _computeSectorFeedback(int sectorIndex, int currentTime) {
    if (_completedLaps.isEmpty) return null;
    if (sectorIndex >= _bestSectorTimes.length) return null;

    final prevLap = _completedLaps.last;
    final prevTime =
        sectorIndex < prevLap.sectors.length ? prevLap.sectors[sectorIndex] : null;
    if (prevTime == null) return null;

    final best = _bestSectorTimes[sectorIndex];
    if (best != null && currentTime < best) return _kPurple;
    if (currentTime < prevTime) return _kGreen;
    if (currentTime > prevTime) return _kRed;
    return null;
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

  void _cycleTheme() {
    setState(() {
      _themeIndex = (_themeIndex + 1) % _kRaceThemes.length;
    });
  }

  Future<void> _checkThemeHint() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_kHintPrefKey) ?? false;
    if (!dismissed && mounted) {
      _hintShowTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() => _showThemeHint = true);
          _hintDismissTimer = Timer(const Duration(seconds: 10), () {
            if (mounted) setState(() => _showThemeHint = false);
          });
        }
      });
    }
  }

  Future<void> _dismissThemeHint() async {
    setState(() => _showThemeHint = false);
    _hintDismissTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHintPrefKey, true);
  }

  void _endRaceImmediately() {
    unawaited(_saveAndNavigate());
  }

  Future<void> _saveAndNavigate() async {
    TelemetryService.instance.endSession();
    final now = DateTime.now();
    final gpsSource = GpsSourceManager.instance.activeSource.info;
    final record = RaceSessionRecord(
      id: const Uuid().v4(),
      trackId: widget.track.id,
      trackName: widget.track.name,
      date: now,
      laps: List.unmodifiable(_completedLaps),
      bestLapMs: _bestLapMs,
      createdAt: now,
      gpsSource: gpsSource,
    );
    await RaceSessionRepository().save(record);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RaceSummaryScreen(
          laps: List.unmodifiable(_completedLaps),
          bestLapMs: _bestLapMs,
          track: widget.track,
          gpsSource: gpsSource,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _kRaceThemes[_themeIndex];
    return _RaceThemeScope(
      theme: theme,
      child: Scaffold(
        backgroundColor: theme.bg,
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
                      totalRaceMs: _totalRaceMs,
                      hasStarted: _hasStarted,
                      bestLapMs: _bestLapMs,
                      speedKmh: _speedKmh,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RightColumn(onEnd: _endRaceImmediately),
                ],
              ),
            ),
            _EventBorder(eventState: _eventState),
            Positioned(
              top: 8,
              right: 8,
              child: _ThemeToggleButton(onTap: _cycleTheme),
            ),
            if (_showThemeHint)
              Positioned(
                top: 44,
                right: 8,
                child: _ThemeHint(onDismiss: _dismissThemeHint),
              ),
          ],
        ),
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
    final theme = _RaceThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOLTA',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: theme.textVeryDim,
          ),
        ),
        SizedBox(
          width: 118,
          child: Text(
            '$lapNumber',
            style: GoogleFonts.spaceMono(
              fontSize: 52,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
              height: 1,
            ),
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
      width: 90,
      height: 84,
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
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: filled ? color : color.withAlpha(120),
            ),
          ),
          const SizedBox(height: 2),
          if (filled)
            Text(
              (timeMs! / 1000).toStringAsFixed(3),
              style: GoogleFonts.spaceMono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            )
          else
            // CA-UX-001-04: setor não capturado exibe "—" em vez de vazio.
            Text(
              '—',
              key: Key('sector_cell_dash_${label.toLowerCase()}'),
              style: GoogleFonts.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color.withAlpha(80),
              ),
            ),
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
  final int totalRaceMs;
  final bool hasStarted;
  final int? bestLapMs;
  final double? speedKmh;

  const _CenterColumn({
    required this.lapMs,
    required this.eventState,
    required this.deltaMs,
    required this.sectors,
    required this.hasSectors,
    required this.sectorFeedbackColors,
    required this.totalRaceMs,
    required this.hasStarted,
    required this.bestLapMs,
    required this.speedKmh,
  });

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder + ConstrainedBox garante centralização sem overflow em
    // qualquer tamanho de tela (portrait em testes, landscape no dispositivo).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = _RaceThemeScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: _TotalTime(totalRaceMs: totalRaceMs, hasStarted: hasStarted),
            ),
            const SizedBox(width: 32),
            Flexible(
              child: _BestLap(bestLapMs: bestLapMs),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _kPrBannerHeight,
          child: eventState == RaceEventState.personalRecord
              ? _PrBanner()
              : null,
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SpeedDisplay(speedKmh: speedKmh),
              const SizedBox(width: 24),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TEMPO DA VOLTA',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: theme.textVeryDim,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMs(lapMs),
                    key: const Key('race_lap_time'),
                    style: GoogleFonts.spaceMono(
                      fontSize: 76,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
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

class _SpeedDisplay extends StatelessWidget {
  final double? speedKmh;

  const _SpeedDisplay({required this.speedKmh});

  @override
  Widget build(BuildContext context) {
    final theme = _RaceThemeScope.of(context);
    final value = speedKmh != null ? speedKmh!.toStringAsFixed(0) : '—';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'KM/H',
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: theme.textVeryDim,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 108,
          child: Text(
            value,
            key: const Key('race_speed'),
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceMono(
              fontSize: 52,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
              height: 1,
            ),
          ),
        ),
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
    final (text, color) = switch (eventState) {
      RaceEventState.neutral => (null, null),
      RaceEventState.melhorVolta => ('MELHOR', _kPurple),
      RaceEventState.voltaMelhor => ('▲ +${_formatDelta(deltaMs ?? 0)}', _kGreen),
      RaceEventState.voltaPior => ('▼ −${_formatDelta((-(deltaMs ?? 0)).abs())}', _kRed),
      RaceEventState.personalRecord => ('▲ +${_formatDelta(deltaMs ?? 0)}', _kGreen),
    };

    return SizedBox(
      height: 36,
      child: text == null
          ? const SizedBox.shrink()
          : _pill(text: text, color: color!),
    );
  }

  Widget _pill({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
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
  final VoidCallback onEnd;

  const _RightColumn({required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Align(
        alignment: Alignment.bottomRight,
        child: _EndButton(onEnd: onEnd),
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
    final theme = _RaceThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'TOTAL',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: theme.textVeryDim,
          ),
        ),
        Text(
          hasStarted ? _formatMs(totalRaceMs) : '—',
          key: const Key('race_total_time'),
          style: GoogleFonts.spaceMono(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.textDim,
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
    final theme = _RaceThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'MELHOR VOLTA',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: theme.textVeryDim,
          ),
        ),
        Text(
          bestLapMs != null ? _formatMs(bestLapMs!) : '—',
          style: GoogleFonts.spaceMono(
            fontSize: 18,
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
      duration: const Duration(milliseconds: 2000),
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


// ── THEME TOGGLE ─────────────────────────────────────────────────────────────

class _ThemeToggleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ThemeToggleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = _RaceThemeScope.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        key: const Key('race_theme_toggle'),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.textPrimary.withAlpha(51),
            width: 1.2,
          ),
        ),
        child: Icon(
          Icons.palette_outlined,
          size: 14,
          color: theme.textPrimary.withAlpha(128),
        ),
      ),
    );
  }
}

class _ThemeHint extends StatefulWidget {
  final VoidCallback onDismiss;

  const _ThemeHint({required this.onDismiss});

  @override
  State<_ThemeHint> createState() => _ThemeHintState();
}

class _ThemeHintState extends State<_ThemeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          key: const Key('race_theme_hint'),
          width: 244,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: const Color(0xF0111111),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            border: Border.all(color: Colors.white.withAlpha(35), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOQUE PARA MUDAR O TEMA',
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThemeSwatch(
                    name: _kThemeDark.name,
                    color: _kThemeDark.bg,
                    isLight: false,
                  ),
                  const SizedBox(width: 10),
                  _ThemeSwatch(
                    name: _kThemeBlue.name,
                    color: _kThemeBlue.bg,
                    isLight: false,
                  ),
                  const SizedBox(width: 10),
                  _ThemeSwatch(
                    name: _kThemeDay.name,
                    color: _kThemeDay.bg,
                    isLight: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Text(
                  'NÃO MOSTRAR NOVAMENTE',
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white.withAlpha(128),
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withAlpha(60),
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

class _ThemeSwatch extends StatelessWidget {
  final String name;
  final Color color;
  final bool isLight;

  const _ThemeSwatch({
    required this.name,
    required this.color,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isLight
                  ? Colors.black.withAlpha(80)
                  : Colors.white.withAlpha(80),
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          name,
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: Colors.white.withAlpha(153),
          ),
        ),
      ],
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
