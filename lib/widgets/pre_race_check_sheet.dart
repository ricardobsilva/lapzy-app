import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/track.dart';
import '../screens/race_screen.dart';
import '../services/gps_source_manager.dart';
import '../widgets/pressable.dart';

const _kBg = Color(0xFF141414);
const _kSurface = Color(0xFF1C1C1C);
const _kGreen = Color(0xFF00E676);
const _kRed = Color(0xFFFF3B30);
const _kYellow = Color(0xFFFFD600);

void showPreRaceCheckSheet(BuildContext context, Track track) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(140),
    builder: (_) => _PreRaceCheckSheet(track: track),
  );
}

class _PreRaceCheckSheet extends StatefulWidget {
  final Track track;

  const _PreRaceCheckSheet({required this.track});

  @override
  State<_PreRaceCheckSheet> createState() => _PreRaceCheckSheetState();
}

class _PreRaceCheckSheetState extends State<_PreRaceCheckSheet> {
  Timer? _pollTimer;

  bool? _serviceEnabled;
  LocationPermission? _permission;
  bool _receivingPositions = false;
  double? _accuracy;
  bool _hasStartFinish = false;
  int _sectorCount = 0;
  String _gpsSourceName = '';

  @override
  void initState() {
    super.initState();
    _hasStartFinish = widget.track.startFinishLine != null;
    _sectorCount = widget.track.sectorBoundaries.length;
    _gpsSourceName = GpsSourceManager.instance.activeSource.info.name;
    unawaited(_checkOnce());
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_checkOnce());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkOnce() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    final receiving = GpsSourceManager.instance.isReceivingPositions(maxAgeSeconds: 5);
    final last = GpsSourceManager.instance.lastPosition;
    final sourceName = GpsSourceManager.instance.activeSource.info.name;

