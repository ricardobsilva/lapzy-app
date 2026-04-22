import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/track.dart';
import '../repositories/track_repository.dart';
import '../screens/track_creation_screen.dart';

void showTrackSelectionSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(140), // 0.55 opacity
    builder: (_) => const _TrackSelectionSheet(),
  );
}

// ── SHEET PRINCIPAL ───────────────────────────────────────────────────────────

class _TrackSelectionSheet extends StatefulWidget {
  const _TrackSelectionSheet();

  @override
  State<_TrackSelectionSheet> createState() => _TrackSelectionSheetState();
}

class _TrackSelectionSheetState extends State<_TrackSelectionSheet> {
  final _searchController = TextEditingController();
  List<Track> _tracks = const [];
  String? _selectedId;
  List<Track> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _tracks = TrackRepository().tracks.toList();
    _filtered = List.from(_tracks);
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _tracks.where((t) => t.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasTracks => _tracks.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final sheetHeight = _hasTracks ? screenHeight * 0.62 : screenHeight * 0.55;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const _DragHandle(),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'SELECIONAR PISTA',
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white.withAlpha(89), // 0.35
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SearchField(controller: _searchController),
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withAlpha(15), height: 1), // 0.06
          if (_hasTracks)
            Expanded(
              child: _TrackList(
                tracks: _filtered,
                selectedId: _selectedId,
                onSelect: (id) => setState(() => _selectedId = id),
              ),
            )
          else
            const Expanded(child: _EmptyContent()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TrackCreationScreen(),
                  ),
                );
              },
              child: _NewTrackButton(hasTracks: _hasTracks),
            ),
          ),
          SizedBox(height: bottomPad + 16),
        ],
      ),
    );
  }
}

// ── DRAG HANDLE ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 50,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38), // 0.15
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── CAMPO DE BUSCA ────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1), // 0.08
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.spaceMono(
          fontSize: 13,
          color: Colors.white.withAlpha(217), // 0.85
        ),
        decoration: InputDecoration(
          hintText: 'Buscar pista...',
          hintStyle: GoogleFonts.spaceMono(
            fontSize: 13,
            color: Colors.white.withAlpha(51), // 0.2
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: InputBorder.none,
        ),
        cursorColor: const Color(0xFF00E676),
      ),
    );
  }
}

// ── LISTA DE PISTAS ───────────────────────────────────────────────────────────

class _TrackList extends StatelessWidget {
  final List<Track> tracks;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _TrackList({
    required this.tracks,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          itemCount: tracks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TrackItem(
            track: tracks[i],
            selected: tracks[i].id == selectedId,
            onTap: () => onSelect(tracks[i].id),
          ),
        ),
        // Gradiente de fade no bottom da lista
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 56,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF141414).withAlpha(0),
                    const Color(0xFF141414),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── ITEM DE PISTA ─────────────────────────────────────────────────────────────

class _TrackItem extends StatelessWidget {
  final Track track;
  final bool selected;
  final VoidCallback onTap;

  const _TrackItem({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00E676).withAlpha(15) // 0.06
              : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF00E676).withAlpha(51) // 0.2
                : Colors.white.withAlpha(13), // 0.05
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (selected) ...[
              const SizedBox(width: 12),
              Container(
                width: 3,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 11),
            ] else
              const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: GoogleFonts.spaceMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : Colors.white.withAlpha(217), // 0.85
                    ),
                  ),
                  if (track.lastSession != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Última sessão: ${_formatDate(track.lastSession!)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        color: Colors.white.withAlpha(89), // 0.35
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '›',
                style: GoogleFonts.spaceMono(
                  fontSize: 18,
                  color: Colors.white.withAlpha(51), // 0.2
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ESTADO VAZIO ──────────────────────────────────────────────────────────────

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.18,
            child: CustomPaint(
              size: const Size(48, 72),
              painter: _FlagIconPainter(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma pista salva',
            style: GoogleFonts.spaceMono(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white.withAlpha(140), // 0.55
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie sua primeira pista para começar',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: Colors.white.withAlpha(64), // 0.25
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícone de bandeira de largada — reproduz o SVG do design (mastro + triângulo).
class _FlagIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    // Mastro vertical
    final mastroRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 - 2, 0, 4, size.height * 0.86),
      const Radius.circular(2),
    );
    canvas.drawRRect(mastroRect, paint);

    // Bandeira triangular
    final path = Path()
      ..moveTo(size.width / 2 + 2, 0)
      ..lineTo(size.width, size.height * 0.24)
      ..lineTo(size.width / 2 + 2, size.height * 0.48)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── BOTÃO NOVA PISTA ──────────────────────────────────────────────────────────

class _NewTrackButton extends StatelessWidget {
  final bool hasTracks;

  const _NewTrackButton({required this.hasTracks});

  @override
  Widget build(BuildContext context) {
    if (!hasTracks) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF00E676),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '+ NOVA PISTA',
            style: GoogleFonts.spaceMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.black,
            ),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: Colors.white.withAlpha(26), // 0.1
        radius: 10,
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '+ NOVA PISTA',
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withAlpha(102), // 0.4
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double start = 0;
      while (start < metric.length) {
        final end = math.min(start + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── HELPERS ───────────────────────────────────────────────────────────────────

String _formatDate(DateTime date) {
  const months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
