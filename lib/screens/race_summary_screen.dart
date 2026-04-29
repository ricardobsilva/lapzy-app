import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/race_session.dart';
import '../models/track.dart';

const _kBg = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kPurple = Color(0xFFBF5AF2);
const _kGreen = Color(0xFF00E676);
const _kRed = Color(0xFFFF3B30);
const _kDivider = Color(0xFF1A1A1A);

const _kFixedSectorColors = [
  Color(0xFF00B0FF), // S1
  Color(0xFFFFD600), // S2
  Color(0xFFFF6D00), // S3
];
const _kExtraSectorColors = [
  Color(0xFF1DE9B6), // teal
  Color(0xFFE040FB), // magenta
  Color(0xFFFF4081), // pink
  Color(0xFF40C4FF), // light blue
  Color(0xFFCCFF90), // lime
  Color(0xFFFFD180), // amber
  Color(0xFF82B1FF), // indigo
];

Color _sectorColor(int index) {
  if (index < _kFixedSectorColors.length) return _kFixedSectorColors[index];
  return _kExtraSectorColors[
      (index - _kFixedSectorColors.length) % _kExtraSectorColors.length];
}

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

  int get _totalRaceMs => widget.laps.fold(0, (sum, l) => sum + l.lapMs);

  int get _bestLapIndex {
    if (widget.bestLapMs == null) return -1;
    return widget.laps.indexWhere((l) => l.lapMs == widget.bestLapMs);
  }

  LapResult? get _bestLap {
    final idx = _bestLapIndex;
    return idx >= 0 ? widget.laps[idx] : null;
  }

  int _activeSectorCount() {
    return widget.laps.fold(0, (m, l) => l.sectors.length > m ? l.sectors.length : m);
  }

  void _showLapDetail(int lapNumber, LapResult lap) {
    final sectorCount = _activeSectorCount();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _LapDetailSheet(
        lapNumber: lapNumber,
        lap: lap,
        bestLap: _bestLap,
        sectorCount: sectorCount,
        maxHeight: MediaQuery.of(ctx).size.height * 0.85,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectorCount = _activeSectorCount();
    final bestLapIndex = _bestLapIndex;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryHero(
              track: widget.track,
              bestLapMs: widget.bestLapMs,
              bestLapNumber: bestLapIndex >= 0 ? bestLapIndex + 1 : null,
              lapCount: widget.laps.length,
              totalRaceMs: _totalRaceMs,
            ),
            const Divider(color: _kDivider, height: 1),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (sectorCount > 0) ...[
                    SliverToBoxAdapter(
                      child: _SectorSummary(
                        laps: widget.laps,
                        sectorCount: sectorCount,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Divider(color: _kDivider, height: 1),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Text(
                        'VOLTAS',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Colors.white.withAlpha(71),
                        ),
                      ),
                    ),
                  ),
                  if (widget.laps.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Nenhuma volta completada',
                            key: const Key('summary_no_laps'),
                            style: GoogleFonts.rajdhani(
                              fontSize: 14,
                              color: Colors.white.withAlpha(71),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList.separated(
                      itemCount: widget.laps.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: _kDivider, height: 1),
                      itemBuilder: (context, i) {
                        final lap = widget.laps[i];
                        final isBest = widget.bestLapMs != null &&
                            lap.lapMs == widget.bestLapMs;
                        final prevLapMs =
                            i > 0 ? widget.laps[i - 1].lapMs : null;
                        return _LapRow(
                          lapNumber: i + 1,
                          lap: lap,
                          isBest: isBest,
                          prevLapMs: prevLapMs,
                          onTap: () => _showLapDetail(i + 1, lap),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
              ),
            ),
            const Divider(color: _kDivider, height: 1),
            const _ShareButton(),
          ],
        ),
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  final Track track;
  final int? bestLapMs;
  final int? bestLapNumber;
  final int lapCount;
  final int totalRaceMs;

  const _SummaryHero({
    required this.track,
    required this.bestLapMs,
    required this.bestLapNumber,
    required this.lapCount,
    required this.totalRaceMs,
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HeroStat(
                label: 'MELHOR VOLTA',
                value: bestLapMs != null ? _formatMs(bestLapMs!) : '—',
                color: _kPurple,
                valueKey: const Key('summary_best_lap'),
                showPrBadge: bestLapMs != null,
              ),
              const SizedBox(width: 32),
              _HeroStat(
                label: 'VOLTA',
                value: bestLapNumber != null
                    ? '$bestLapNumber/$lapCount'
                    : '$lapCount',
                color: Colors.white,
                valueKey: const Key('summary_lap_count'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HeroStat(
            label: 'TEMPO TOTAL',
            value: lapCount > 0 ? _formatMs(totalRaceMs) : '—',
            color: Colors.white.withAlpha(153),
            valueKey: const Key('summary_total_time'),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Key? valueKey;
  final bool showPrBadge;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
    this.valueKey,
    this.showPrBadge = false,
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              key: valueKey,
              style: GoogleFonts.rajdhani(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (showPrBadge) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _PrBadge(),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PrBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _kPurple.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _kPurple.withAlpha(89), width: 1),
      ),
      child: Text(
        'PR',
        style: GoogleFonts.rajdhani(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _kPurple,
        ),
      ),
    );
  }
}

class _SectorSummary extends StatelessWidget {
  final List<LapResult> laps;
  final int sectorCount;

  const _SectorSummary({required this.laps, required this.sectorCount});

  List<int> _timesForSector(int index) {
    return laps
        .map((l) => _sectorOf(l, index))
        .whereType<int>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final avgs = <int?>[];
    final opportunities = <int?>[];

    for (int s = 0; s < sectorCount; s++) {
      final times = _timesForSector(s);
      if (times.isEmpty) {
        avgs.add(null);
        opportunities.add(null);
      } else {
        final avg = times.reduce((a, b) => a + b) ~/ times.length;
        final best = times.reduce(min);
        avgs.add(avg);
        opportunities.add(avg - best);
      }
    }

    int? bestSector, worstSector;
    int? minOpp, maxOpp;
    for (int s = 0; s < sectorCount; s++) {
      final opp = opportunities[s];
      if (opp == null) continue;
      if (minOpp == null || opp < minOpp) {
        minOpp = opp;
        bestSector = s;
      }
      if (maxOpp == null || opp > maxOpp) {
        maxOpp = opp;
        worstSector = s;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SETORES',
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Colors.white.withAlpha(71),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const columns = 3;
              const gap = 8.0;
              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: List.generate(sectorCount, (s) {
                  final indicator = s == bestSector
                      ? _SectorIndicator.best
                      : s == worstSector
                          ? _SectorIndicator.worst
                          : _SectorIndicator.neutral;
                  return SizedBox(
                    width: cardWidth,
                    child: _SectorSummaryCard(
                      sectorIndex: s,
                      avgMs: avgs[s],
                      indicator: indicator,
                    ),
                  );
                }),
              );
            },
          ),
          if (worstSector != null && maxOpp != null && maxOpp > 0) ...[
            const SizedBox(height: 10),
            Text(
              'MAIOR OPORTUNIDADE: S${worstSector + 1}  +${(maxOpp / 1000).toStringAsFixed(3)}s potencial',
              key: const Key('summary_sector_insight'),
              style: GoogleFonts.rajdhani(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withAlpha(115),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _SectorIndicator { best, worst, neutral }

class _SectorSummaryCard extends StatelessWidget {
  final int sectorIndex;
  final int? avgMs;
  final _SectorIndicator indicator;

  const _SectorSummaryCard({
    required this.sectorIndex,
    required this.avgMs,
    required this.indicator,
  });

  Color get _sectorLabelColor {
    return switch (indicator) {
      _SectorIndicator.best => _kGreen,
      _SectorIndicator.worst => _kRed,
      _SectorIndicator.neutral => _sectorColor(sectorIndex),
    };
  }

  Color get _borderColor {
    return switch (indicator) {
      _SectorIndicator.best => _kGreen,
      _SectorIndicator.worst => _kRed,
      _SectorIndicator.neutral => const Color(0xFF2A2A2A),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('summary_sector_$sectorIndex'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'S${sectorIndex + 1}',
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: _sectorLabelColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            avgMs != null ? _formatSectorMs(avgMs!) : '—',
            key: Key('summary_sector_avg_$sectorIndex'),
            style: GoogleFonts.rajdhani(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            switch (indicator) {
              _SectorIndicator.best => 'MELHOR',
              _SectorIndicator.worst => 'PIOR',
              _SectorIndicator.neutral => 'MÉDIO',
            },
            style: GoogleFonts.rajdhani(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: _borderColor.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}

class _LapRow extends StatelessWidget {
  final int lapNumber;
  final LapResult lap;
  final bool isBest;
  final int? prevLapMs;
  final VoidCallback onTap;

  const _LapRow({
    required this.lapNumber,
    required this.lap,
    required this.isBest,
    required this.prevLapMs,
    required this.onTap,
  });

  int? get _deltaMs {
    if (prevLapMs == null) return null;
    return prevLapMs! - lap.lapMs;
  }

  @override
  Widget build(BuildContext context) {
    final delta = _deltaMs;

    return GestureDetector(
      key: Key('summary_lap_row_$lapNumber'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
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
            SizedBox(
              width: 72,
              child: _DeltaText(deltaMs: delta, lapNumber: lapNumber),
            ),
            if (isBest) _PrBadge(),
          ],
        ),
      ),
    );
  }
}

class _DeltaText extends StatelessWidget {
  final int? deltaMs;
  final int lapNumber;

  const _DeltaText({required this.deltaMs, required this.lapNumber});

  @override
  Widget build(BuildContext context) {
    if (deltaMs == null) {
      return Text(
        '—',
        key: Key('summary_lap_delta_$lapNumber'),
        textAlign: TextAlign.end,
        style: GoogleFonts.rajdhani(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withAlpha(71),
        ),
      );
    }

    final improved = deltaMs! > 0;
    final color = improved ? _kGreen : _kRed;
    final prefix = improved ? '▲ ' : '▼ ';
    final value = (deltaMs!.abs() / 1000).toStringAsFixed(3);

    return Text(
      '$prefix$value',
      key: Key('summary_lap_delta_$lapNumber'),
      textAlign: TextAlign.end,
      style: GoogleFonts.rajdhani(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          key: const Key('summary_share_button'),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withAlpha(26), width: 1),
          ),
          child: Text(
            'COMPARTILHAR',
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Colors.white.withAlpha(180),
            ),
          ),
        ),
      ),
    );
  }
}

class _LapDetailSheet extends StatelessWidget {
  final int lapNumber;
  final LapResult lap;
  final LapResult? bestLap;
  final int sectorCount;
  final double maxHeight;

  const _LapDetailSheet({
    required this.lapNumber,
    required this.lap,
    required this.bestLap,
    required this.sectorCount,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        key: const Key('summary_lap_detail_sheet'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'VOLTA $lapNumber',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: Colors.white.withAlpha(71),
                    ),
                  ),
                  Text(
                    _formatMs(lap.lapMs),
                    key: const Key('lap_detail_total_time'),
                    style: GoogleFonts.rajdhani(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (sectorCount > 0) ...[
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF2A2A2A), height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: _SheetColumnHeaders(),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(sectorCount, (s) {
                      final thisTime = _sectorOf(lap, s);
                      final bestTime =
                          bestLap != null ? _sectorOf(bestLap!, s) : null;
                      return _SectorDetailRow(
                        sectorIndex: s,
                        thisTimeMs: thisTime,
                        bestTimeMs: bestTime,
                      );
                    }),
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SheetColumnHeaders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            'SETOR',
            style: GoogleFonts.rajdhani(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withAlpha(71),
            ),
          ),
        ),
        Expanded(
          child: Text(
            'TEMPO',
            style: GoogleFonts.rajdhani(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withAlpha(71),
            ),
          ),
        ),
        Expanded(
          child: Text(
            'SETOR CORRESPONDENTE NA MELHOR VOLTA',
            style: GoogleFonts.rajdhani(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withAlpha(71),
            ),
          ),
        ),
        const SizedBox(width: 60),
      ],
    );
  }
}

class _SectorDetailRow extends StatelessWidget {
  final int sectorIndex;
  final int? thisTimeMs;
  final int? bestTimeMs;

  const _SectorDetailRow({
    required this.sectorIndex,
    required this.thisTimeMs,
    required this.bestTimeMs,
  });

  Color get _color => _sectorColor(sectorIndex);

  @override
  Widget build(BuildContext context) {
    // positive delta = this lap was faster than best lap sector
    final deltaMs = (thisTimeMs != null && bestTimeMs != null)
        ? bestTimeMs! - thisTimeMs!
        : null;

    final deltaText = deltaMs == null
        ? '—'
        : deltaMs >= 0
            ? '▲ ${(deltaMs / 1000).toStringAsFixed(3)}'
            : '▼ ${(deltaMs.abs() / 1000).toStringAsFixed(3)}';

    final deltaColor = deltaMs == null
        ? Colors.white.withAlpha(71)
        : deltaMs >= 0
            ? _kGreen
            : _kRed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              'S${sectorIndex + 1}',
              key: Key('lap_detail_sector_label_$sectorIndex'),
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              thisTimeMs != null ? _formatSectorMs(thisTimeMs!) : '—',
              key: Key('lap_detail_sector_time_$sectorIndex'),
              style: GoogleFonts.rajdhani(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              bestTimeMs != null ? _formatSectorMs(bestTimeMs!) : '—',
              key: Key('lap_detail_best_sector_time_$sectorIndex'),
              style: GoogleFonts.rajdhani(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white.withAlpha(115),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              deltaText,
              key: Key('lap_detail_sector_delta_$sectorIndex'),
              textAlign: TextAlign.end,
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: deltaColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int? _sectorOf(LapResult lap, int index) {
  return index < lap.sectors.length ? lap.sectors[index] : null;
}

String _formatMs(int ms) {
  final m = ms ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  final h = ms % 1000;
  return '$m:${s.toString().padLeft(2, '0')}.${h.toString().padLeft(3, '0')}';
}

String _formatSectorMs(int ms) {
  final s = ms ~/ 1000;
  final h = ms % 1000;
  return '$s.${h.toString().padLeft(3, '0')}';
}
