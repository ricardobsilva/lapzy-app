import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lifecycle_tracker.dart';
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
    Duration? watchdogTimeout,
    Future<LocationPermission> Function()? permissionRequester,
    Future<bool> Function()? appSettingsOpener,
  })  : _activeSource = initialSource,
        _internalFallback = internalFallback,
        _prefs = prefs,
        _watchdogTimeout = watchdogTimeout ?? _kFirstPositionTimeout,
        _permissionRequester = permissionRequester ?? Geolocator.requestPermission,
        _appSettingsOpener = appSettingsOpener ?? Geolocator.openAppSettings;

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
  /// [watchdogTimeout] controla o timeout do watchdog de primeira posição.
  /// Passe `Duration.zero` para desabilitar em testes que não precisam do watchdog.
  factory GpsSourceManager.forTesting({
    required GpsSource activeSource,
    InternalGpsService? internalFallback,
    SharedPreferences? prefs,
    Duration watchdogTimeout = Duration.zero,
    Future<LocationPermission> Function()? permissionRequester,
    Future<bool> Function()? appSettingsOpener,
  }) {
    return GpsSourceManager._(
      initialSource: activeSource,
      internalFallback: internalFallback ??
          InternalGpsService(streamFactory: () => const Stream.empty()),
      prefs: prefs,
      watchdogTimeout: watchdogTimeout,
      permissionRequester: permissionRequester,
      appSettingsOpener: appSettingsOpener,
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

  /// Timer de watchdog: reinicia a subscription se nenhum dado chegar em tempo.
  /// Também usado para agendar retry após erro do GPS interno.
  Timer? _firstPositionTimer;

  /// Quanto tempo esperar pelo primeiro dado antes de reiniciar.
  ///
  /// 90s cobre cold start de GPS (45–90s sem cache de satélites).
  /// Valor curto interrompe a inicialização antes do fix chegar.
  static const _kFirstPositionTimeout = Duration(seconds: 90);

  /// Número máximo de tentativas automáticas de restart do watchdog.
  ///
  /// 1 retry é suficiente para o caso de "stream silenciosa" do Android.
  static const _kMaxWatchdogRetries = 1;

  /// Timeout efetivo do watchdog — injetável via [forTesting].
  /// Duration.zero desabilita o watchdog e o retry de erro completamente.
  final Duration _watchdogTimeout;

  /// Delay entre tentativas de reconexão após erro do GPS interno.
  static const _kInternalErrorRetryDelay = Duration(seconds: 3);

  /// Máximo de retries automáticos por erro do GPS interno.
  static const _kMaxInternalErrorRetries = 3;

  /// Contador de erros consecutivos do GPS interno — reset ao receber 1ª posição.
  int _internalErrorRetries = 0;

  /// Callbacks injetáveis para permissão e configurações (override em testes).
  final Future<LocationPermission> Function() _permissionRequester;
  final Future<bool> Function() _appSettingsOpener;

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
    _log('source_selected: ${_activeSource.info.name} (startup)');
    await _subscribeToSource(_activeSource);
  }

  // ── mudança de fonte ───────────────────────────────────────────────────────

  /// Ativa uma nova fonte GPS e persiste a escolha localmente.
  ///
  /// Idempotente: se a fonte já está ativa e a subscription está viva,
  /// ignora a chamada para evitar reconectar desnecessariamente.
  Future<void> setActiveSource(GpsSource source) async {
    final alreadyActive = _sourceSub != null &&
        _activeSource.info.name == source.info.name;
    if (alreadyActive) {
      _log('source_already_active_reusing: ${source.info.name} — skipping restart');
      return;
    }
    _log('source_selected: ${source.info.name} (${source.info.connectionType.name}) reason=user_choice');
    _activeSource = source;
    await _subscribeToSource(source);
    _emitEvent(GpsSourceChangedEvent(
      source: source,
      reason: GpsSourceChangeReason.userChoice,
    ));
    await _persistSource(source);
  }

  /// Reinicia a subscription da fonte ativa — útil para depuração manual.
  Future<void> restartSource() async {
    _log('source_start_requested: ${_activeSource.info.name} reason=manual_restart');
    await _subscribeToSource(_activeSource);
  }

  /// Notifica que uma tela se conectou ao stream GPS.
  void notifyScreenAttached(String screen) {
    _log('screen_attached_to_stream: $screen src=${_activeSource.info.name}');
  }

  /// Notifica que uma tela se desconectou do stream GPS.
  void notifyScreenDetached(String screen) {
    _log('screen_detached_from_stream: $screen src=${_activeSource.info.name}');
  }

  // ── internos ───────────────────────────────────────────────────────────────

  /// Cancela a subscription anterior, reseta estado e inicia nova subscription.
  ///
  /// O `await` no cancel evita race conditions onde a stream antiga ainda emite
  /// posições após a nova subscription ter sido criada.
  ///
  /// [retryAttempt] conta quantas vezes o watchdog já reiniciou esta fonte.
  /// O watchdog para após [_kMaxWatchdogRetries] tentativas.
  Future<void> _subscribeToSource(GpsSource source, {int retryAttempt = 0}) async {
    _firstPositionTimer?.cancel();
    _firstPositionTimer = null;

    if (_sourceSub != null) {
      _log('previous_subscription_cancel_start: prev=${_activeSource.info.name}');
      GpsDiagnosticsService.instance.onSubscriptionCancelled(_activeSource);
      await _sourceSub!.cancel();
      _sourceSub = null;
      _log('previous_subscription_cancel_done');
    }

    _log('source_state_reset');
    _lastPositionTime = null;
    _lastPosition = null;
    _lastGpsTime = null;
    _positionCount = 0;

    if (retryAttempt > 0) {
      _log('subscription_restart_attempt: ${source.info.name} (tentativa $retryAttempt/$_kMaxWatchdogRetries)');
    } else {
      _log('new_subscription_start: ${source.info.name} (${source.info.connectionType.name})');
    }

    GpsDiagnosticsService.instance.onSubscriptionStarted(source);
    _sourceSub = source.positionStream.listen(
      _onPositionReceived,
      onError: (Object err) {
        _log('ERRO na stream GPS (${source.info.name}): $err');
        _handleSourceError(err);
      },
      onDone: () {
        _log('Stream GPS encerrada (${source.info.name})');
        _handleSourceDone();
      },
    );

    _scheduleFirstPositionWatchdog(source, retryAttempt: retryAttempt);
  }

  /// Agenda watchdog que reinicia a subscription se nenhum dado chegar em tempo.
  ///
  /// Reinicia até [_kMaxWatchdogRetries] vezes. Se todas as tentativas falharem,
  /// loga [subscription_restart_failure] e para.
  /// Desabilitado quando [_watchdogTimeout] é [Duration.zero] (testes).
  void _scheduleFirstPositionWatchdog(GpsSource source, {required int retryAttempt}) {
    if (_watchdogTimeout == Duration.zero) return;
    _firstPositionTimer = Timer(_watchdogTimeout, () {
      if (_positionCount > 0) return;
      if (_activeSource.info.name != source.info.name) return;

      if (retryAttempt < _kMaxWatchdogRetries) {
        final nextAttempt = retryAttempt + 1;
        _log(
          'no_first_position_timeout: ${source.info.name} '
          'após ${_watchdogTimeout.inSeconds}s sem dados — '
          'reiniciando (tentativa $nextAttempt/$_kMaxWatchdogRetries)',
        );
        TelemetryService.instance.logEvent(
          'gps_no_data_timeout',
          reason: 'first_position_timeout',
          extra: {'source': source.info.name, 'attempt': nextAttempt},
        );
        unawaited(_subscribeToSource(source, retryAttempt: nextAttempt));
      } else {
        _log(
          'subscription_restart_failure: ${source.info.name} '
          '— sem dados após $_kMaxWatchdogRetries tentativas de reinício',
        );
        TelemetryService.instance.logEvent(
          'gps_no_data_timeout',
          reason: 'retry_also_failed',
          extra: {'source': source.info.name, 'attempts': retryAttempt + 1},
        );
      }
    });
  }

  void _onPositionReceived(Position pos) {
    final now = DateTime.now();
    final last = _lastPositionTime;
    final deltaMs = last != null ? now.difference(last).inMilliseconds : null;
    final hz = deltaMs != null && deltaMs > 0
        ? (1000 / deltaMs).toStringAsFixed(2)
        : '?';
    _positionCount++;

    if (_positionCount == 1) {
      _firstPositionTimer?.cancel();
      _firstPositionTimer = null;
      _internalErrorRetries = 0;
      final subStartedAt =
          GpsDiagnosticsService.instance.current.subscriptionStartedAt;
      final deltaFromSub = subStartedAt != null
          ? now.difference(subStartedAt).inMilliseconds
          : null;
      _log(
        'first_raw_position_received: src=${_activeSource.info.name} '
        'Δ_subscription=${deltaFromSub ?? '?'}ms',
      );
      _log(
        'first_fix_valid: lat=${pos.latitude.toStringAsFixed(6)} '
        'acc=${pos.accuracy.toStringAsFixed(1)}m',
      );
    }

    _log(
      '${AppLifecycleTracker.tag} '
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

    GpsDiagnosticsService.instance.onPositionReceived(pos, now);
  }

  /// Chamado quando a stream emite um erro (ex.: permissão negada).
  ///
  /// O `_sourceSub` é anulado antes de chamar [_subscribeToSource] para que
  /// a nova subscription não tente await-cancelar uma stream já em erro.
  void _handleSourceError(Object err) {
    GpsDiagnosticsService.instance.onSourceError(_activeSource, err);
    if (_activeSource.info.isExternal) {
      _log('source_selected: ${_internalFallback.info.name} reason=fallback_error from=${_activeSource.info.name}');
      TelemetryService.instance.logEvent('gps_fallback',
          reason: 'source_error',
          extra: {'from': _activeSource.info.name});
      _sourceSub = null;
      _activeSource = _internalFallback;
      unawaited(_subscribeToSource(_internalFallback));
      _emitEvent(GpsSourceChangedEvent(
        source: _internalFallback,
        reason: GpsSourceChangeReason.fallback,
      ));
    } else {
      if (_isPermissionError(err)) {
        _handlePermissionDenied();
        return;
      }
      _firstPositionTimer?.cancel();
      _firstPositionTimer = null;
      _sourceSub = null;
      _internalErrorRetries++;
      if (_watchdogTimeout != Duration.zero &&
          _internalErrorRetries <= _kMaxInternalErrorRetries) {
        _log(
          'GPS interno com erro — reiniciando em ${_kInternalErrorRetryDelay.inSeconds}s '
          '(tentativa $_internalErrorRetries/$_kMaxInternalErrorRetries)',
        );
        TelemetryService.instance.logEvent(
          'gps_source_error',
          reason: 'internal_gps_error_retry_scheduled',
          extra: {'attempt': _internalErrorRetries},
        );
        _firstPositionTimer = Timer(_kInternalErrorRetryDelay, () {
          _firstPositionTimer = null;
          if (_activeSource.info.connectionType == GpsConnectionType.internal) {
            unawaited(_subscribeToSource(_activeSource));
          }
        });
      } else {
        _log(
          'GPS interno com erro — sem mais tentativas '
          '(${_internalErrorRetries > _kMaxInternalErrorRetries ? 'máx atingido' : 'watchdog desabilitado'})',
        );
        TelemetryService.instance.logEvent(
          'gps_source_error',
          reason: 'internal_gps_error_no_more_retries',
          extra: {'attempts': _internalErrorRetries},
        );
      }
    }
  }

  bool _isPermissionError(Object err) {
    final msg = err.toString().toLowerCase();
    return msg.contains('permission') || msg.contains('denied');
  }

  void _handlePermissionDenied() {
    _firstPositionTimer?.cancel();
    _firstPositionTimer = null;
    _sourceSub = null;
    _log('GPS interno: permissão negada — solicitando ao usuário');
    TelemetryService.instance.logEvent('gps_permission_denied');
    unawaited(_requestPermissionAndRetry());
  }

  Future<void> _requestPermissionAndRetry() async {
    final perm = await _permissionRequester();
    if (perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always) {
      _log('GPS: permissão concedida — reiniciando');
      TelemetryService.instance.logEvent('gps_permission_granted');
      _internalErrorRetries = 0;
      await _subscribeToSource(_activeSource);
    } else if (perm == LocationPermission.deniedForever) {
      _log('GPS: permissão negada permanentemente — abrindo configurações');
      TelemetryService.instance.logEvent('gps_permission_denied_forever');
      GpsDiagnosticsService.instance.onPermissionDenied(_activeSource);
      await _appSettingsOpener();
    } else {
      _log('GPS: permissão negada pelo usuário');
      TelemetryService.instance.logEvent('gps_permission_rejected_by_user');
      GpsDiagnosticsService.instance.onPermissionDenied(_activeSource);
    }
  }

  /// Solicita permissão de localização ao usuário.
  ///
  /// Mostra o dialog do sistema se a permissão não foi negada definitivamente.
  /// Se negada definitivamente, abre as configurações do app.
  /// Se concedida, reinicia a subscription GPS automaticamente.
  Future<void> requestLocationPermission() async {
    await _requestPermissionAndRetry();
  }

  /// Chamado quando a stream termina (GPS externo desconectado ou stream vazia).
  ///
  /// O `_sourceSub` é anulado antes de chamar [_subscribeToSource] para que
  /// a nova subscription não tente await-cancelar uma stream já encerrada.
  void _handleSourceDone() {
    GpsDiagnosticsService.instance.onSourceDone(_activeSource);
    if (_activeSource.info.isExternal) {
      _log('source_selected: ${_internalFallback.info.name} reason=fallback_done from=${_activeSource.info.name}');
      TelemetryService.instance.logEvent('gps_fallback',
          reason: 'source_done',
          extra: {'from': _activeSource.info.name});
      _sourceSub = null;
      _activeSource = _internalFallback;
      unawaited(_subscribeToSource(_internalFallback));
      _emitEvent(GpsSourceChangedEvent(
        source: _internalFallback,
        reason: GpsSourceChangeReason.fallback,
      ));
    } else {
      _firstPositionTimer?.cancel();
      _firstPositionTimer = null;
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
    _firstPositionTimer?.cancel();
    _sourceSub?.cancel();
    _positionController.close();
    _eventController.close();
  }
}
