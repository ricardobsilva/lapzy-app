import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gps_diagnostics.dart';
import '../services/gps_diagnostics_service.dart';
import '../services/gps_source.dart';
import '../services/usb_gps_channel.dart';
import '../widgets/pressable.dart';

const _kBg = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kDivider = Color(0xFF1A1A1A);

const _kGreen = Color(0xFF00E676);
const _kYellow = Color(0xFFFFD600);
const _kOrange = Color(0xFFFF9500);
const _kRed = Color(0xFFFF3B30);

class GpsDiagnosticsScreen extends StatefulWidget {
  final GpsDiagnosticsService? service;

  const GpsDiagnosticsScreen({super.key, this.service});

  @override
  State<GpsDiagnosticsScreen> createState() => _GpsDiagnosticsScreenState();
}

class _GpsDiagnosticsScreenState extends State<GpsDiagnosticsScreen> {
  late final GpsDiagnosticsService _service;
  late GpsDiagnosticsSnapshot _snap;
  StreamSubscription<GpsDiagnosticsSnapshot>? _sub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GpsDiagnosticsService.instance;
    _snap = _service.current;
    _sub = _service.stream.listen((snap) {
      if (mounted) setState(() => _snap = snap);
    });
    // Tick every second to refresh elapsed times
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DiagTopBar(snap: _snap),
            const Divider(color: _kDivider, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StateSection(snap: _snap),
                    const Divider(color: _kDivider, height: 1),
                    _PositionSection(snap: _snap),
                    if (_snap.sourceType == GpsConnectionType.usb ||
                        _snap.sourceType == GpsConnectionType.bluetooth) ...[
                      const Divider(color: _kDivider, height: 1),
                      _NmeaSection(snap: _snap),
                    ],
                    if (_snap.sourceType == GpsConnectionType.usb) ...[
                      const Divider(color: _kDivider, height: 1),
                      _UsbSerialSection(snap: _snap),
                    ],
                    const Divider(color: _kDivider, height: 1),
                    _EventsSection(snap: _snap),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TOP BAR ───────────────────────────────────────────────────────────────────

class _DiagTopBar extends StatelessWidget {
  final GpsDiagnosticsSnapshot snap;

  const _DiagTopBar({required this.snap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Pressable(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.white.withAlpha(153),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'DIAGNÓSTICO GPS',
              style: GoogleFonts.rajdhani(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          _SourceBadge(snap: snap),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final GpsDiagnosticsSnapshot snap;

  const _SourceBadge({required this.snap});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (snap.sourceType) {
      GpsConnectionType.internal => ('INT', _kGreen),
      GpsConnectionType.bluetooth => ('BT', const Color(0xFF00B0FF)),
      GpsConnectionType.usb => ('USB', _kYellow),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(100), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── STATE SECTION ─────────────────────────────────────────────────────────────

class _StateSection extends StatelessWidget {
  final GpsDiagnosticsSnapshot snap;

  const _StateSection({required this.snap});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _stateDisplay(snap.fixState);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            snap.sourceName,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              color: Colors.white.withAlpha(115),
            ),
          ),
        ],
      ),
    );
  }

  static (String, Color) _stateDisplay(GpsFixState state) => switch (state) {
        GpsFixState.idle => ('INATIVO', Colors.white.withAlpha(89)),
        GpsFixState.connecting => ('CONECTANDO', _kOrange),
        GpsFixState.receiving => ('RECEBENDO', _kYellow),
        GpsFixState.fixAcquired => ('FIX ADQUIRIDO', _kGreen),
        GpsFixState.error => ('ERRO', _kRed),
        GpsFixState.done => ('DESCONECTADO', _kRed),
      };
}

// ── POSITION SECTION ──────────────────────────────────────────────────────────

class _PositionSection extends StatelessWidget {
  final GpsDiagnosticsSnapshot snap;

  const _PositionSection({required this.snap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeSinceLast = snap.lastPositionWallTime != null
        ? now.difference(snap.lastPositionWallTime!).inSeconds
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'POSIÇÃO'),
        _DiagRow(
          label: 'Latitude',
          value: snap.lastLat != null
              ? snap.lastLat!.toStringAsFixed(7)
              : '—',
        ),
        _DiagRow(
          label: 'Longitude',
          value: snap.lastLng != null
              ? snap.lastLng!.toStringAsFixed(7)
              : '—',
        ),
        _DiagRow(
          label: 'Precisão',
          value: snap.lastAccuracyM != null
              ? '${snap.lastAccuracyM!.toStringAsFixed(1)} m'
              : '—',
        ),
        _DiagRow(
          label: 'Velocidade',
          value: snap.lastSpeedKmh != null
              ? '${snap.lastSpeedKmh!.toStringAsFixed(1)} km/h'
              : '—',
        ),
        _DiagRow(
          label: 'Bearing',
          value: snap.lastBearing != null
              ? '${snap.lastBearing!.toStringAsFixed(1)}°'
              : '—',
        ),
        _DiagRow(
          label: 'Hz instantâneo',
          value: snap.hzInstantaneous != null
              ? '${snap.hzInstantaneous!.toStringAsFixed(2)} Hz'
              : '—',
        ),
        _DiagRow(
          label: 'Hz médio (10p)',
          value: snap.hzRollingAvg != null
              ? '${snap.hzRollingAvg!.toStringAsFixed(2)} Hz'
              : '—',
        ),
        _DiagRow(
          label: 'Última posição',
          value: timeSinceLast != null ? '${timeSinceLast}s atrás' : '—',
          valueColor: timeSinceLast != null && timeSinceLast > 5
              ? _kRed
              : null,
        ),
        _DiagRow(
          label: 'Timestamp GPS',
          value: snap.lastPositionGpsTime != null
              ? _formatTime(snap.lastPositionGpsTime!)
              : '—',
        ),
      ],
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }
}

// ── NMEA SECTION ──────────────────────────────────────────────────────────────

class _NmeaSection extends StatelessWidget {
  final GpsDiagnosticsSnapshot snap;

