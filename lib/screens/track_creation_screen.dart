import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/track.dart';
import '../repositories/track_repository.dart';
import '../services/track_geometry.dart';

// ── MODO DE EDIÇÃO ────────────────────────────────────────────────────────────

enum TrackCreationMode { centerline, sc, s1, s2, s3 }

// ── CONSTANTES ────────────────────────────────────────────────────────────────

const _kSnapRadiusPx = 45.0;
const _kMinSectorMeters = 20.0;
const _kDefaultPosition = CameraPosition(
  target: LatLng(-23.5505, -46.6333), // São Paulo
  zoom: 15,
);

const _kSectorColors = {
  TrackCreationMode.s1: Color(0xFF00B0FF),
  TrackCreationMode.s2: Color(0xFFFFD600),
  TrackCreationMode.s3: Color(0xFFFF6D00),
};

// ── TELA PRINCIPAL ────────────────────────────────────────────────────────────

class TrackCreationScreen extends StatefulWidget {
  const TrackCreationScreen({super.key, this.mapBuilder});

  /// Substitui o GoogleMap — útil em widget tests.
  final Widget Function()? mapBuilder;

  @override
  State<TrackCreationScreen> createState() => _TrackCreationScreenState();
}

class _TrackCreationScreenState extends State<TrackCreationScreen> {
  final _nameController = TextEditingController();
  GoogleMapController? _mapController;

  // ── CENTERLINE ──────────────────────────────────────────────────────────────

  final List<GeoPoint> _centerline = [];
  List<double> _cumDist = [];
  double _totalLen = 0;
  bool _centerlineClosed = false;

  // Coordenadas de tela do centerline — atualizadas quando a câmera para.
  // Usadas para snap em pixels durante arraste de setor.
  List<Offset>? _screenCenterline;

  // ── START/FINISH ────────────────────────────────────────────────────────────

  double? _startFinishD;

  // ── SETORES ─────────────────────────────────────────────────────────────────

  Sector? _s1, _s2, _s3;

  // ── ESTADO DE GESTO ─────────────────────────────────────────────────────────

  TrackCreationMode _mode = TrackCreationMode.centerline;
  final List<double> _gestureDists = [];
  bool _isDrawing = false;

  // ── MAP ─────────────────────────────────────────────────────────────────────

  bool _isSatellite = false;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // ── LIFECYCLE ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── PERMISSÃO E LOCALIZAÇÃO ─────────────────────────────────────────────────

