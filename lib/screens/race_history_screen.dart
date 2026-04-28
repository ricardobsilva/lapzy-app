import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/race_session_record.dart';
import '../models/track.dart';
import '../repositories/race_session_repository.dart';
import 'race_summary_screen.dart';

const _kBg = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kGreen = Color(0xFF00E676);

const _kMonths = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _formatDate(DateTime d) {
  final local = d.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = _kMonths[local.month - 1];
  final year = local.year;
  final hour = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$day $month $year · $hour:$min';
}

class RaceHistoryScreen extends StatelessWidget {
  const RaceHistoryScreen({super.key});

  List<RaceSessionRecord> _sortedSessions() {
    final list = List<RaceSessionRecord>.from(RaceSessionRepository().sessions);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sortedSessions();
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(),
            const Divider(
              color: Color(0x0FFFFFFF),
              height: 1,
            ),
            Expanded(
              child: sessions.isEmpty
                  ? const _EmptyState()
                  : _SessionList(sessions: sessions),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              key: const Key('history_back_button'),
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                '‹',
                style: GoogleFonts.spaceMono(
                  fontSize: 24,
                  color: Colors.white.withAlpha(128),
                ),
              ),
            ),
          ),
          Text(
            'CORRIDAS',
            key: const Key('history_title'),
            style: GoogleFonts.spaceMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Colors.white.withAlpha(230),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<RaceSessionRecord> sessions;

  const _SessionList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          key: const Key('history_list'),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
          itemCount: sessions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _SessionCard(
            session: sessions[index],
            index: index,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              key: const Key('history_fade'),
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000A0A0A), Color(0xFF0A0A0A)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final RaceSessionRecord session;
  final int index;

  const _SessionCard({required this.session, required this.index});

  void _navigateToSummary(BuildContext context) {
    final track = Track(id: session.trackId, name: session.trackName);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RaceSummaryScreen(
        laps: session.laps,
        bestLapMs: session.bestLapMs,
        track: track,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('history_card_$index'),
      onTap: () => _navigateToSummary(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withAlpha(18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.trackName,
                    key: Key('history_track_name_$index'),
                    style: GoogleFonts.spaceMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(session.date),
                    key: Key('history_date_$index'),
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      color: Colors.white.withAlpha(89),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '›',
              style: GoogleFonts.spaceMono(
                fontSize: 20,
                color: Colors.white.withAlpha(46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('history_empty_state'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ClockIcon(),
          const SizedBox(height: 48),
          Text(
            'Nenhuma corrida ainda.',
            key: const Key('history_empty_title'),
            style: GoogleFonts.spaceMono(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white.withAlpha(179),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sua primeira corrida vai aparecer aqui.',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: Colors.white.withAlpha(77),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Que tal aquecer o motor?',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: Colors.white.withAlpha(77),
            ),
          ),
          const SizedBox(height: 32),
          _GhostButton(
            label: 'INICIAR CORRIDA',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _ClockIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: CustomPaint(
        painter: _ClockPainter(),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerPaint = Paint()
      ..color = Colors.white.withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final innerPaint = Paint()
      ..color = Colors.white.withAlpha(31)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final handPaint = Paint()
      ..color = Colors.white.withAlpha(51)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, size.width / 2 - 1, outerPaint);
    canvas.drawCircle(center, size.width / 2 - 10, innerPaint);

    // Hour hand pointing ~12 o'clock (slightly left)
    canvas.drawLine(
      center,
      center + const Offset(-2, -14),
      handPaint,
    );
    // Minute hand pointing ~3 o'clock
    canvas.drawLine(
      center,
      center + const Offset(9, 3),
      handPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('history_start_race_button'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: _kGreen.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _kGreen.withAlpha(64),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: _kGreen,
          ),
        ),
      ),
    );
  }
}
