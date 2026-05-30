import 'gps_source.dart';

/// Estado da fonte GPS no pipeline de diagnóstico.
enum GpsFixState {
  idle,           // não subscrito ainda
  initializing,   // subscription criada, zero dados recebidos
  waitingFix,     // dados chegando (NMEA ou posição), sem fix válido ainda
  fixAcquired,    // ao menos uma Position válida recebida
  stale,          // tinha fix, mas nenhuma posição nos últimos 5s
  error,          // stream emitiu erro
  disconnected,   // stream fechou (fonte desconectada)
}

/// Linha NMEA individual com resultado do parse.
class NmeaLineDiag {
  final String raw;
  final DateTime receivedAt;
  final bool valid;           // true → produziu Position
  final String? discardReason; // null se valid=true ou sentença não-posição

  const NmeaLineDiag({
    required this.raw,
    required this.receivedAt,
    required this.valid,
    this.discardReason,
  });
}

/// Dados extraídos de uma sentença GGA (qualidade de fix).
class GgaData {
  final int fixQuality;  // 0=sem fix, 1=GPS, 2=DGPS
  final int satellites;
  final double? hdop;

  const GgaData({
    required this.fixQuality,
    required this.satellites,
    this.hdop,
  });
}

/// Snapshot imutável do estado de diagnóstico GPS.
/// Emitido pelo GpsDiagnosticsService a cada evento relevante.
class GpsDiagnosticsSnapshot {
  final String sourceName;
  final GpsConnectionType sourceType;
  final GpsFixState fixState;

  // Eventos de tempo
  final DateTime? subscriptionStartedAt;
  final DateTime? firstRawDataAt;
  final DateTime? firstValidPositionAt;

  // Última posição válida
  final double? lastLat;
  final double? lastLng;
  final double? lastAccuracyM;
  final double? lastSpeedKmh;
  final double? lastBearing;
  final DateTime? lastPositionGpsTime;
  final DateTime? lastPositionWallTime;

  // Frequência
  final double? hzInstantaneous;
  final double? hzRollingAvg;

  // NMEA (GPS externo)
  final List<NmeaLineDiag> recentNmea; // últimas 15 linhas (todos os tipos)
  final String? lastRmcStatus;          // 'A' (fix) ou 'V' (void)
  final GgaData? lastGga;
  final int nmeaReceived;
  final int nmeaDiscarded;
  final double? nmeaLinesPerSec;

  // USB Serial (apenas para GPS externo USB)
  final int usbRawBytesTotal;
  final double usbRawBytesPerSec;
  final bool? usbSerialThreadAlive;
  final String? usbSerialState;
  final String? usbEndpointInfo;
  final int usbBaudRate;
  final String? usbLastSerialError;
  final int usbConfiguredHz;

  const GpsDiagnosticsSnapshot({
    required this.sourceName,
    required this.sourceType,
    this.fixState = GpsFixState.idle,
    this.subscriptionStartedAt,
    this.firstRawDataAt,
    this.firstValidPositionAt,
    this.lastLat,
    this.lastLng,
    this.lastAccuracyM,
    this.lastSpeedKmh,
    this.lastBearing,
    this.lastPositionGpsTime,
    this.lastPositionWallTime,
    this.hzInstantaneous,
    this.hzRollingAvg,
    this.recentNmea = const [],
    this.lastRmcStatus,
    this.lastGga,
    this.nmeaReceived = 0,
    this.nmeaDiscarded = 0,
    this.nmeaLinesPerSec,
    this.usbRawBytesTotal = 0,
    this.usbRawBytesPerSec = 0.0,
    this.usbSerialThreadAlive,
    this.usbSerialState,
    this.usbEndpointInfo,
    this.usbBaudRate = 9600,
    this.usbLastSerialError,
    this.usbConfiguredHz = 1,
  });

