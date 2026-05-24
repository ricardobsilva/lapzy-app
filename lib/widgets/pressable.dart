import 'package:flutter/material.dart';

/// Envolve qualquer widget com feedback visual de toque:
/// escala levemente (0.93) e reduz opacidade (0.65) ao pressionar.
/// Substitui GestureDetector puro em botões sem feedback nativo.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const Pressable({required this.child, this.onTap, super.key});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 200),
        curve: _pressed ? Curves.easeIn : Curves.elasticOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.65 : 1.0,
          duration: _pressed
              ? const Duration(milliseconds: 80)
              : const Duration(milliseconds: 200),
          child: widget.child,
        ),
      ),
    );
  }
}
