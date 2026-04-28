import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/track.dart';
import '../repositories/track_repository.dart';
import '../services/track_geometry.dart';

// ── CONSTANTES ────────────────────────────────────────────────────────────────

const _kDefaultPosition = CameraPosition(
  target: LatLng(-23.5505, -46.6333),
  zoom: 15,
);
const _kGreen = Color(0xFF00E676);
const _kSurface = Color(0xFF141414);

const _kSectorColors = [
  Color(0xFF00B0FF), // S1
  Color(0xFFFFD600), // S2
  Color(0xFFFF6D00), // S3
];

const _kNodeLabels = ['S/C', 'S', 'N', '✓'];
const _kStepLabels = ['LARGADA', 'SETORES', 'NOME', 'SALVAR'];

const _kMapHeightFraction = 0.54;
const _kMinWidthM = 3.0;
const _kMaxWidthM = 30.0;

// Distância mínima em pixels lógicos entre pontos capturados durante o gesto.
// Reduz a quantidade de chamadas getLatLng sem perder fidelidade da curva.
const _kPointSpacingPx = 10.0;

// ── TELA PRINCIPAL ────────────────────────────────────────────────────────────

class TrackCreationScreen extends StatefulWidget {
  const TrackCreationScreen({super.key, this.mapBuilder, this.initialStep = 0});

  final Widget Function()? mapBuilder;
  final int initialStep;

  @override
  State<TrackCreationScreen> createState() => _TrackCreationScreenState();
}

class _TrackCreationScreenState extends State<TrackCreationScreen> {
  late int _step;

  final _nameController = TextEditingController();
  GoogleMapController? _mapController;

  // ── LARGADA ──────────────────────────────────────────────────────────────────

  TrackLine? _startFinishLine;

  // Pontos do gesto em pixels lógicos (para o painter em tempo real)
  List<Offset> _scDrawPoints = [];

  // ── SETORES ──────────────────────────────────────────────────────────────────

  final List<TrackLine> _sectorBoundaries = [];

  List<Offset> _sectorDrawPoints = [];
  bool _isDrawing = false;

  // ── MODO / MAPA / BUSCA ──────────────────────────────────────────────────────

  bool _isDrawMode = false;
  Set<Polyline> _polylines = {};
  MapType _mapType = MapType.hybrid;

  // Zoom e latitude atuais da câmera — usados para converter metros → pixels.
  // Inicializados com os valores de _kDefaultPosition.
  double _cameraZoom = 15.0;
  double _cameraLat = -23.5505;

  bool _showSearch = false;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  // ── LIFECYCLE ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, 3);
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── CONDIÇÕES ─────────────────────────────────────────────────────────────────

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _startFinishLine != null;