  GpsDiagnosticsSnapshot copyWith({
    String? sourceName,
    GpsConnectionType? sourceType,
    GpsFixState? fixState,
    DateTime? subscriptionStartedAt,
    DateTime? firstRawDataAt,
    DateTime? firstValidPositionAt,
    double? lastLat,
    double? lastLng,
    double? lastAccuracyM,
    double? lastSpeedKmh,
    double? lastBearing,
    DateTime? lastPositionGpsTime,
    DateTime? lastPositionWallTime,
    double? hzInstantaneous,
    double? hzRollingAvg,
    List<NmeaLineDiag>? recentNmea,
    String? lastRmcStatus,
    GgaData? lastGga,
    int? nmeaReceived,
    int? nmeaDiscarded,
    double? nmeaLinesPerSec,
    int? usbRawBytesTotal,
    double? usbRawBytesPerSec,
    bool? usbSerialThreadAlive,
    String? usbSerialState,
    String? usbEndpointInfo,
    int? usbBaudRate,
    String? usbLastSerialError,
    int? usbConfiguredHz,
    // sentinel values for clearing nullable fields
    bool clearHzInstantaneous = false,
    bool clearHzRollingAvg = false,
    bool clearFirstRawDataAt = false,
    bool clearFirstValidPositionAt = false,
    bool clearLastRmcStatus = false,
    bool clearLastGga = false,
    bool clearNmeaLinesPerSec = false,
  }) {
    return GpsDiagnosticsSnapshot(
      sourceName: sourceName ?? this.sourceName,
      sourceType: sourceType ?? this.sourceType,
      fixState: fixState ?? this.fixState,
      subscriptionStartedAt:
          subscriptionStartedAt ?? this.subscriptionStartedAt,
      firstRawDataAt: clearFirstRawDataAt
          ? null
          : (firstRawDataAt ?? this.firstRawDataAt),
      firstValidPositionAt: clearFirstValidPositionAt
          ? null
          : (firstValidPositionAt ?? this.firstValidPositionAt),
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastAccuracyM: lastAccuracyM ?? this.lastAccuracyM,
      lastSpeedKmh: lastSpeedKmh ?? this.lastSpeedKmh,
      lastBearing: lastBearing ?? this.lastBearing,
      lastPositionGpsTime: lastPositionGpsTime ?? this.lastPositionGpsTime,
      lastPositionWallTime: lastPositionWallTime ?? this.lastPositionWallTime,
      hzInstantaneous: clearHzInstantaneous
          ? null
          : (hzInstantaneous ?? this.hzInstantaneous),
      hzRollingAvg:
          clearHzRollingAvg ? null : (hzRollingAvg ?? this.hzRollingAvg),
      recentNmea: recentNmea ?? this.recentNmea,
      lastRmcStatus:
          clearLastRmcStatus ? null : (lastRmcStatus ?? this.lastRmcStatus),
      lastGga: clearLastGga ? null : (lastGga ?? this.lastGga),
      nmeaReceived: nmeaReceived ?? this.nmeaReceived,
      nmeaDiscarded: nmeaDiscarded ?? this.nmeaDiscarded,
      nmeaLinesPerSec: clearNmeaLinesPerSec
          ? null
          : (nmeaLinesPerSec ?? this.nmeaLinesPerSec),
      usbRawBytesTotal: usbRawBytesTotal ?? this.usbRawBytesTotal,
      usbRawBytesPerSec: usbRawBytesPerSec ?? this.usbRawBytesPerSec,
      usbSerialThreadAlive: usbSerialThreadAlive ?? this.usbSerialThreadAlive,
      usbSerialState: usbSerialState ?? this.usbSerialState,
      usbEndpointInfo: usbEndpointInfo ?? this.usbEndpointInfo,
      usbBaudRate: usbBaudRate ?? this.usbBaudRate,
      usbLastSerialError: usbLastSerialError ?? this.usbLastSerialError,
      usbConfiguredHz: usbConfiguredHz ?? this.usbConfiguredHz,
    );
  }
}
