import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gps_source.dart';
import 'internal_gps_service.dart';
import 'external_gps_service.dart';

const _kPrefsKey = 'lapzy_gps_source_v1';

/// Singleton que gerencia a fonte GPS ativa no app.
///
/// Responsabilidades:
/// - Expor o [positionStream] correto para o [LapDetector]
/// - Persistir a preferência entre sessões (SharedPreferences)
/// - Fazer fallback automático para GPS interno se o externo desconectar
/// - Notificar ouvintes via [events] quando a fonte ativa muda
///
/// ### Ciclo de vida
/// ```dart
/// // main.dart
/// await GpsSourceManager.instance.init();   // carrega preferência e inicia stream
/// runApp(...)
///
/// // testes
/// GpsSourceManager.resetForTesting(GpsSourceManager.forTesting(...));
/// ```
class GpsSourceManager {
  GpsSourceManager._({
    required GpsSource initialSource,
    required InternalGpsService internalFallback,
    SharedPreferences? prefs,
  })  : _activeSource = initialSource,
        _internalFallback = internalFallback,
        _prefs = prefs;

  // ── singleton ──────────────────────────────────────────────────────────────

  static GpsSourceManager? _instance;

  static GpsSourceManager get instance => _instance ??= GpsSourceManager._(
        initialSource: InternalGpsService(),
        internalFallback: InternalGpsService(),
      );

  /// Substitui o singleton — use apenas em testes.
  static void resetForTesting([GpsSourceManager? mock]) => _instance = mock;

  /// Constrói um manager com estado controlado para testes.
  ///
  /// [internalFallback] é o serviço usado no fallback automático quando o GPS
  /// externo desconecta. Defaults para `Stream.empty()` em testes.
  factory GpsSourceManager.forTesting({
    required GpsSource activeSource,
    InternalGpsService? internalFallback,
    SharedPreferences? prefs,
  }) {
    return GpsSourceManager._(
      initialSource: activeSource,
      internalFallback: internalFallback ??
          InternalGpsService(streamFactory: () => const Stream.empty()),
      prefs: prefs,
    );
  }

  // ── estado ─────────────────────────────────────────────────────────────────

  GpsSource _activeSource;
  final InternalGpsService _internalFallback;
  final SharedPreferences? _prefs;
  StreamSubscription<Position>? _sourceSub;
  final _positionController = StreamController<Position>.broadcast();
  final _eventController = StreamController<GpsSourceChangedEvent>.broadcast();

  // ── interface pública ──────────────────────────────────────────────────────

  /// Stream de posições GPS da fonte ativa.
  ///
  /// Faz fallback automático para o GPS interno em caso de falha do externo.
  /// Passe esta stream como [positionStreamFactory] para o [LapDetector].
  Stream<Position> get positionStream => _positionController.stream;

  /// Stream de eventos de mudança de fonte.
  ///
  /// Emite [GpsSourceChangedEvent] quando o usuário muda a fonte ou
  /// quando ocorre fallback automático por desconexão do GPS externo.
  Stream<GpsSourceChangedEvent> get events => _eventController.stream;

  /// Fonte GPS ativa no momento.
  GpsSource get activeSource => _activeSource;

  // ── inicialização ──────────────────────────────────────────────────────────

  /// Inicializa o manager: carrega preferência persistida e inicia a fonte.
  ///
  /// Deve ser chamado em [main] antes de [runApp]. Idempotente.
  Future<void> init() async {
    await _loadPersistedSource();
    _subscribeToSource(_activeSource);
  }

  // ── mudança de fonte ───────────────────────────────────────────────────────

  /// Ativa uma nova fonte GPS e persiste a escolha localmente.
  Future<void> setActiveSource(GpsSource source) async {
    _activeSource = source;
    _subscribeToSource(source);
    _emitEvent(GpsSourceChangedEvent(
      source: source,
      reason: GpsSourceChangeReason.userChoice,
    ));
    await _persistSource(source);
  }

  // ── internos ───────────────────────────────────────────────────────────────

  void _subscribeToSource(GpsSource source) {
    _sourceSub?.cancel();
    _sourceSub = source.positionStream.listen(
      _positionController.add,
      onError: (_) => _handleExternalDisconnect(),
      onDone: () => _handleExternalDisconnect(),
    );
  }

  void _handleExternalDisconnect() {
    if (!_activeSource.info.isExternal) return;
    _sourceSub = null; // already done — avoid canceling from within onDone
    _activeSource = _internalFallback;
    _subscribeToSource(_internalFallback);
    _emitEvent(GpsSourceChangedEvent(
      source: _internalFallback,
      reason: GpsSourceChangeReason.fallback,
    ));
  }

  void _emitEvent(GpsSourceChangedEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }

  Future<void> _loadPersistedSource() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final info = GpsSourceInfo.fromJson(decoded);
      _activeSource = info.connectionType == GpsConnectionType.internal
          ? _internalFallback
          : ExternalGpsService(info: info);
    } catch (_) {
      // Preferência inválida ou corrompida — mantém GPS interno como padrão.
    }
  }

  Future<void> _persistSource(GpsSource source) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(source.info.toJson()));
    } catch (_) {
      // Falha silenciosa — preferência não é crítica para funcionamento.
    }
  }

  void dispose() {
    _sourceSub?.cancel();
    _positionController.close();
    _eventController.close();
  }
}
