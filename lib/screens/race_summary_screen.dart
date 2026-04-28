import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/race_session.dart';
import '../models/track.dart';

const _kBg = Color(0xFF0A0A0A);
const _kPurple = Color(0xFFBF5AF2);

class RaceSummaryScreen extends StatefulWidget {
  final List<LapResult> laps;
  final int? bestLapMs;
  final Track track;

  const RaceSummaryScreen({
    required this.laps,
    required this.bestLapMs,
    required this.track,
    super.key,
  });

  @override
  State<RaceSummaryScreen> createState() => _RaceSummaryScreenState();
}

class _RaceSummaryScreenState extends State<RaceSummaryScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryHeader(
              track: widget.track,
              bestLapMs: widget.bestLapMs,
              lapCount: widget.laps.length,
            ),
            const Divider(color: Color(0xFF1A1A1A), height: 1),
            Expanded(
              child: _LapList(
                laps: widget.laps,
                bestLapMs: widget.bestLapMs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final Track track;
  final int? bestLapMs;
  final int lapCount;

  const _SummaryHeader({
    required this.track,
    required this.bestLapMs,
    required this.lapCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMO',
            key: const Key('summary_title'),
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Colors.white.withAlpha(71),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            track.name,
            key: const Key('summary_track_name'),
            style: GoogleFonts.rajdhani(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatBlock(
                label: 'MELHOR VOLTA',
                value: bestLapMs != null ? _formatMs(bestLapMs!) : '—',
                color: _kPurple,
                valueKey: const Key('summary_best_lap'),
              ),
              const SizedBox(width: 32),
              _StatBlock(
                label: 'VOLTAS',
                value: '$lapCount',
                color: Colors.white,
                valueKey: const Key('summary_lap_count'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Key? valueKey;

  const _StatBlock({
    required this.label,
    required this.value,
    required this.color,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Colors.white.withAlpha(71),
          ),
        ),
        Text(
          value,
          key: valueKey,
          style: GoogleFonts.rajdhani(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LapList extends StatelessWidget {
  final List<LapResult> laps;
  final int? bestLapMs;

  const _LapList({required this.laps, required this.bestLapMs});

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma volta completada',
          key: const Key('summary_no_laps'),
          style: GoogleFonts.rajdhani(
            fontSize: 14,
            color: Colors.white.withAlpha(71),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: laps.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Color(0xFF1A1A1A), height: 1),
      itemBuilder: (_, i) {
        final lap = laps[i];
        final isBest =
            bestLapMs != null && lap.lapMs == bestLapMs;
        return _LapRow(
          lapNumber: i + 1,
          lap: lap,
          isBest: isBest,
        );
      },
    );
  }
}

class _LapRow extends StatelessWidget {
  final int lapNumber;
  final LapResult lap;
  final bool isBest;

  const _LapRow({
    required this.lapNumber,
    required this.lap,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$lapNumber',
              key: Key('summary_lap_number_$lapNumber'),
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white.withAlpha(71),
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatMs(lap.lapMs),
              key: Key('summary_lap_time_$lapNumber'),
              style: GoogleFonts.rajdhani(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isBest ? _kPurple : Colors.white,
              ),
            ),
          ),
          if (isBest)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kPurple.withAlpha(26),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: _kPurple.withAlpha(89), width: 1),
              ),
              child: Text(
                'PR',
                style: GoogleFonts.rajdhani(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _kPurple,
                ),
              ),
            ),
          if (lap.s1Ms != null || lap.s2Ms != null || lap.s3Ms != null)
            _SectorTimes(lap: lap),
        ],
      ),
    );
  }
}

class _SectorTimes extends StatelessWidget {
  final LapResult lap;

  const _SectorTimes({required this.lap});

  @override
  Widget build(BuildContext context) {
    final sectors = [lap.s1Ms, lap.s2Ms, lap.s3Ms]
        .asMap()
        .entries
        .where((e) => e.value != null)
        .toList();

    return Row(
      children: sectors.map((e) {
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            'S${e.key + 1} ${(e.value! / 1000).toStringAsFixed(3)}',
            key: Key(
                'summary_lap_${lap.lapMs}_sector_${e.key + 1}'),
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              color: Colors.white.withAlpha(115),
            ),
          ),
        );
      }).toList(),
    );
  }
}

String _formatMs(int ms) {
  final m = ms ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final h = ms % 1000;
  return '$m:${s.toString().padLeft(2, '0')}.${h.toString().padLeft(3, '0')}';
}