    if (!mounted) return;
    setState(() {
      _serviceEnabled = serviceEnabled;
      _permission = permission;
      _receivingPositions = receiving;
      _accuracy = last?.accuracy;
      _gpsSourceName = sourceName;
    });
  }

  bool get _permissionOk =>
      _permission == LocationPermission.whileInUse ||
      _permission == LocationPermission.always;

  bool get _serviceOk => _serviceEnabled == true;

  bool get _criticalOk => _serviceOk && _permissionOk && _hasStartFinish;

  bool get _gpsSignalOk => _receivingPositions;

  bool get _accuracyOk => _accuracy != null && _accuracy! <= 20.0;

  void _startRace() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RaceScreen(track: widget.track),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      height: screenHeight * 0.72,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _DragHandle(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VERIFICAÇÃO PRÉ-CORRIDA',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white.withAlpha(89),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.track.name,
                  style: GoogleFonts.rajdhani(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _CheckGroup(
                    title: 'SISTEMA GPS',
                    items: [
                      _CheckItem(
                        label: 'Serviço de localização',
                        status: _serviceEnabled == null
                            ? _CheckStatus.loading
                            : _serviceEnabled!
                                ? _CheckStatus.ok
                                : _CheckStatus.fail,
                        detail: _serviceEnabled == false
                            ? 'Ative o GPS nas configurações do dispositivo'
                            : null,
                      ),
                      _CheckItem(
                        label: 'Permissão de localização',
                        status: _permission == null
                            ? _CheckStatus.loading
                            : _permissionOk
                                ? _CheckStatus.ok
                                : _CheckStatus.fail,
                        detail: _permission == LocationPermission.denied
                            ? 'Permissão negada — abra as configurações do app'
                            : _permission == LocationPermission.deniedForever
                                ? 'Permissão bloqueada — configure nas configurações do sistema'
                                : null,
                      ),
                      _CheckItem(
                        label: 'Sinal GPS',
                        status: _permission == null
                            ? _CheckStatus.loading
                            : !_permissionOk
                                ? _CheckStatus.fail
                                : _gpsSignalOk
                                    ? _CheckStatus.ok
                                    : _CheckStatus.warning,
                        detail: !_gpsSignalOk && _permissionOk
                            ? 'Aguardando sinal — vá para um local aberto'
                            : null,
                      ),
                      _CheckItem(
                        label: 'Precisão GPS',
                        status: _accuracy == null
                            ? (_permissionOk ? _CheckStatus.loading : _CheckStatus.fail)
                            : _accuracyOk
                                ? _CheckStatus.ok
                                : _CheckStatus.warning,
                        detail: _accuracy != null && !_accuracyOk
                            ? '${_accuracy!.toStringAsFixed(0)} m — ideal ≤ 20 m'
                            : _accuracy != null
                                ? '${_accuracy!.toStringAsFixed(0)} m'
                                : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CheckGroup(
                    title: 'CONFIGURAÇÃO DA PISTA',
                    items: [
                      _CheckItem(
                        label: 'Linha de largada/chegada',
                        status: _hasStartFinish ? _CheckStatus.ok : _CheckStatus.fail,
                        detail: !_hasStartFinish
                            ? 'Pista sem linha S/C — edite a pista antes de correr'
                            : null,
                      ),
                      _CheckItem(
                        label: 'Setores configurados',
                        status: _sectorCount > 0 ? _CheckStatus.ok : _CheckStatus.warning,
                        detail: _sectorCount == 0
                            ? 'Nenhum setor — tempos de setor não serão capturados'
                            : '$_sectorCount setor${_sectorCount > 1 ? 'es' : ''}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CheckGroup(
                    title: 'FONTE GPS',
                    items: [
                      _CheckItem(
                        label: 'Fonte ativa',
                        status: _CheckStatus.info,
                        detail: _gpsSourceName,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _StartButton(
              enabled: _criticalOk,
              hasWarnings: !_gpsSignalOk || !_accuracyOk || _sectorCount == 0,
              onStart: _startRace,
            ),
          ),
          SizedBox(height: bottomPad + 16),
        ],
      ),
    );
  }
}

enum _CheckStatus { loading, ok, warning, fail, info }

class _CheckGroup extends StatelessWidget {
  final String title;
  final List<_CheckItem> items;

  const _CheckGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(13), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: GoogleFonts.spaceMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white.withAlpha(89),
              ),
            ),
          ),
          Divider(color: Colors.white.withAlpha(13), height: 1),
          ...items.map((item) => item),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final _CheckStatus status;
  final String? detail;

  const _CheckItem({
    required this.label,
    required this.status,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _StatusIcon(status: status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(217),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      color: _detailColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _detailColor {
    return switch (status) {
      _CheckStatus.ok => Colors.white.withAlpha(89),
      _CheckStatus.warning => _kYellow.withAlpha(200),
      _CheckStatus.fail => _kRed.withAlpha(200),
      _CheckStatus.info => Colors.white.withAlpha(89),
      _CheckStatus.loading => Colors.white.withAlpha(89),
    };
  }
}

class _StatusIcon extends StatelessWidget {
  final _CheckStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == _CheckStatus.loading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white.withAlpha(89),
        ),
      );
    }

    final (icon, color) = switch (status) {
      _CheckStatus.ok => (Icons.check_circle, _kGreen),
      _CheckStatus.warning => (Icons.warning_rounded, _kYellow),
      _CheckStatus.fail => (Icons.cancel, _kRed),
      _CheckStatus.info => (Icons.info_outline, Colors.white.withAlpha(128)),
      _CheckStatus.loading => (Icons.circle_outlined, Colors.white.withAlpha(60)),
    };

    return Icon(icon, size: 20, color: color);
  }
}

class _StartButton extends StatelessWidget {
  final bool enabled;
  final bool hasWarnings;
  final VoidCallback onStart;

  const _StartButton({
    required this.enabled,
    required this.hasWarnings,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onStart : null,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? _kGreen : _kGreen.withAlpha(40),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'INICIAR CORRIDA',
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: enabled ? Colors.black : Colors.white.withAlpha(60),
                ),
              ),
              if (enabled && hasWarnings) ...[
                const SizedBox(height: 1),
                Text(
                  'atenção: há avisos ativos',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    color: Colors.black.withAlpha(140),
                  ),
                ),
              ],
              if (!enabled) ...[
                const SizedBox(height: 1),
                Text(
                  'resolva os erros acima para continuar',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    color: Colors.white.withAlpha(60),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 50,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
