import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/track.dart';
import '../repositories/track_repository.dart';
import 'track_creation_screen.dart';
import 'track_detail_screen.dart';

const _kBg = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kGreen = Color(0xFF00E676);
const _kRed = Color(0xFFFF3B30);

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

class TrackListScreen extends StatefulWidget {
  const TrackListScreen({super.key});

  @override
  State<TrackListScreen> createState() => _TrackListScreenState();
}

class _TrackListScreenState extends State<TrackListScreen> {
  List<Track> _sortedTracks() {
    final list = List<Track>.from(TrackRepository().tracks);
    list.sort((a, b) {
      final ca = a.createdAt;
      final cb = b.createdAt;
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;
      return cb.compareTo(ca);
    });
    return list;
  }

  Future<bool> _confirmDelete(BuildContext context, Track track) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _DeleteConfirmSheet(track: track),
    );
    return confirmed == true;
  }

  void _deleteTrack(Track track) {
    TrackRepository().remove(track.id);
    if (mounted) setState(() {});
  }

  void _navigateToDetail(Track track) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrackDetailScreen(track: track),
      ),
    );
    if (mounted) setState(() {});
  }

  void _navigateToCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TrackCreationScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _sortedTracks();
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(),
            const Divider(color: Color(0x0FFFFFFF), height: 1),
            Expanded(
              child: tracks.isEmpty
                  ? _EmptyState(onCreateTap: _navigateToCreate)
                  : _TrackList(
                      tracks: tracks,
                      onTap: _navigateToDetail,
                      onConfirmDelete: (t) => _confirmDelete(context, t),
                      onDismissed: _deleteTrack,
                    ),
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
              key: const Key('tracks_back_button'),
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
            'TRAÇADOS',
            key: const Key('tracks_title'),
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

class _TrackList extends StatelessWidget {
  final List<Track> tracks;
  final void Function(Track) onTap;
  final Future<bool> Function(Track) onConfirmDelete;
  final void Function(Track) onDismissed;

  const _TrackList({
    required this.tracks,
    required this.onTap,
    required this.onConfirmDelete,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          key: const Key('tracks_list'),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
          itemCount: tracks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _TrackCard(
            track: tracks[index],
            index: index,
            onTap: onTap,
            onConfirmDelete: onConfirmDelete,
            onDismissed: onDismissed,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              key: const Key('tracks_fade'),
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

class _TrackCard extends StatelessWidget {
  final Track track;
  final int index;
  final void Function(Track) onTap;
  final Future<bool> Function(Track) onConfirmDelete;
  final void Function(Track) onDismissed;

  const _TrackCard({
    required this.track,
    required this.index,
    required this.onTap,
    required this.onConfirmDelete,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(track.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onConfirmDelete(track),
      onDismissed: (_) => onDismissed(track),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _kRed.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kRed.withAlpha(77)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: _kRed.withAlpha(204), size: 18),
            const SizedBox(width: 6),
            Text(
              'EXCLUIR',
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: _kRed.withAlpha(204),
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        key: Key('track_card_$index'),
        onTap: () => onTap(track),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(18), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      key: Key('track_name_$index'),
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
                      track.createdAt != null
                          ? _formatDate(track.createdAt!)
                          : '—',
                      key: Key('track_date_$index'),
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
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('tracks_empty_state'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TrackIcon(),
          const SizedBox(height: 48),
          Text(
            'Nenhum traçado configurado.',
            key: const Key('tracks_empty_title'),
            style: GoogleFonts.spaceMono(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white.withAlpha(179),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Crie um traçado para começar a cronometrar.',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: Colors.white.withAlpha(77),
            ),
          ),
          const SizedBox(height: 32),
          _GhostButton(
            label: 'CRIAR TRAÇADO',
            onTap: onCreateTap,
          ),
        ],
      ),
    );
  }
}

class _TrackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: CustomPaint(painter: _TrackIconPainter()),
    );
  }
}

class _TrackIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerPaint = Paint()
      ..color = Colors.white.withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final innerPaint = Paint()
      ..color = Colors.white.withAlpha(51)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, size.width / 2 - 1, outerPaint);

    // Oval de pista estilizado
    final trackRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.55,
      height: size.height * 0.38,
    );
    canvas.drawOval(trackRect, innerPaint);
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
      key: const Key('tracks_create_button'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: _kGreen.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kGreen.withAlpha(64), width: 1),
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

class _DeleteConfirmSheet extends StatelessWidget {
  final Track track;

  const _DeleteConfirmSheet({required this.track});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Excluir traçado?',
            key: const Key('delete_confirm_title'),
            style: GoogleFonts.spaceMono(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum histórico será perdido, mas você não poderá mais iniciar novas corridas com essas configurações.',
            key: const Key('delete_confirm_body'),
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: Colors.white.withAlpha(128),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            key: const Key('delete_confirm_button'),
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _kRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'EXCLUIR',
                  style: GoogleFonts.spaceMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            key: const Key('delete_cancel_button'),
            onTap: () => Navigator.of(context).pop(false),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: Center(
                child: Text(
                  'CANCELAR',
                  style: GoogleFonts.spaceMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white.withAlpha(128),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
