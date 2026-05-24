import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gps_diagnostics_service.dart';
import 'gps_source.dart';
import 'internal_gps_service.dart';
import 'telemetry_service.dart';

void _log(String msg) => debugPrint('[LAPZY/GPS] $msg');

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

  /// Para cálculo de Hz — timestamp da última posição recebida.
  DateTime? _lastPositionTime;
  int _positionCount = 0;

  /// Última posição GPS recebida — usada pelo pre-race check.
  Position? _lastPosition;

  /// Timestamp GPS da posição anterior — usada para delta_gps no telemetry.
  DateTime? _lastGpsTime;

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

  /// Última posição GPS recebida. Null se ainda não houve nenhuma.
  Position? get lastPosition => _lastPosition;

  /// True se uma posição foi recebida nos últimos [maxAgeSeconds] segundos.
  bool isReceivingPositions({int maxAgeSeconds = 5}) {
    final last = _lastPositionTime;
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds < maxAgeSeconds;
  }

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
    _log('Usuário selecionou: ${source.info.name} (${source.info.connectionType.name})');
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
    if (_sourceSub != null) {
      GpsDiagnosticsService.instance.onSubscriptionCancelled(_activeSource);
    }
    _sourceSub?.cancel();
    _lastPositionTime = null;
    _positionCount = 0;
    _log('Assinando fonte: ${source.info.name} (${source.info.connectionType.name})');
    GpsDiagnosticsService.instance.onSubscriptionStarted(source);
    _sourceSub = source.positionStream.listen(
      _onPositionReceived,
      onError: (Object err) {
        _log('ERRO na stream GPS (${source.info.name}): $err');
        _handleSourceError();
      },
      onDone: () {
        _log('Stream GPS encerrada (${source.info.name})');
        _handleSourceDone();
      },
    );
    if (source.info.connectionType == GpsConnectionType.internal) {
      unawaited(_emitLastKnownPosition());
    }
  }

  /// Emite a última posição em cache do Android imediatamente após assinar
  /// a fonte interna. Evita ficar em estado "conectando" durante o cold start
  /// do GPS — a tela de diagnóstico e o pré-corrida mostram dados ao instante.
  /// O stream fresco vai sobrescrevendo conforme chega.
  Future<void> _emitLastKnownPosition() async {
    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached == null) return;
      final age = DateTime.now().difference(cached.timestamp);
      _log(
        'Posição cached disponível: '
        'lat=${cached.latitude.toStringAsFixed(6)} '
        'lng=${cached.longitude.toStringAsFixed(6)} '
        'acc=${cached.accuracy.toStringAsFixed(0)}m '
        'idade=${age.inSeconds}s',
      );
      _onPositionReceived(cached);
    } catch (_) {
      // Falha silenciosa — getLastKnownPosition pode falhar em emuladores
      // ou quando a permissão foi revogada entre inicializações.
    }
  }

  void _onPositionReceived(Position pos) {
    final now = DateTime.now();
    final last = _lastPositionTime;
    final deltaMs = last != null ? now.difference(last).inMilliseconds : null;
    final hz = deltaMs != null && deltaMs > 0
        ? (1000 / deltaMs).toStringAsFixed(2)
        : '?';
    _positionCount++;
    _log(
      'POS #$_positionCount '
      'lat=${pos.latitude.toStringAsFixed(6)} '
      'lng=${pos.longitude.toStringAsFixed(6)} '
      'speed=${(pos.speed * 3.6).toStringAsFixed(1)}km/h '
      'acc=${pos.accuracy.toStringAsFixed(0)}m '
      'Δ=${deltaMs ?? '?'}ms '
      'hz=$hz '
      'src=${_activeSource.info.connectionType.name}',
    );

    TelemetryService.instance.logPosition(
      pos,
      deltaWallMs: deltaMs,
      prevGpsTime: _lastGpsTime,
      gpsSource: _activeSource.info.connectionType.name,
    );

    _lastPositionTime = now;
    _lastGpsTime = pos.timestamp;
    _lastPosition = pos;
    _positionController.add(pos);

    // Diagnostics: external USB GPS is already reported via onNmeaLine in
    // UsbGpsDetector. For internal and BT sources, report here.
    if (_activeSource.info.connectionType != GpsConnectionType.usb) {
      GpsDiagnosticsService.instance.onPositionReceived(pos, now);
    }
  }

  /// Chamado quando a stream emite um erro (ex.: permissão negada).
  void _handleSourceError() {
    GpsDiagnosticsService.instance.onSourceError(_activeSource, 'stream_error');
    if (_activeSource.info.isExternal) {
      _log('GPS externo com erro — fallback para GPS interno');
      TelemetryService.instance.logEvent('gps_fallback',
          reason: 'source_error',
          extra: {'from': _activeSource.info.name});
      _sourceSub = null;
      _activeSource = _internalFallback;
      _subscribeToSource(_internalFallback);
      _emitEvent(GpsSourceChangedEvent(
        source: _internalFallback,
        reason: GpsSourceChangeReason.fallback,
      ));
    } else {
      _log('GPS interno com erro — aguardando recuperação do sistema');
      TelemetryService.instance.logEvent('gps_source_error',
          reason: 'internal_gps_error');
    }
  }

  /// Chamado quando a stream termina (GPS externo desconectado ou stream vazia).
  void _handleSourceDone() {
    GpsDiagnosticsService.instance.onSourceDone(_activeSource);
    if (_activeSource.info.isExternal) {
      _log('GPS externo desconectado — fallback para GPS interno');
      TelemetryService.instance.logEvent('gps_fallback',
          reason: 'source_done',
          extra: {'from': _activeSource.info.name});
      _sourceSub = null;
      _activeSource = _internalFallback;
      _subscribeToSource(_internalFallback);
      _emitEvent(GpsSourceChangedEvent(
        source: _internalFallback,
        reason: GpsSourceChangeReason.fallback,
      ));
    } else {
      _log('Stream do GPS interno encerrou inesperadamente');
      TelemetryService.instance.logEvent('gps_source_done',
          reason: 'internal_stream_ended');
    }
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
      if (info.connectionType != GpsConnectionType.internal) {
        // GPS externo não pode ser restaurado automaticamente — a conexão física
        // (BT/USB) é perdida quando o app fecha. Reseta para GPS interno e o
        // usuário reconecta via GpsSourceScreen se necessário.
        _log('GPS externo persistido (${info.name}) — resetando para GPS interno no startup');
        await _persistSource(_internalFallback);
        return;
      }
      _activeSource = _internalFallback;
    } catch (_) {
      // Preferência inválida ou corrompida — mantém GPS interno como padrão.
      _log('Erro ao carregar preferência GPS — usando GPS interno');
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

  /// Emite um evento de fallback direto — use apenas em testes widget.
  ///
  /// Permite testar a resposta da UI a eventos de fallback sem precisar de
  /// assinatura de stream de posição nem de chamada à plataforma.
  @visibleForTesting
  void simulateFallbackForTesting(GpsSource source) {
    _activeSource = source;
    _emitEvent(GpsSourceChangedEvent(
      source: source,
      reason: GpsSourceChangeReason.fallback,
    ));
  }

  void dispose() {
    _sourceSub?.cancel();
    _positionController.close();
    _eventController.close();
  }
}