  const _NmeaSection({required this.snap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'NMEA'),
        _DiagRow(
          label: 'Linhas recebidas',
          value: '${snap.nmeaReceived}',
        ),
        _DiagRow(
          label: 'Descartadas',
          value: '${snap.nmeaDiscarded}',
          valueColor: snap.nmeaDiscarded > 0 ? _kYellow : null,
        ),
        _DiagRow(
          label: 'Linhas/seg',
          value: snap.nmeaLinesPerSec != null
              ? snap.nmeaLinesPerSec!.toStringAsFixed(1)
              : '—',
        ),
        _DiagRow(
          label: 'Status RMC',
          value: snap.lastRmcStatus ?? '—',
          valueColor: snap.lastRmcStatus == 'A' ? _kGreen : null,
        ),
        if (snap.lastGga != null) ...[
          _DiagRow(
            label: 'Fix quality',
            value: _ggaFixLabel(snap.lastGga!.fixQuality),
            valueColor:
                snap.lastGga!.fixQuality > 0 ? _kGreen : _kRed,
          ),
          _DiagRow(
            label: 'Satélites',
            value: '${snap.lastGga!.satellites}',
          ),
          _DiagRow(
            label: 'HDOP',
            value: snap.lastGga!.hdop != null
                ? snap.lastGga!.hdop!.toStringAsFixed(2)
                : '—',
          ),
        ],
        const SizedBox(height: 8),
        _NmeaLog(lines: snap.recentNmea),
      ],
    );
  }

  static String _ggaFixLabel(int quality) => switch (quality) {
        0 => '0 (sem fix)',
        1 => '1 (GPS)',
        2 => '2 (DGPS)',
        _ => '$quality',
      };
}

class _NmeaLog extends StatelessWidget {
  final List<NmeaLineDiag> lines;

  const _NmeaLog({required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Text(
          'Nenhuma linha NMEA recebida',
          style: GoogleFonts.spaceMono(
            fontSize: 10,
            color: Colors.white.withAlpha(71),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.reversed.map((line) => _NmeaLogLine(line: line)).toList(),
      ),
    );
  }
}

class _NmeaLogLine extends StatelessWidget {
  final NmeaLineDiag line;

  const _NmeaLogLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final color = line.valid
        ? _kGreen
        : line.discardReason != null
            ? _kRed
            : Colors.white.withAlpha(89);

