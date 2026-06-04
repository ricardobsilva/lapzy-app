/// Rastreia se o app está em foreground ou background.
/// Atualizado pelo [_RaceScreenState] via [WidgetsBindingObserver].
///
/// Usado pelos services de GPS e crossing para prefixar logs com [FG] ou [BG],
/// permitindo identificar exatamente o que para de funcionar com a tela bloqueada.
class AppLifecycleTracker {
  static bool _isBackground = false;

  static void setBackground({required bool value}) {
    _isBackground = value;
  }

  static bool get isBackground => _isBackground;

  static String get tag => _isBackground ? '[BG]' : '[FG]';
}