  // ── MAP ───────────────────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController c) {
    _mapController = c;
    _centerToUserLocation();
  }

  // Salva zoom/lat sem setState — evita rebuild a cada frame do gesto.
  void _onCameraMove(CameraPosition pos) {
    _cameraZoom = pos.zoom;
    _cameraLat = pos.target.latitude;
  }

  // Ao parar o gesto, reconstrói as polylines com a largura correta.
  void _onCameraIdle() {
    if (_startFinishLine != null || _sectorBoundaries.isNotEmpty) {
      setState(() => _updateOverlays());
    }
  }

  Future<void> _centerToUserLocation() async {
    if (_mapController == null) return;
    // Se já há uma linha configurada, não sobrepõe a posição atual do mapa.
    if (_startFinishLine != null) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.best),
      );
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 18),
        ),
      );
    } catch (_) {}
  }

  // ── GESTO — S/C ──────────────────────────────────────────────────────────────

  void _onSCDragStart(DragStartDetails d) {
    setState(() => _scDrawPoints = [d.localPosition]);
  }

  void _onSCDragUpdate(DragUpdateDetails d) {
    if (_scDrawPoints.isEmpty) return;
    if ((d.localPosition - _scDrawPoints.last).distance < _kPointSpacingPx) return;
    setState(() => _scDrawPoints.add(d.localPosition));
  }

  void _onSCDragEnd(DragEndDetails _) {
    final pts = List<Offset>.from(_scDrawPoints);
    if (pts.length >= 2 && (pts.last - pts.first).distance > 12) {
      final ratio = MediaQuery.of(context).devicePixelRatio;
      _confirmSC(pts, ratio);
    }
    setState(() => _scDrawPoints = []);
  }

  Future<void> _confirmSC(List<Offset> screenPts, double pixelRatio) async {
    if (_mapController == null) return;
    try {
      final latLngs = await Future.wait(
        screenPts.map(
          (p) => _mapController!.getLatLng(
            ScreenCoordinate(
              x: (p.dx * pixelRatio).round(),
              y: (p.dy * pixelRatio).round(),
            ),
          ),
        ),
      );
      if (!mounted) return;
      final geo = latLngs.map((ll) => GeoPoint(ll.latitude, ll.longitude)).toList();
      setState(() {
        _startFinishLine = TrackLine(
          a: geo.first,
          b: geo.last,
          middlePoints: geo.length > 2 ? geo.sublist(1, geo.length - 1) : const [],
          widthMeters: _startFinishLine?.widthMeters ?? 6.0,
        );
        _updateOverlays();
      });
    } catch (_) {}
  }

  // ── GESTO — SETOR ─────────────────────────────────────────────────────────────

  void _onSectorDragStart(DragStartDetails d) {
    setState(() {
      _sectorDrawPoints = [d.localPosition];
      _isDrawing = true;
    });
  }

  void _onSectorDragUpdate(DragUpdateDetails d) {
    if (!_isDrawing || _sectorDrawPoints.isEmpty) return;
    if ((d.localPosition - _sectorDrawPoints.last).distance < _kPointSpacingPx) return;
    setState(() => _sectorDrawPoints.add(d.localPosition));
  }

  void _onSectorDragEnd(DragEndDetails _) {
    final pts = List<Offset>.from(_sectorDrawPoints);
    if (pts.length >= 2 && (pts.last - pts.first).distance > 12) {
      final ratio = MediaQuery.of(context).devicePixelRatio;
      _addSectorBoundary(pts, ratio);
    }
    setState(() {
      _sectorDrawPoints = [];
      _isDrawing = false;
    });
  }

  Future<void> _addSectorBoundary(List<Offset> screenPts, double pixelRatio) async {
    if (_mapController == null) return;
    try {
      final latLngs = await Future.wait(
        screenPts.map(
          (p) => _mapController!.getLatLng(
            ScreenCoordinate(
              x: (p.dx * pixelRatio).round(),
              y: (p.dy * pixelRatio).round(),
            ),
          ),
        ),
      );
      if (!mounted) return;
      final geo = latLngs.map((ll) => GeoPoint(ll.latitude, ll.longitude)).toList();
      setState(() {
        _sectorBoundaries.add(TrackLine(
          a: geo.first,
          b: geo.last,
          middlePoints: geo.length > 2 ? geo.sublist(1, geo.length - 1) : const [],
        ));
        _updateOverlays();
      });
    } catch (_) {}
  }

  void _removeSectorBoundary(int index) {
    setState(() {
      _sectorBoundaries.removeAt(index);
      _updateOverlays();
    });
  }

  // ── LARGURA DAS LINHAS ────────────────────────────────────────────────────────

  void _updateSCWidth(double w) {
    if (_startFinishLine == null) return;
    setState(() {
      _startFinishLine = TrackLine(
        a: _startFinishLine!.a,
        b: _startFinishLine!.b,
        middlePoints: _startFinishLine!.middlePoints,
        widthMeters: w.clamp(_kMinWidthM, _kMaxWidthM),
      );
      _updateOverlays();
    });
  }

  void _updateSectorWidth(int index, double w) {
    setState(() {
      final old = _sectorBoundaries[index];
      _sectorBoundaries[index] = TrackLine(
        a: old.a,
        b: old.b,
        middlePoints: old.middlePoints,
        widthMeters: w.clamp(_kMinWidthM, _kMaxWidthM),
      );
      _updateOverlays();
    });
  }

  // ── BUSCA ─────────────────────────────────────────────────────────────────────

  Future<void> _searchAndFly(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final locs = await locationFromAddress(query.trim());
      if (locs.isEmpty || !mounted) return;
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(locs.first.latitude, locs.first.longitude),
            zoom: 17,
          ),
        ),
      );
      if (mounted) {
        setState(() {
          _showSearch = false;
          _searchController.clear();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── OVERLAYS ──────────────────────────────────────────────────────────────────

  void _updateOverlays() {
    final polylines = <Polyline>{};

    if (_startFinishLine != null) {
      final sc = _startFinishLine!;
      polylines.add(Polyline(
        polylineId: const PolylineId('sc_line'),
        points: sc.allPoints.map((p) => LatLng(p.lat, p.lng)).toList(),
        color: _kGreen,
        width: _metersToPixels(sc.widthMeters),
      ));
    }

    for (var i = 0; i < _sectorBoundaries.length; i++) {
      final b = _sectorBoundaries[i];
      polylines.add(Polyline(
        polylineId: PolylineId('sector_$i'),
        points: b.allPoints.map((p) => LatLng(p.lat, p.lng)).toList(),
        color: _sectorColor(i),
        width: _metersToPixels(b.widthMeters),
      ));
    }

    _polylines = polylines;
  }

  /// Converte metros → pixels lógicos de polyline para o zoom e latitude atuais.
  ///
  /// Fórmula: metersPerPixel = 156543 * cos(lat) / 2^zoom
  /// Isso mantém a largura física constante independente do zoom.
  int _metersToPixels(double meters) {
    final latRad = _cameraLat * math.pi / 180;
    final metersPerPixel =
        156543.03392 * math.cos(latRad) / math.pow(2, _cameraZoom);
    return (meters / metersPerPixel).clamp(1.0, 100.0).round();
  }

  Color _sectorColor(int index) {
    if (index < _kSectorColors.length) return _kSectorColors[index];
    return _generateSectorColor(index);
  }

  // ── NAVEGAÇÃO DO WIZARD ───────────────────────────────────────────────────────

  void _goStep(int n) {
    setState(() {
      _step = n.clamp(0, 3);
      _isDrawMode = false;
    });
    // No step de confirmação, centraliza o mapa na linha de largada/chegada.
    if (n == 3) _flyToTrack();
  }

  Future<void> _flyToTrack() async {
    if (_mapController == null || _startFinishLine == null) return;
    final mid = _startFinishLine!.midpoint;
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(mid.lat, mid.lng), zoom: 17),
      ),
    );
  }

  // ── SALVAR ────────────────────────────────────────────────────────────────────

  void _saveTrack() {
    if (!_canSave) return;
    final now = DateTime.now();
    final track = Track(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      startFinishLine: _startFinishLine,
      sectorBoundaries: List.from(_sectorBoundaries),
      createdAt: now,
      updatedAt: now,
    );
    unawaited(TrackRepository().save(track));
    _goStep(3);
  }

  // ── HINT ──────────────────────────────────────────────────────────────────────

  String get _mapHint {
    switch (_step) {
      case 0:
        return _startFinishLine == null
            ? 'Arraste para marcar a largada'
            : 'Arraste para reposicionar a largada';
      case 1:
        return 'Arraste no mapa para definir fronteira de setor';
      default:
        return '';
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inDrawableStep = _step == 0 || _step == 1;
    final scGestureActive = _step == 0 && _isDrawMode;
    final sectorGestureActive = _step == 1 && _isDrawMode;
    final mapGesturesEnabled = !_isDrawMode || _step >= 2;

    // No step 2, quando o teclado abre: usa Offstage para ocultar o mapa sem
    // removê-lo do widget tree (a Platform View permanece viva, evitando
    // _onMapCreated disparar de novo). O Padding reserva a altura do teclado.
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = _step == 2 && keyboardHeight > 0;
    final mapHeight = MediaQuery.of(context).size.height * _kMapHeightFraction;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardOpen ? keyboardHeight : 0),
          child: Column(
            children: [
              _ProgBar(step: _step, onJumpTo: _goStep),
              // Offstage mantém o widget vivo mas remove do layout —
              // o mapa não é recriado quando o teclado abre/fecha.
              Offstage(
                offstage: keyboardOpen,
                child: SizedBox(
                  height: mapHeight,
                  child: Stack(
                    children: [
                      _buildMap(mapGesturesEnabled),
                      if (scGestureActive) _buildSCOverlay(),
                      if (sectorGestureActive) _buildSectorOverlay(),
                      if (scGestureActive && _scDrawPoints.length >= 2)
                        _PathPainter(points: _scDrawPoints, color: _kGreen),
                      if (sectorGestureActive && _sectorDrawPoints.length >= 2)
                        _PathPainter(
                          points: _sectorDrawPoints,
                          color: _sectorColor(_sectorBoundaries.length),
                        ),
                      if (_mapHint.isNotEmpty && _isDrawMode)
                        _MapHint(text: _mapHint),
                      _buildBackButton(),
                      _buildSearchOverlay(),
                      _buildMapTypeToggle(
                        bottom: inDrawableStep ? 56 : 12,
                      ),
                      if (inDrawableStep) _buildDrawModeToggle(),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildBottomPanel()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(bool gesturesEnabled) {
    if (widget.mapBuilder != null) {
      return SizedBox.expand(child: widget.mapBuilder!());
    }
    return GoogleMap(
      mapType: _mapType,
      initialCameraPosition: _kDefaultPosition,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      scrollGesturesEnabled: gesturesEnabled,
      zoomGesturesEnabled: gesturesEnabled,
      polylines: _polylines,
      onMapCreated: _onMapCreated,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
    );
  }

  Widget _buildSCOverlay() => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onSCDragStart,
        onPanUpdate: _onSCDragUpdate,
        onPanEnd: _onSCDragEnd,
      );

  Widget _buildSectorOverlay() => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onSectorDragStart,
        onPanUpdate: _onSectorDragUpdate,
        onPanEnd: _onSectorDragEnd,
      );

  Widget _buildBackButton() => Positioned(
        top: 12,
        left: 12,
        child: _GlassButton(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      );

  Widget _buildSearchOverlay() {
    if (!_showSearch) {
      return Positioned(
        top: 12,
        right: 12,
        child: _GlassButton(
          key: const Key('search_button'),
          onTap: () => setState(() {
            _showSearch = true;
            _searchController.clear();
          }),
          child: const Icon(Icons.search, color: Colors.white, size: 20),
        ),
      );
    }
    return Positioned(
      top: 12,
      left: 64,
      right: 12,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(220),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('search_field'),
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.spaceMono(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar kartódromo...',
                  hintStyle: GoogleFonts.spaceMono(
                    fontSize: 12,
                    color: Colors.white.withAlpha(71),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _searchAndFly,
              ),
            ),
            const SizedBox(width: 6),
            if (_isSearching)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
              )
            else
              GestureDetector(
                onTap: () => setState(() => _showSearch = false),
                child: Icon(Icons.close, color: Colors.white.withAlpha(128), size: 18),
              ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeToggle({required double bottom}) {
    final isSat = _mapType == MapType.hybrid;
    return Positioned(
      bottom: bottom,
      right: 12,
      child: GestureDetector(
        key: const Key('map_type_toggle'),
        onTap: () => setState(
          () => _mapType = isSat ? MapType.normal : MapType.hybrid,
        ),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(180),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSat ? _kGreen : Colors.white.withAlpha(40),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.satellite_alt,
            color: isSat ? _kGreen : Colors.white.withAlpha(128),
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawModeToggle() => Positioned(
        bottom: 12,
        right: 12,
        child: GestureDetector(
          onTap: () => setState(() => _isDrawMode = !_isDrawMode),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _isDrawMode ? Colors.black.withAlpha(180) : _kGreen,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kGreen, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isDrawMode ? Icons.open_with : Icons.edit,
                  color: _isDrawMode ? _kGreen : Colors.black,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  _isDrawMode ? 'MOVER' : 'TRAÇAR',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: _isDrawMode ? _kGreen : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  // ── PAINEL INFERIOR ───────────────────────────────────────────────────────────

  Widget _buildBottomPanel() => Container(
        decoration: BoxDecoration(
          color: _kSurface,
          border: Border(top: BorderSide(color: Colors.white.withAlpha(20))),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16, 14, 16,
            MediaQuery.of(context).padding.bottom + 14,
          ),
          child: switch (_step) {
            0 => _buildPanel0(),
            1 => _buildPanel1(),
            2 => _buildPanel2(),
            _ => _buildPanel3(),
          },
        ),
      );

  Widget _buildPanel0() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle('Largada / Chegada'),
          const SizedBox(height: 4),
          _panelDesc('Arraste um traço no mapa para marcar a linha de largada.'),
          if (_startFinishLine != null) ...[
            const SizedBox(height: 10),
            _WidthRow(
              label: 'Largura da linha',
              widthMeters: _startFinishLine!.widthMeters,
              onChanged: _updateSCWidth,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(),
              _ActionButton(
                label: 'Confirmar →',
                enabled: _startFinishLine != null,
                onTap: () => _goStep(1),
              ),
            ],
          ),
        ],
      );

  Widget _buildPanel1() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _panelTitle('Setores'),
              const SizedBox(width: 6),
              Text(
                '(opcional)',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  color: Colors.white.withAlpha(71),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _panelDesc('Arraste no mapa para definir fronteiras de setor.'),
          const SizedBox(height: 8),
          if (_sectorBoundaries.isEmpty)
            Text(
              'Nenhum setor ainda.',
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                color: Colors.white.withAlpha(71),
              ),
            )
          else
            ...List.generate(
              _sectorBoundaries.length,
              (i) => _SectorItem(
                index: i,
                color: _sectorColor(i),
                sectorLength: _sectorLengthMeters(i),
                widthMeters: _sectorBoundaries[i].widthMeters,
                onDelete: () => _removeSectorBoundary(i),
                onWidthChanged: (w) => _updateSectorWidth(i, w),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(),
              _ActionButton(
                label: 'Continuar →',
                enabled: true,
                onTap: () => _goStep(2),
              ),
            ],
          ),
        ],
      );

  Widget _buildPanel2() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle('Nome da pista'),
          const SizedBox(height: 10),
          _NameField(controller: _nameController),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionButton(
                label: '← Voltar',
                enabled: true,
                ghost: true,
                onTap: () => _goStep(1),
              ),
              const Spacer(),
              _SaveButton(enabled: _canSave, onTap: _saveTrack),
            ],
          ),
        ],
      );

  Widget _buildPanel3() {
    final n = _sectorBoundaries.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.black, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameController.text.trim(),
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Linha de chegada · $n setor${n != 1 ? 'es' : ''}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      color: Colors.white.withAlpha(71),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _ActionButton(
            label: 'CONCLUIR →',
            enabled: true,
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ),
      ],
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────────

  Widget _panelTitle(String t) => Text(
        t,
        style: GoogleFonts.rajdhani(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.white.withAlpha(128),
        ),
      );

  Widget _panelDesc(String t) => Text(
        t,
        style: GoogleFonts.spaceMono(
          fontSize: 12,
          color: Colors.white.withAlpha(71),
          height: 1.5,
        ),
      );

  double? _sectorLengthMeters(int index) {
    if (_startFinishLine == null) return null;
    final prevMid = index == 0
        ? _startFinishLine!.midpoint
        : _sectorBoundaries[index - 1].midpoint;
    return TrackGeometry.haversine(prevMid, _sectorBoundaries[index].midpoint);
  }
}

// ── BARRA DE PROGRESSO ────────────────────────────────────────────────────────

class _ProgBar extends StatelessWidget {
  const _ProgBar({required this.step, required this.onJumpTo});
  final int step;
  final void Function(int) onJumpTo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(20))),
      ),
      child: Row(
        children: List.generate(7, (i) {
          if (i.isOdd) {
            final li = i ~/ 2;
            return Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: li < step
                    ? _kGreen.withAlpha(102)
                    : Colors.white.withAlpha(20),
              ),
            );
          }
          final ni = i ~/ 2;
          final done = ni < step;
          final active = ni == step;
          return GestureDetector(
            onTap: (done || active) ? () => onJumpTo(ni) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? _kGreen
                        : done
                            ? _kGreen.withAlpha(38)
                            : const Color(0xFF1C1C1C),
                    border: Border.all(
                      color: active
                          ? _kGreen
                          : done
                              ? _kGreen.withAlpha(128)
                              : Colors.white.withAlpha(26),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      done ? '✓' : _kNodeLabels[ni],
                      style: GoogleFonts.spaceMono(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? Colors.black
                            : done
                                ? _kGreen
                                : Colors.white.withAlpha(71),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _kStepLabels[ni],
                  style: GoogleFonts.spaceMono(
                    fontSize: 8,
                    letterSpacing: 0.4,
                    color: (active || done)
                        ? Colors.white.withAlpha(128)
                        : Colors.white.withAlpha(71),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── HINT DO MAPA ──────────────────────────────────────────────────────────────

class _MapHint extends StatelessWidget {
  const _MapHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(199),
            border: Border.all(color: Colors.white.withAlpha(30)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              color: Colors.white.withAlpha(128),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── BOTÃO GLASS ───────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
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

// ── PAINTER DE TRAÇADO (multi-ponto) ─────────────────────────────────────────

class _PathPainter extends StatelessWidget {
  const _PathPainter({required this.points, required this.color});
  final List<Offset> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PathPainterDelegate(points: points, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _PathPainterDelegate extends CustomPainter {
  const _PathPainterDelegate({required this.points, required this.color});
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PathPainterDelegate old) =>
      old.points.length != points.length || old.color != color;
}

// ── CONTROLE DE LARGURA ───────────────────────────────────────────────────────

class _WidthRow extends StatelessWidget {
  const _WidthRow({
    required this.label,
    required this.widthMeters,
    required this.onChanged,
  });
  final String label;
  final double widthMeters;
  final void Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    final w = widthMeters.round();
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 11,
            color: Colors.white.withAlpha(71),
          ),
        ),
        const SizedBox(width: 10),
        _StepButton(
          label: '−',
          enabled: w > _kMinWidthM,
          onTap: () => onChanged((w - 1).toDouble()),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '$w m',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withAlpha(128),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StepButton(
          label: '+',
          enabled: w < _kMaxWidthM,
          onTap: () => onChanged((w + 1).toDouble()),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.white.withAlpha(enabled ? 40 : 15)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: enabled ? Colors.white : Colors.white.withAlpha(51),
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── CAMPO DE NOME ─────────────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: TextField(
        key: const Key('track_name_field'),
        controller: controller,
        style: GoogleFonts.spaceMono(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Nome da pista',
          hintStyle: GoogleFonts.spaceMono(
            fontSize: 14,
            color: Colors.white.withAlpha(71),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: InputBorder.none,
        ),
        cursorColor: _kGreen,
      ),
    );
  }
}

// ── BOTÃO SALVAR ──────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: enabled ? _kGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? _kGreen : Colors.white.withAlpha(20),
          ),
        ),
        child: Center(
          child: Text(
            'Salvar →',
            key: const Key('save_button'),
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: enabled ? Colors.black : Colors.white.withAlpha(77),
            ),
          ),
        ),
      ),
    );
  }
}

// ── ITEM DE SETOR ─────────────────────────────────────────────────────────────

class _SectorItem extends StatelessWidget {
  const _SectorItem({
    required this.index,
    required this.color,
    required this.onDelete,
    required this.widthMeters,
    required this.onWidthChanged,
    this.sectorLength,
  });
  final int index;
  final Color color;
  final VoidCallback onDelete;
  final double widthMeters;
  final void Function(double) onWidthChanged;
  final double? sectorLength;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'S${index + 1}',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    color: Colors.white.withAlpha(128),
                  ),
                ),
              ),
              if (sectorLength != null)
                Text(
                  '~${sectorLength!.round()} m',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    color: Colors.white.withAlpha(71),
                  ),
                ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDelete,
                child: Text(
                  '✕',
                  style: TextStyle(color: Colors.red.withAlpha(102), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _WidthRow(
            label: 'Largura',
            widthMeters: widthMeters,
            onChanged: onWidthChanged,
          ),
        ],
      ),
    );
  }
}

// ── BOTÃO DE AÇÃO ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.ghost = false,
  });
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final bg = ghost
        ? Colors.transparent
        : enabled
            ? _kGreen
            : _kGreen.withAlpha(51);
    final fg = ghost
        ? Colors.white.withAlpha(128)
        : enabled
            ? Colors.black
            : Colors.black.withAlpha(128);
    final border = ghost
        ? Colors.white.withAlpha(20)
        : enabled
            ? _kGreen
            : _kGreen.withAlpha(51);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

// ── UTILITÁRIOS ───────────────────────────────────────────────────────────────

Color _generateSectorColor(int index, {int seed = 42}) {
  final rng = math.Random(seed + index * 31337);
  return HSLColor.fromAHSL(1.0, rng.nextDouble() * 360, 0.85, 0.55).toColor();
}
