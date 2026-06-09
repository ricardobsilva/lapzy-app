import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'gps_diagnostics.dart';
import 'gps_source.dart';
import 'usb_gps_channel.dart';

const _kStaleTimeout = Duration(seconds: 5);

/// Singleton que coleta eventos do pipeline GPS e expõe um snapshot diagnóstico
/// em tempo real para a UI e para análise pós-teste.
///
/// Recebe eventos via push de:
/// - [GpsSourceManager] → posições válidas, subscription start/cancel, erros
/// - [UsbGpsDetector] → linhas NMEA brutas + resultado do parse
///
/// Emite [GpsDiagnosticsSnapshot] via [stream] a cada evento relevante.
class GpsDiagnosticsService {
  GpsDiagnosticsService._();

  static GpsDiagnosticsService? _instance;
  static GpsDiagnosticsService get instance =>
      _instance ??= GpsDiagnosticsService._();

  static void resetForTesting([GpsDiagnosticsService? mock]) =>
      _instance = mock;

  GpsDiagnosticsSnapshot _snap = const GpsDiagnosticsSnapshot(
    sourceName: 'GPS interno',
    sourceType: GpsConnectionType.internal,
    fixState: GpsFixState.idle,
  );

  /// Rolling Hz: últimos 10 intervalos entre posições (em ms).
  final _hzSamples = <int>[];

  /// Para cálculo de Hz instantâneo: timestamp da posição anterior.
  DateTime? _lastPositionWallTime;

  /// Para cálculo de NMEA lines/sec: contagem e janela de 5s.
  int _nmeaCountInWindow = 0;
  DateTime? _nmeaWindowStart;

  /// Timer de stale: dispara quando nenhuma posição chega em 5s após fix.
  Timer? _staleTimer;

  final _ctrl = StreamController<GpsDiagnosticsSnapshot>.broadcast();

  GpsDiagnosticsSnapshot get current => _snap;
  Stream<GpsDiagnosticsSnapshot> get stream => _ctrl.stream;

  /// Chamado por [GpsSourceManager] quando uma nova subscription é criada.
  void onSubscriptionStarted(GpsSource source) {
    debugPrint(
      '[LAPZY/DIAG] Subscription iniciada → ${source.info.name} (${source.info.connectionType.name})',
    );
    _staleTimer?.cancel();
    _staleTimer = null;
    _hzSamples.clear();
    _lastPositionWallTime = null;
    _nmeaCountInWindow = 0;
    _nmeaWindowStart = null;
    final now = DateTime.now();
    _snap = GpsDiagnosticsSnapshot(
      sourceName: source.info.name,
      sourceType: source.info.connectionType,
      fixState: GpsFixState.initializing,
      subscriptionStartedAt: now,
      // Preserve USB serial fields so the diagnostics screen keeps showing
      // the last USB state even after fallback to internal GPS.
      usbRawBytesTotal: _snap.usbRawBytesTotal,
      usbRawBytesPerSec: _snap.usbRawBytesPerSec,
      usbSerialThreadAlive: _snap.usbSerialThreadAlive,
      usbSerialState: _snap.usbSerialState,
      usbEndpointInfo: _snap.usbEndpointInfo,
      usbBaudRate: _snap.usbBaudRate,
      usbLastSerialError: _snap.usbLastSerialError,
      usbConfiguredHz: _snap.usbConfiguredHz,
    );
    _emit();
  }

  /// Chamado por [GpsSourceManager] quando uma subscription é cancelada.
  void onSubscriptionCancelled(GpsSource source) {
    debugPrint(
      '[LAPZY/DIAG] Subscription cancelada → ${source.info.name}',
    );
    // Não altera snapshot — a próxima onSubscriptionStarted vai resetar.
  }

  /// Chamado por [GpsSourceManager] quando a stream GPS emite um erro.
  void onSourceError(GpsSource source, Object error) {
    debugPrint('[LAPZY/DIAG] Erro na fonte ${source.info.name}: $error');
    _staleTimer?.cancel();
    _staleTimer = null;
    _snap = _snap.copyWith(fixState: GpsFixState.error);
    _emit();
  }

  /// Chamado por [GpsSourceManager] quando a permissão de localização foi negada.
  void onPermissionDenied(GpsSource source) {
    debugPrint('[LAPZY/DIAG] Permissão de localização negada → ${source.info.name}');
    _staleTimer?.cancel();
    _staleTimer = null;
    _snap = _snap.copyWith(fixState: GpsFixState.permissionDenied);
    _emit();
  }

  /// Chamado por [GpsSourceManager] quando a stream GPS fecha (done).
  void onSourceDone(GpsSource source) {
    debugPrint('[LAPZY/DIAG] Stream fechada → ${source.info.name}');
    _staleTimer?.cancel();
    _staleTimer = null;
    _snap = _snap.copyWith(fixState: GpsFixState.disconnected);
    _emit();
  }