    final display = line.raw.length > 60
        ? '${line.raw.substring(0, 60)}…'
        : line.raw;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        display,
        style: GoogleFonts.spaceMono(
          fontSize: 9,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── EVENTS SECTION ────────────────────────────────────────────────────────────

class _EventsSection extends StatelessWidget {
  final GpsDiagnosticsSnapshot snap;

  const _EventsSection({required this.snap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'LINHA DO TEMPO'),
        _DiagRow(
          label: 'Subscription iniciada',
          value: snap.subscriptionStartedAt != null
              ? _elapsed(now, snap.subscriptionStartedAt!)
              : '—',
        ),
        _DiagRow(
          label: 'Primeiro dado bruto',
          value: snap.firstRawDataAt != null
              ? _elapsed(now, snap.firstRawDataAt!)
              : '—',
        ),
        _DiagRow(
          label: 'Primeiro fix válido',
          value: snap.firstValidPositionAt != null
              ? _elapsed(now, snap.firstValidPositionAt!)
              : '—',
          valueColor: snap.firstValidPositionAt != null ? _kGreen : null,
        ),
        if (snap.subscriptionStartedAt != null &&
            snap.firstValidPositionAt != null)
          _DiagRow(
            label: 'TTFF',
            value: _duration(
              snap.firstValidPositionAt!
                  .difference(snap.subscriptionStartedAt!),
            ),
            valueColor: _kGreen,
          ),
      ],
    );
  }

  static String _elapsed(DateTime now, DateTime then) {
    final diff = now.difference(then);
    if (diff.inSeconds < 60) return 'há ${diff.inSeconds}s';
    return 'há ${diff.inMinutes}m ${diff.inSeconds % 60}s';
  }

  static String _duration(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    return '${(d.inMilliseconds / 1000.0).toStringAsFixed(1)}s';
  }
}

// ── USB SERIAL SECTION ────────────────────────────────────────────────────────

class _UsbSerialSection extends StatelessWidget {
  final GpsDiagnosticsSnapshot snap;

  const _UsbSerialSection({required this.snap});

  @override
  Widget build(BuildContext context) {
    final bytesOk = snap.usbRawBytesTotal > 0;
    final threadProblem =
        snap.usbSerialState == 'reading' && snap.usbSerialThreadAlive == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'SERIAL USB'),
        _DiagRow(
          label: 'Estado',
          value: snap.usbSerialState ?? '—',
        ),
        _DiagRow(
          label: 'Baud rate',
          value: '${snap.usbBaudRate}',
        ),
        _DiagRow(
          label: 'Thread viva',
          value: snap.usbSerialThreadAlive == null
              ? '—'
              : snap.usbSerialThreadAlive!
                  ? 'sim'
                  : 'não',
          valueColor: threadProblem ? _kRed : null,
        ),
        _DiagRow(
          label: 'Bytes RX total',
          value: '${snap.usbRawBytesTotal}',
          valueColor: bytesOk ? _kGreen : _kRed,
        ),
        _DiagRow(
          label: 'Bytes RX/s',
          value: snap.usbRawBytesPerSec.toStringAsFixed(1),
        ),
        _DiagRow(
          label: 'Endpoint',
          value: snap.usbEndpointInfo ?? '—',
        ),
        _DiagRow(
          label: 'Último erro',
          value: snap.usbLastSerialError ?? '—',
          valueColor: snap.usbLastSerialError != null ? _kRed : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [9600, 38400, 115200].map((baud) {
              final isActive = snap.usbBaudRate == baud;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _BaudButton(
                  baud: baud,
                  isActive: isActive,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _BaudButton extends StatelessWidget {
  final int baud;
  final bool isActive;

  const _BaudButton({required this.baud, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _kYellow : Colors.white.withAlpha(89);
    return Pressable(
      onTap: () => UsbGpsChannel().setBaudRate(baud),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _kYellow.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withAlpha(120), width: 1),
        ),
        child: Text(
          '$baud',
          style: GoogleFonts.spaceMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: GoogleFonts.rajdhani(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: Colors.white.withAlpha(71),
        ),
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DiagRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              color: Colors.white.withAlpha(115),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
