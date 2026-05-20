import 'package:geolocator/geolocator.dart';

/// Tipo de conexão do dispositivo GPS.
enum GpsConnectionType {
  internal,
  bluetooth,
  usb,
}

/// Informação sobre a fonte GPS — serializada em [RaceSessionRecord].
class GpsSourceInfo {
  final String name;
  final GpsConnectionType connectionType;

  const GpsSourceInfo({required this.name, required this.connectionType});

  /// Rótulo do badge exibido na UI (OK / BT / USB).
  String get badgeLabel => switch (connectionType) {
        GpsConnectionType.internal => 'OK',
        GpsConnectionType.bluetooth => 'BT',
        GpsConnectionType.usb => 'USB',
      };

  /// Cor ARGB do badge.
  int get badgeArgb => switch (connectionType) {
        GpsConnectionType.internal => 0xFF00E676,
        GpsConnectionType.bluetooth => 0xFF00B0FF,
        GpsConnectionType.usb => 0xFFFFD600,
      };

  bool get isExternal => connectionType != GpsConnectionType.internal;

  /// Texto de rodapé exibido na [RaceSummaryScreen].
  String get summaryLabel => switch (connectionType) {
        GpsConnectionType.internal =>
          'Cronometrado com GPS interno · Precisão típica: ±300–500ms',
        GpsConnectionType.bluetooth => 'Cronometrado com $name via BT',
        GpsConnectionType.usb => 'Cronometrado com $name via USB-C',
      };

  Map<String, dynamic> toJson() => {
        'name': name,
        'connectionType': connectionType.name,
      };

  factory GpsSourceInfo.fromJson(Map<String, dynamic> json) => GpsSourceInfo(
        name: json['name'] as String,
        connectionType: GpsConnectionType.values.firstWhere(
          (e) => e.name == json['connectionType'] as String,
          orElse: () => GpsConnectionType.internal,
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is GpsSourceInfo &&
      other.name == name &&
      other.connectionType == connectionType;

  @override
  int get hashCode => Object.hash(name, connectionType);

  @override
  String toString() => 'GpsSourceInfo(name: $name, type: ${connectionType.name})';
}

/// Contrato comum entre fontes GPS.
///
/// [InternalGpsService] e [ExternalGpsService] implementam esta interface.
/// O [LapDetector] e o restante do app são agnósticos à fonte ativa —
/// recebem apenas o [positionStream] exposto por esta interface.
abstract class GpsSource {
  /// Informação descritiva desta fonte.
  GpsSourceInfo get info;

  /// Stream de posições GPS desta fonte.
  ///
  /// [InternalGpsService]: aplica suavização e correções do GPS interno.
  /// [ExternalGpsService]: repassa os dados brutos do dispositivo sem modificação.
  Stream<Position> get positionStream;
}

/// Razão para a mudança de fonte GPS ativa.
enum GpsSourceChangeReason {
  /// Usuário escolheu uma nova fonte explicitamente.
  userChoice,

  /// Fonte externa desconectou — fallback automático para GPS interno.
  fallback,
}

/// Evento emitido pelo [GpsSourceManager] quando a fonte ativa muda.
class GpsSourceChangedEvent {
  final GpsSource source;
  final GpsSourceChangeReason reason;

  const GpsSourceChangedEvent({required this.source, required this.reason});
}