  /// Chamado por [GpsSourceManager] quando uma posição válida é recebida.
  void onPositionReceived(Position pos, DateTime wallTime) {
    final isFirst = _snap.firstRawDataAt == null;
    final isFirstValid = _snap.firstValidPositionAt == null;

    if (isFirst) {
      debugPrint(
        '[LAPZY/DIAG] Primeiro dado bruto recebido da fonte ${_snap.sourceName} '
        'Δ desde subscription=${_snap.subscriptionStartedAt != null ? wallTime.difference(_snap.subscriptionStartedAt!).inMilliseconds : "?"}ms',
      );
    }
    if (isFirstValid) {
      final delta = _snap.subscriptionStartedAt != null
          ? wallTime.difference(_snap.subscriptionStartedAt!).inMilliseconds
          : null;
      debugPrint(
        '[LAPZY/DIAG] Primeiro fix válido → ${_snap.sourceName} '
        'Δ desde subscription=${delta}ms '
        'lat=${pos.latitude.toStringAsFixed(6)} '
        'acc=${pos.accuracy.toStringAsFixed(1)}m',
      );
    }

    // Hz
    final prevWall = _lastPositionWallTime;
    final deltaMs =
        prevWall != null ? wallTime.difference(prevWall).inMilliseconds : null;
    final hzInstant =
        deltaMs != null && deltaMs > 0 ? 1000.0 / deltaMs : null;

    if (deltaMs != null) {
      _hzSamples.add(deltaMs);
      if (_hzSamples.length > 10) _hzSamples.removeAt(0);
    }
    final hzAvg = _hzSamples.isNotEmpty
        ? 1000.0 /
            (_hzSamples.reduce((a, b) => a + b) / _hzSamples.length)
        : null;

    _lastPositionWallTime = wallTime;

    _snap = _snap.copyWith(
      fixState: GpsFixState.fixAcquired,
      firstRawDataAt: isFirst ? wallTime : null,
      firstValidPositionAt: isFirstValid ? wallTime : null,
      lastLat: pos.latitude,
      lastLng: pos.longitude,
      lastAccuracyM: pos.accuracy,
      lastSpeedKmh: pos.speed < 0 ? 0.0 : pos.speed * 3.6,
      lastBearing: pos.heading,
      lastPositionGpsTime: pos.timestamp,
      lastPositionWallTime: wallTime,
      hzInstantaneous: hzInstant,
      hzRollingAvg: hzAvg,
      clearHzInstantaneous: hzInstant == null,
    );
    _emit();

    _staleTimer?.cancel();
    _staleTimer = Timer(_kStaleTimeout, () {
      if (_snap.fixState == GpsFixState.fixAcquired) {
        debugPrint('[LAPZY/DIAG] stale: sem posição por ${_kStaleTimeout.inSeconds}s → ${_snap.sourceName}');
        _snap = _snap.copyWith(fixState: GpsFixState.stale);
        _emit();
      }
    });
  }

  /// Chamado por [UsbGpsDetector] para cada linha NMEA bruta recebida.
  /// [parsedPosition]: posição gerada (null se descartada ou não-posição).
  /// [discardReason]: motivo de descarte se a sentença era RMC mas inválida.
  /// [gga]: dados GGA extraídos (null se não era GGA).
  void onNmeaLine({
    required String raw,
    required DateTime receivedAt,
    Position? parsedPosition,
    String? discardReason,
    GgaData? gga,
    String? rmcStatus,
  }) {
    final isFirst = _snap.firstRawDataAt == null;
    if (isFirst) {
      debugPrint(
        '[LAPZY/DIAG] Primeiro dado bruto NMEA da fonte ${_snap.sourceName}: $raw',
      );
    }

    final valid = parsedPosition != null;

    if (!valid && discardReason != null) {
      debugPrint('[LAPZY/DIAG] NMEA descartado ($discardReason): $raw');
    }

    // Atualiza janela de NMEA lines/sec (janela de 5s)
    final now = receivedAt;
    _nmeaWindowStart ??= now;
    _nmeaCountInWindow++;
    final windowDuration =
        now.difference(_nmeaWindowStart!).inMilliseconds;
    double? linesPerSec;
    if (windowDuration >= 2000) {
      linesPerSec = _nmeaCountInWindow * 1000.0 / windowDuration;
      // Reinicia janela a cada 5s
      if (windowDuration >= 5000) {
        _nmeaWindowStart = now;
        _nmeaCountInWindow = 0;
      }
    }

    // Mantém as últimas 15 linhas NMEA
    final updated = List<NmeaLineDiag>.from(_snap.recentNmea)
      ..add(NmeaLineDiag(
        raw: raw,
        receivedAt: receivedAt,
        valid: valid,
        discardReason: discardReason,
      ));
    if (updated.length > 15) updated.removeAt(0);

    final newDiscarded =
        _snap.nmeaDiscarded + (discardReason != null ? 1 : 0);
    final newReceived = _snap.nmeaReceived + 1;

    // Estado: se estava initializing, agora está waitingFix (dados chegando, sem fix ainda)
    final newState = _snap.fixState == GpsFixState.initializing
        ? GpsFixState.waitingFix
        : _snap.fixState;

    _snap = _snap.copyWith(
      fixState: newState,
      firstRawDataAt: isFirst ? receivedAt : null,
      recentNmea: updated,
      lastRmcStatus: rmcStatus,
      clearLastRmcStatus: rmcStatus == null && !valid,
      lastGga: gga,
      nmeaReceived: newReceived,
      nmeaDiscarded: newDiscarded,
      nmeaLinesPerSec: linesPerSec,
    );

    _emit();
  }

  /// Chamado por [UsbGpsDetector] com dados de diagnóstico da camada serial USB.
  void onUsbSerialDiag(UsbSerialDiag diag) {
    _snap = _snap.copyWith(
      usbRawBytesTotal: diag.bytesTotal,
      usbRawBytesPerSec: diag.bytesPerSec,
      usbSerialThreadAlive: diag.threadAlive,
      usbSerialState: diag.state,
      usbEndpointInfo: diag.endpoint,
      usbBaudRate: diag.baudRate,
      usbLastSerialError:
          diag.lastError?.isNotEmpty == true ? diag.lastError : null,
      usbConfiguredHz: diag.configuredHz,
    );
    _emit();
  }

  void _emit() {
    if (!_ctrl.isClosed) _ctrl.add(_snap);
  }

  void dispose() {
    _staleTimer?.cancel();
    _ctrl.close();
  }
}
