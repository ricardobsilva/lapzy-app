import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/track.dart';
import '../repositories/track_repository.dart';
import 'race_screen.dart';
import 'track_creation_screen.dart';

const _kBg = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kGreen = Color(0xFF00E676);

const _kSectorColors = [
  Color(0xFF00B0FF),
  Color(0xFFFFD600),
  Color(0xFFFF6D00),
];

const _kMonths = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _formatDate(DateTime d) {
  final local = d.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = _kMonths[local.month - 1];
  final year = local.year;
  final hour = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$day $month $year · $hour:$min';
}

class TrackDetailScreen extends StatefulWidget {
  const TrackDetailScreen({super.key, required this.track});

  final Track track;

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  GoogleMapController? _mapController;
  double _cameraZoom = 17.0;
  double _cameraLat = -23.5505;

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};
    final sc = widget.track.startFinishLine;
    if (sc != null) {
      polylines.add(Polyline(
        polylineId: const PolylineId('sc_line'),
        points: sc.allPoints.map((p) => LatLng(p.lat, p.lng)).toList(),
        color: _kGreen,
        width: _metersToPixels(sc.widthMeters),
      ));
    }
    for (var i = 0; i < widget.track.sectorBoundaries.length; i++) {
      final b = widget.track.sectorBoundaries[i];
      polylines.add(Polyline(
        polylineId: PolylineId('sector_$i'),
        points: b.allPoints.map((p) => LatLng(p.lat, p.lng)).toList(),
        color: i < _kSectorColors.length
            ? _kSectorColors[i]
            : _generateSectorColor(i),
        width: _metersToPixels(b.widthMeters),
      ));
    }
    return polylines;
  }

  int _metersToPixels(double meters) {
    final latRad = _cameraLat * math.pi / 180;
    final metersPerPixel =
        156543.03392 * math.cos(latRad) / math.pow(2, _cameraZoom);
    return (meters / metersPerPixel).clamp(1.0, 100.0).round();
  }

  CameraPosition get _initialCamera {
    final sc = widget.track.startFinishLine;
    if (sc != null) {
      final mid = sc.midpoint;
      return CameraPosition(
        target: LatLng(mid.lat, mid.lng),
        zoom: 17,
      );
    }
    return const CameraPosition(
      target: LatLng(-23.5505, -46.6333),
      zoom: 15,
    );
  }

  void _onMapCreated(GoogleMapController c) {
    _mapController = c;
  }

  void _onCameraMove(CameraPosition pos) {
    _cameraZoom = pos.zoom;
    _cameraLat = pos.target.latitude;
  }

  void _onCameraIdle() {
    setState(() {});
  }

  void _navigateToEdit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TrackCreationScreen(initialTrack: widget.track),
      ),
    );
    if (saved == true && mounted) {
      _showPostEditSheet();
    }
  }

  void _showPostEditSheet() {
    final updatedTrack = TrackRepository().tracks.firstWhere(
      (t) => t.id == widget.track.id,
      orElse: () => widget.track,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: _kGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.black, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Traçado atualizado',
                    style: GoogleFonts.spaceMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: _PostEditButton(
                  label: 'INICIAR CORRIDA',
                  primary: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => RaceScreen(track: updatedTrack),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _PostEditButton(
                  label: 'IR PARA INÍCIO',
                  primary: false,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapHeight = MediaQuery.of(context).size.height * 0.54;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(trackName: widget.track.name),
            SizedBox(
              height: mapHeight,
              child: Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.hybrid,
                    initialCameraPosition: _initialCamera,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    polylines: _buildPolylines(),
                    onMapCreated: _onMapCreated,
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _BottomPanel(
                track: widget.track,
                onEdit: _navigateToEdit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String trackName;

  const _TopBar({required this.trackName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              key: const Key('detail_back_button'),
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                '‹',
                style: GoogleFonts.spaceMono(
                  fontSize: 24,
                  color: Colors.white.withAlpha(128),
                ),
              ),
            ),
          ),
          Text(
            trackName,
            key: const Key('detail_track_name'),
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withAlpha(230),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final Track track;
  final VoidCallback onEdit;

  const _BottomPanel({required this.track, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final n = track.sectorBoundaries.length;
    final createdAt = track.createdAt;

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: Colors.white.withAlpha(20))),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16, 18, 16,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track.name,
              key: const Key('detail_name'),
              style: GoogleFonts.spaceMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            if (createdAt != null)
              Text(
                _formatDate(createdAt),
                key: const Key('detail_date'),
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  color: Colors.white.withAlpha(89),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              n == 0
                  ? 'Sem setores configurados'
                  : '$n setor${n != 1 ? 'es' : ''} configurado${n != 1 ? 's' : ''}',
              key: const Key('detail_sectors'),
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                color: Colors.white.withAlpha(71),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _EditButton(onTap: onEdit),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('detail_edit_button'),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _kGreen.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kGreen.withAlpha(64), width: 1),
        ),
        child: Center(
          child: Text(
            'EDITAR',
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: _kGreen,
            ),
          ),
        ),
      ),
    );
  }
}

class _PostEditButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _PostEditButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: primary ? _kGreen.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primary ? _kGreen.withAlpha(64) : Colors.white.withAlpha(30),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: primary ? _kGreen : Colors.white.withAlpha(120),
            ),
          ),
        ),
      ),
    );
  }
}

Color _generateSectorColor(int index, {int seed = 42}) {
  final rng = math.Random(seed + index * 31337);
  return HSLColor.fromAHSL(1.0, rng.nextDouble() * 360, 0.85, 0.55).toColor();
}