  Future<void> _centerToUserLocation() async {
    if (_mapController == null) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.best),
      );
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 18,
          ),
        ),
      );
    } catch (_) {
      // Localização indisponível — permanece na posição padrão
    }
  }

  // ── CAN SAVE ────────────────────────────────────────────────────────────────

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _centerlineClosed &&
      _startFinishD != null;

  // ── MAP CALLBACKS ────────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _centerToUserLocation();
  }

  void _onMapTap(LatLng latLng) {
    final gp = GeoPoint(latLng.latitude, latLng.longitude);

    switch (_mode) {
      case TrackCreationMode.centerline:
        setState(() {
          _centerline.add(gp);
          _updateOverlays();
        });
      case TrackCreationMode.sc:
        if (_centerlineClosed && _cumDist.isNotEmpty) {
          _snapAndSetStartFinish(gp);
        }
      case TrackCreationMode.s1:
      case TrackCreationMode.s2:
      case TrackCreationMode.s3:
        break; // controlado pelo GestureDetector
    }
  }

  void _onCameraIdle() {
    _refreshScreenCenterline();
  }

  // ── CENTERLINE ──────────────────────────────────────────────────────────────

  void _closeCenterline() {
    if (_centerline.length < 3) return;

    // Fecha o loop: adiciona trecho do último ponto ao primeiro
    final closedPath = [..._centerline, _centerline.first];
    final cumDist = TrackGeometry.buildCumDist(closedPath);
    final totalLen = cumDist.last;

    setState(() {
      _cumDist = cumDist;
      _totalLen = totalLen;
      _centerlineClosed = true;
      _mode = TrackCreationMode.sc;
      _updateOverlays();
    });

    _refreshScreenCenterline();
  }

  // ── START/FINISH ─────────────────────────────────────────────────────────────

  void _snapAndSetStartFinish(GeoPoint gp) {
    if (_centerline.isEmpty || _cumDist.isEmpty) return;

    final ref = _centerline.first;
    final projPath =
        _centerline.map((p) => TrackGeometry.projectToLocal(p, ref)).toList();
    final touch = TrackGeometry.projectToLocal(gp, ref);
    final snap = TrackGeometry.snapToDist(touch, projPath, _cumDist);

    setState(() {
      _startFinishD = snap.d;
      _updateOverlays();
    });
  }

  // ── TELA DE COORDENADAS ──────────────────────────────────────────────────────

  Future<void> _refreshScreenCenterline() async {
    if (_mapController == null || _centerline.isEmpty) return;
    final pts = <Offset>[];
    for (final gp in _centerline) {
      final sc = await _mapController!
          .getScreenCoordinate(LatLng(gp.lat, gp.lng));
      pts.add(Offset(sc.x.toDouble(), sc.y.toDouble()));
    }
    if (mounted) setState(() => _screenCenterline = pts);
  }

  // ── GESTURE DE SETOR ─────────────────────────────────────────────────────────

  void _onSectorDragStart(DragStartDetails details) {
    if (!_centerlineClosed || _screenCenterline == null) return;
    setState(() {
      _gestureDists.clear();
      _isDrawing = true;
    });
  }

  void _onSectorDragUpdate(DragUpdateDetails details) {
    if (!_isDrawing ||
        _screenCenterline == null ||
        _cumDist.isEmpty) {
      return;
    }

    final touch =
        Vec2(details.localPosition.dx, details.localPosition.dy);
    final projPath =
        _screenCenterline!.map((o) => Vec2(o.dx, o.dy)).toList();
    final snap = TrackGeometry.snapToDist(touch, projPath, _cumDist);

    if (snap.distFromPath > _kSnapRadiusPx) return; // muito longe da pista

    setState(() => _gestureDists.add(snap.d));
  }

  void _onSectorDragEnd(DragEndDetails _) {
    if (!_isDrawing) return;

    if (_gestureDists.isNotEmpty) {
      final interval =
          TrackGeometry.extractSectorInterval(_gestureDists, _totalLen);

      if (interval != null) {
        final color = _kSectorColors[_mode]!;
        final sector = Sector(
          id: _mode.name,
          dStart: interval.dStart,
          dEnd: interval.dEnd,
          colorValue: color.toARGB32(),
        );
        setState(() {
          switch (_mode) {
            case TrackCreationMode.s1:
              _s1 = sector;
            case TrackCreationMode.s2:
              _s2 = sector;
            case TrackCreationMode.s3:
              _s3 = sector;
            default:
              break;
          }
          _updateOverlays();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Setor muito curto — mínimo ${_kMinSectorMeters.toInt()} m',
              style:
                  GoogleFonts.spaceMono(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1C1C1C),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    setState(() {
      _gestureDists.clear();
      _isDrawing = false;
    });
  }

  // ── OVERLAYS DO MAPA ──────────────────────────────────────────────────────────

  void _updateOverlays() {
    final polylines = <Polyline>{};
    final markers = <Marker>{};

    // Centerline
    if (_centerline.isNotEmpty) {
      final pts = _centerline.map((p) => LatLng(p.lat, p.lng)).toList();
      if (_centerlineClosed) pts.add(pts.first);
      polylines.add(Polyline(
        polylineId: const PolylineId('centerline'),
        points: pts,
        color: Colors.white.withAlpha(153),
        width: 2,
        patterns: [],
      ));
    }

    // Linha de largada/chegada
    if (_startFinishD != null && _centerlineClosed) {
      final pathForCut = [..._centerline, _centerline.first];
      final (pA, pB) = TrackGeometry.cutLinePoints(
        _startFinishD!,
        pathForCut,
        _cumDist,
        _totalLen,
      );
      polylines.add(Polyline(
        polylineId: const PolylineId('sc_line'),
        points: [LatLng(pA.lat, pA.lng), LatLng(pB.lat, pB.lng)],
        color: Colors.white,
        width: 4,
      ));

      final center = TrackGeometry.pointAtDist(
        _startFinishD!,
        pathForCut,
        _cumDist,
        _totalLen,
      );
      markers.add(Marker(
        markerId: const MarkerId('sc'),
        position: LatLng(center.lat, center.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'S/C'),
      ));
    }

    // Setores
    final sectorMap = {
      TrackCreationMode.s1: _s1,
      TrackCreationMode.s2: _s2,
      TrackCreationMode.s3: _s3,
    };
    for (final entry in sectorMap.entries) {
      final sector = entry.value;
      if (sector == null) continue;

      final color = Color(sector.colorValue);
      final pathForSector = [..._centerline, _centerline.first];

      // Banda colorida ao longo do subpath
      final subPts = TrackGeometry.subpathPoints(
        sector.dStart,
        sector.dEnd,
        pathForSector,
        _cumDist,
        _totalLen,
      );
      if (subPts.isNotEmpty) {
        polylines.add(Polyline(
          polylineId: PolylineId('sector_${entry.key.name}'),
          points: subPts.map((p) => LatLng(p.lat, p.lng)).toList(),
          color: color,
          width: 7,
        ));
      }

      // Linha de corte no início do setor
      final (sA, sB) = TrackGeometry.cutLinePoints(
        sector.dStart,
        pathForSector,
        _cumDist,
        _totalLen,
      );
      polylines.add(Polyline(
        polylineId: PolylineId('cut_start_${entry.key.name}'),
        points: [LatLng(sA.lat, sA.lng), LatLng(sB.lat, sB.lng)],
        color: color,
        width: 3,
      ));

      // Linha de corte no fim do setor
      final (eA, eB) = TrackGeometry.cutLinePoints(
        sector.dEnd,
        pathForSector,
        _cumDist,
        _totalLen,
      );
      polylines.add(Polyline(
        polylineId: PolylineId('cut_end_${entry.key.name}'),
        points: [LatLng(eA.lat, eA.lng), LatLng(eB.lat, eB.lng)],
        color: color,
        width: 3,
      ));
    }

    _polylines = polylines;
    _markers = markers;
  }

  // ── SALVAR ────────────────────────────────────────────────────────────────────

  void _saveTrack() {
    if (!_canSave) return;

    final sectors = [_s1, _s2, _s3].whereType<Sector>().toList();
    final track = Track(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      centerline: List.from(_centerline),
      startFinishLine: StartFinishLine(d: _startFinishD!),
      sectors: sectors,
    );

    TrackRepository().add(track);
    Navigator.of(context).pop();
  }

  // ── HINT ─────────────────────────────────────────────────────────────────────

  String get _modeHint {
    switch (_mode) {
      case TrackCreationMode.centerline:
        if (_centerlineClosed) return '';
        if (_centerline.length < 3) return 'Toque no mapa para traçar a pista';
        return 'Toque em FECHAR para finalizar o traçado';
      case TrackCreationMode.sc:
        if (_startFinishD == null) return 'Toque na pista para definir a largada';
        return 'Largada definida — escolha setores ou salve';
      case TrackCreationMode.s1:
      case TrackCreationMode.s2:
      case TrackCreationMode.s3:
        if (!_centerlineClosed) return 'Trace a pista primeiro';
        return 'Arraste ao longo da pista para definir o setor';
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildMap(),
          if (_mode == TrackCreationMode.s1 ||
              _mode == TrackCreationMode.s2 ||
              _mode == TrackCreationMode.s3)
            _buildSectorGestureOverlay(),
          _buildTopBar(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (widget.mapBuilder != null) {
      return SizedBox.expand(child: widget.mapBuilder!());
    }

    return GoogleMap(
      initialCameraPosition: _kDefaultPosition,
      mapType: _isSatellite ? MapType.satellite : MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      // Gestos de câmera desabilitados no modo de setor para capturar o arraste
      scrollGesturesEnabled: _mode == TrackCreationMode.centerline ||
          _mode == TrackCreationMode.sc,
      zoomGesturesEnabled: _mode == TrackCreationMode.centerline ||
          _mode == TrackCreationMode.sc,
      polylines: _polylines,
      markers: _markers,
      onMapCreated: _onMapCreated,
      onTap: _onMapTap,
      onCameraIdle: _onCameraIdle,
    );
  }

  Widget _buildSectorGestureOverlay() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onSectorDragStart,
      onPanUpdate: _onSectorDragUpdate,
      onPanEnd: _onSectorDragEnd,
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _GlassButton(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _NameField(controller: _nameController)),
            const SizedBox(width: 10),
            _SaveButton(
              enabled: _canSave,
              onTap: _saveTrack,
            ),
            const SizedBox(width: 6),
            _GlassButton(
              onTap: () => setState(() => _isSatellite = !_isSatellite),
              child: Icon(
                _isSatellite
                    ? Icons.map_outlined
                    : Icons.satellite_alt_outlined,
                color: Colors.white.withAlpha(179),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withAlpha(204),
              Colors.transparent,
            ],
            stops: const [0.55, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeSelector(
              mode: _mode,
              centerlineClosed: _centerlineClosed,
              onModeChanged: (m) => setState(() => _mode = m),
            ),
            const SizedBox(height: 6),
            Text(
              _modeHint,
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                color: Colors.white.withAlpha(115),
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            if (_mode == TrackCreationMode.centerline &&
                _centerline.length >= 3 &&
                !_centerlineClosed) ...[
              const SizedBox(height: 12),
              _CloseTrackButton(onTap: _closeCenterline),
            ],
          ],
        ),
      ),
    );
  }
}

// ── NOME DA PISTA ──────────────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(153),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: TextField(
        key: const Key('track_name_field'),
        controller: controller,
        style: GoogleFonts.spaceMono(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'Nome da pista',
          hintStyle: GoogleFonts.spaceMono(
            fontSize: 14,
            color: Colors.white.withAlpha(77),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: InputBorder.none,
        ),
        cursorColor: const Color(0xFF00E676),
      ),
    );
  }
}

