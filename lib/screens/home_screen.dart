import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/track_selection_sheet.dart';

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
            Expanded(child: _Body()),
          ],
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
          _CircleIconButton(icon: Icons.history_outlined),
          _Logo(),
          _CircleIconButton(icon: Icons.person_outline),
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

  const _CircleIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withAlpha(51), // rgba(255,255,255,0.20)
          width: 1.2,
        ),
      ),
      child: Icon(
        icon,
        size: 15,
        color: Colors.white.withAlpha(128), // rgba(255,255,255,0.50)
      ),
    );
  }
}

// ── BODY ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
