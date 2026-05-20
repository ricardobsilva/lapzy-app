import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gps_source.dart';
import '../services/gps_source_manager.dart';
import '../widgets/track_selection_sheet.dart';
import 'gps_source_screen.dart';
import 'race_history_screen.dart';
import 'track_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(),
            _GpsBannerSlot(),
            Expanded(child: _Body()),
          ],
        ),
      ),
    );
  }
}

// ── GPS BANNER ────────────────────────────────────────────────────────────────

/// Slot que escuta o [GpsSourceManager] e exibe o banner quando um GPS externo
/// está ativo. Quando a fonte é interna, não ocupa espaço algum.
class _GpsBannerSlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GpsSourceChangedEvent>(
      stream: GpsSourceManager.instance.events,
      builder: (context, snapshot) {
        final source =
            snapshot.data?.source ?? GpsSourceManager.instance.activeSource;
        if (!source.info.isExternal) return const SizedBox.shrink();
        return _GpsBanner(
          info: source.info,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const GpsSourceScreen()),
          ),
        );
      },
    );
  }
}

class _GpsBanner extends StatefulWidget {
  final GpsSourceInfo info;
  final VoidCallback onTap;

  const _GpsBanner({required this.info, required this.onTap});

  @override
  State<_GpsBanner> createState() => _GpsBannerState();
}

class _GpsBannerState extends State<_GpsBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = Color(widget.info.badgeArgb);

    return GestureDetector(
      key: const Key('home_gps_banner'),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Opacity(
          opacity: _pulseAnim.value,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: badgeColor.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: badgeColor.withAlpha(60), width: 1),
          ),
          child: Row(
            children: [
              _Badge(label: widget.info.badgeLabel, color: badgeColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.info.name,
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'GPS externo ativo',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        color: Colors.white.withAlpha(115),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.white.withAlpha(89),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(100), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── TOP BAR ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleIconButton(
                key: const Key('home_history_button'),
                icon: Icons.history_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RaceHistoryScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CircleIconButton(
                key: const Key('home_tracks_button'),
                icon: Icons.route_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TrackListScreen(),
                  ),
                ),
              ),
            ],
          ),
          _Logo(),
          _CircleIconButton(
            key: const Key('home_gps_settings_button'),
            icon: Icons.satellite_alt_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GpsSourceScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.spaceMono(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'LAP', style: base.copyWith(color: Colors.white)),
          TextSpan(
            text: 'ZY',
            style: base.copyWith(color: const Color(0xFFFF6D00)),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withAlpha(51),
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: Colors.white.withAlpha(128),
        ),
      ),
    );
  }
}

// ── BODY ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Tagline(),
            const SizedBox(height: 20),
            _ButtonWithGlow(),
            const SizedBox(height: 18),
            _Hint(),
          ],
        ),
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'CRONOMETRAGEM DE KART',
      style: GoogleFonts.spaceMono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 3.5,
        color: Colors.white.withAlpha(89), // rgba(255,255,255,0.35)
      ),
    );
  }
}

class _ButtonWithGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow — radial ellipse that simulates the SVG blur effect
        SizedBox(
          width: 420,
          height: 280,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: Center(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  color: const Color(0xFF00E676).withAlpha(38), // ~0.15 opacity
                ),
              ),
            ),
          ),
        ),
        // Button
        _IniciarButton(onTap: () => showTrackSelectionSheet(context)),
      ],
    );
  }
}

class _IniciarButton extends StatelessWidget {
  const _IniciarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withAlpha(30),
        highlightColor: Colors.white.withAlpha(15),
        child: Ink(
          width: 240,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF00E676),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              'INICIAR',
              style: GoogleFonts.spaceMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'selecione a pista após iniciar',
      style: GoogleFonts.spaceMono(
        fontSize: 10,
        letterSpacing: 1,
        color: Colors.white.withAlpha(71), // rgba(255,255,255,0.28)
      ),
    );
  }
}