// ── BOTÃO SALVAR ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GlassButton(
      onTap: enabled ? onTap : null,
      child: Text(
        'SALVAR',
        key: const Key('save_button'),
        style: GoogleFonts.spaceMono(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: enabled
              ? const Color(0xFF00E676)
              : Colors.white.withAlpha(77),
        ),
      ),
    );
  }
}

// ── BOTÃO DE VIDRO (TOP BAR) ──────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(153),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(26)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── SELETOR DE MODO ───────────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.centerlineClosed,
    required this.onModeChanged,
  });

  final TrackCreationMode mode;
  final bool centerlineClosed;
  final ValueChanged<TrackCreationMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(153),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Row(
        children: [
          _ModeTab(
            label: 'TRILHA',
            active: mode == TrackCreationMode.centerline,
            onTap: () => onModeChanged(TrackCreationMode.centerline),
          ),
          _VerticalDivider(),
          _ModeTab(
            label: 'S/C',
            active: mode == TrackCreationMode.sc,
            enabled: centerlineClosed,
            onTap: centerlineClosed
                ? () => onModeChanged(TrackCreationMode.sc)
                : null,
          ),
          _VerticalDivider(),
          _ModeTab(
            label: 'S1',
            active: mode == TrackCreationMode.s1,
            enabled: centerlineClosed,
            color: _kSectorColors[TrackCreationMode.s1]!,
            onTap: centerlineClosed
                ? () => onModeChanged(TrackCreationMode.s1)
                : null,
          ),
          _VerticalDivider(),
          _ModeTab(
            label: 'S2',
            active: mode == TrackCreationMode.s2,
            enabled: centerlineClosed,
            color: _kSectorColors[TrackCreationMode.s2]!,
            onTap: centerlineClosed
                ? () => onModeChanged(TrackCreationMode.s2)
                : null,
          ),
          _VerticalDivider(),
          _ModeTab(
            label: 'S3',
            active: mode == TrackCreationMode.s3,
            enabled: centerlineClosed,
            color: _kSectorColors[TrackCreationMode.s3]!,
            onTap: centerlineClosed
                ? () => onModeChanged(TrackCreationMode.s3)
                : null,
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withAlpha(20),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.active,
    this.enabled = true,
    this.color,
    this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = active
        ? (color ?? Colors.white)
        : enabled
            ? Colors.white.withAlpha(128)
            : Colors.white.withAlpha(38);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: active
                ? (color ?? Colors.white).withAlpha(26)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400,
                color: effectiveColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── BOTÃO FECHAR PISTA ────────────────────────────────────────────────────────

class _CloseTrackButton extends StatelessWidget {
  const _CloseTrackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withAlpha(26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF00E676).withAlpha(102),
          ),
        ),
        child: Center(
          child: Text(
            'FECHAR PISTA',
            key: const Key('close_track_button'),
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: const Color(0xFF00E676),
            ),
          ),
        ),
      ),
    );
  }
}

// ── HELPER DE TAMANHO VISUAL PARA CORTE ───────────────────────────────────────

/// Retorna o comprimento visual em tela de um setor (para feedback em debug).
/// Não usado em produção — apenas utilitário.
double sectorLengthMeters(Sector sector, double totalLen) {
  return ((sector.dEnd - sector.dStart) + totalLen) % totalLen;
}

/// Gera uma cor aleatória para S4+ com boa legibilidade sobre fundo escuro.
Color generateSectorColor(int sectorIndex, {int seed = 42}) {
  final rng = math.Random(seed + sectorIndex * 31337);
  // Mantém saturação alta e luminosidade média para legibilidade
  final hue = rng.nextDouble() * 360;
  return HSLColor.fromAHSL(1.0, hue, 0.85, 0.55).toColor();
}
