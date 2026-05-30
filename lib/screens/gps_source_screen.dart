import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/bluetooth_gps_scanner.dart';
import '../services/gps_source.dart';
import '../services/gps_source_manager.dart';
import '../services/internal_gps_service.dart';
import '../services/external_gps_service.dart';
import '../services/usb_gps_detector.dart';
import '../widgets/pressable.dart';
import 'gps_diagnostics_screen.dart';

const _kBg = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kSurface2 = Color(0xFF1C1C1C);
const _kDivider = Color(0xFF1A1A1A);
const _kGreen = Color(0xFF00E676);

class GpsSourceScreen extends StatefulWidget {
  /// Manager injetável para testes.
  final GpsSourceManager? manager;

  /// Fábrica de scanner BT — injetável para testes.
  final Stream<List<ExternalGpsService>> Function()? btScannerFactory;

  /// Fábrica de detector USB — injetável para testes.
  final Stream<ExternalGpsService?> Function()? usbDetectorFactory;

  const GpsSourceScreen({
    super.key,
    this.manager,
    this.btScannerFactory,
    this.usbDetectorFactory,
  });

  @override
  State<GpsSourceScreen> createState() => _GpsSourceScreenState();
}

class _GpsSourceScreenState extends State<GpsSourceScreen> {
  late final GpsSourceManager _manager;
  late GpsSource _selectedSource;
  List<ExternalGpsService> _btDevices = [];
  bool _scanning = true;
  StreamSubscription<List<ExternalGpsService>>? _btSub;
  ExternalGpsService? _usbDevice;
  StreamSubscription<ExternalGpsService?>? _usbSub;
  StreamSubscription<GpsSourceChangedEvent>? _managerSub;

  @override
  void initState() {
    super.initState();
    _manager = widget.manager ?? GpsSourceManager.instance;
    _selectedSource = _manager.activeSource;
    _subscribeToManagerEvents();
    _startBtScan();
    _startUsbMonitor();
  }

  @override
  void dispose() {
    _stopBtScan();
    _usbSub?.cancel();
    _managerSub?.cancel();
    super.dispose();
  }

  void _subscribeToManagerEvents() {
    _managerSub = _manager.events.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event.reason == GpsSourceChangeReason.fallback) {
          _selectedSource = event.source;
        }
      });
    });
  }

  void _startBtScan() {
    final factory = widget.btScannerFactory;
    if (factory == null && !Platform.isAndroid) {
      _scanning = false;
      return;
    }
    final resolvedFactory = factory ?? BluetoothGpsScanner().scan;
    _btSub = resolvedFactory().listen(
      (devices) {
        if (mounted) setState(() => _btDevices = devices);
      },
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
      onError: (_) {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  void _stopBtScan() {
    _btSub?.cancel();
    _btSub = null;
  }

  void _startUsbMonitor() {
    final factory = widget.usbDetectorFactory;
    if (factory == null && !Platform.isAndroid) return;
    final resolvedFactory = factory ?? UsbGpsDetector().watch;
    _usbSub = resolvedFactory().listen(
      (device) {
        if (!mounted) return;
        setState(() {
          _usbDevice = device;
          final usbWasSelected = _selectedSource is ExternalGpsService &&
              _selectedSource.info.connectionType == GpsConnectionType.usb;
          if (usbWasSelected && device == null) {
            _selectedSource = InternalGpsService();
          }
        });
        // Se o GPS ativo no manager era USB e o cabo foi removido, faz fallback
        // imediato — sem esperar que o stream de posição feche.
        if (device == null &&
            _manager.activeSource.info.connectionType == GpsConnectionType.usb) {
          unawaited(_manager.setActiveSource(InternalGpsService()));
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _applySource() async {
    await _manager.setActiveSource(_selectedSource);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final activeInfo = _manager.activeSource.info;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(),
            const Divider(color: _kDivider, height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(label: 'ATIVO'),
                    _ActiveSourceCard(info: activeInfo),
                    const SizedBox(height: 4),
                    _SectionLabel(label: 'DISPOSITIVOS DISPONÍVEIS'),
                    _InternalGpsItem(
                      selected: _selectedSource is InternalGpsService,
                      onTap: () => setState(
                        () => _selectedSource = InternalGpsService(),
                      ),
                    ),
                    const Divider(color: _kDivider, height: 1, indent: 16, endIndent: 16),
                    if (_scanning)
                      _ScanningIndicator()
                    else if (_btDevices.isEmpty)
                      _EmptyBtMessage()
                    else
                      ..._btDevices.asMap().entries.map(
                        (e) => _ExternalDeviceItem(
                          key: Key('gps_device_${e.key}'),
                          source: e.value,
                          selected: _selectedSource is ExternalGpsService &&
                              _selectedSource.info == e.value.info,
                          onTap: () => setState(() => _selectedSource = e.value),
                        ),
                      ),
                    const Divider(color: _kDivider, height: 1, indent: 16, endIndent: 16),
                    _UsbItem(
                      device: _usbDevice,
                      selected: _usbDevice != null &&
                          _selectedSource is ExternalGpsService &&
                          _selectedSource.info == _usbDevice!.info,
                      onTap: _usbDevice != null
                          ? () => setState(() => _selectedSource = _usbDevice!)
                          : null,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const Divider(color: _kDivider, height: 1),
            _ApplyButton(
              enabled: _selectedSource.info != activeInfo,
              onTap: _applySource,
            ),
          ],
        ),
      ),
    );
  }
}

// ── TOP BAR ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Pressable(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.white.withAlpha(153),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'FONTE GPS',
              style: GoogleFonts.rajdhani(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          Pressable(
            key: const Key('gps_diagnostics_button'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GpsDiagnosticsScreen(),
              ),
            ),
            child: Text(
              'DIAGNÓSTICO',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white.withAlpha(115),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SECTION LABEL ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label,
        style: GoogleFonts.rajdhani(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: Colors.white.withAlpha(71),
        ),
      ),
    );
  }
}

// ── ACTIVE SOURCE CARD ────────────────────────────────────────────────────────

class _ActiveSourceCard extends StatelessWidget {
  final GpsSourceInfo info;

  const _ActiveSourceCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final badgeColor = Color(info.badgeArgb);
    return Container(
      key: const Key('gps_active_card'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withAlpha(60), width: 1),
      ),
      child: Row(
        children: [
          _BadgeChip(label: info.badgeLabel, color: badgeColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              info.name,
              key: const Key('gps_active_name'),
              style: GoogleFonts.rajdhani(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── INTERNAL GPS ITEM ─────────────────────────────────────────────────────────

class _InternalGpsItem extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _InternalGpsItem({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _DeviceListItem(
      key: const Key('gps_item_internal'),
      label: 'GPS interno do celular',
      badgeLabel: 'OK',
      badgeArgb: 0xFF00E676,
      selected: selected,
      enabled: true,
      onTap: onTap,
    );
  }
}

// ── EXTERNAL BT DEVICE ITEM ───────────────────────────────────────────────────

class _ExternalDeviceItem extends StatelessWidget {
  final ExternalGpsService source;
  final bool selected;
  final VoidCallback onTap;

  const _ExternalDeviceItem({
    super.key,
    required this.source,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _DeviceListItem(
      label: source.info.name,
      badgeLabel: source.info.badgeLabel,
      badgeArgb: source.info.badgeArgb,
      selected: selected,
      enabled: true,
      onTap: onTap,
    );
  }
}

// ── USB-C ITEM ────────────────────────────────────────────────────────────────

/// USB-C: desabilitado quando nenhum cabo está conectado; ativo automaticamente
/// quando um receptor GPS USB é detectado via [UsbGpsDetector].
class _UsbItem extends StatelessWidget {
  final ExternalGpsService? device;
  final bool selected;
  final VoidCallback? onTap;

  const _UsbItem({
    required this.device,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final connected = device != null;
    final label = connected
        ? 'USB-C · ${device!.info.name}'
        : 'USB-C · Nenhum cabo conectado';
    return _DeviceListItem(
      key: const Key('gps_item_usb'),
      label: label,
      badgeLabel: 'USB',
      badgeArgb: 0xFFFFD600,
      selected: selected,
      enabled: connected,
      onTap: onTap,
    );
  }
}

// ── SCANNING INDICATOR ────────────────────────────────────────────────────────

class _ScanningIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white.withAlpha(89),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Buscando dispositivos Bluetooth...',
            key: const Key('gps_bt_scanning'),
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              color: Colors.white.withAlpha(89),
            ),
          ),
        ],
      ),
    );
  }
}

// ── EMPTY BT MESSAGE ──────────────────────────────────────────────────────────

class _EmptyBtMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        'Nenhum dispositivo Bluetooth encontrado',
        key: const Key('gps_bt_empty'),
        style: GoogleFonts.rajdhani(
          fontSize: 13,
          color: Colors.white.withAlpha(71),
        ),
      ),
    );
  }
}

// ── DEVICE LIST ITEM ──────────────────────────────────────────────────────────

class _DeviceListItem extends StatelessWidget {
  final String label;
  final String badgeLabel;
  final int badgeArgb;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _DeviceListItem({
    super.key,
    required this.label,
    required this.badgeLabel,
    required this.badgeArgb,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = Color(badgeArgb);
    final textAlpha = enabled ? 255 : 71;
    final badgeAlpha = enabled ? 100 : 38;

    return Pressable(
      onTap: enabled ? onTap : null,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            _BadgeChip(
              label: badgeLabel,
              color: enabled ? badgeColor : badgeColor.withAlpha(badgeAlpha),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withAlpha(textAlpha),
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 18, color: _kGreen)
            else if (enabled)
              Icon(Icons.radio_button_unchecked,
                  size: 18, color: Colors.white.withAlpha(51)),
          ],
        ),
      ),
    );
  }
}

// ── BADGE CHIP ────────────────────────────────────────────────────────────────

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(100), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── APPLY BUTTON ──────────────────────────────────────────────────────────────

class _ApplyButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ApplyButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: Container(
          key: const Key('gps_apply_button'),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: enabled ? _kGreen : _kSurface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'USAR ESTE GPS',
            style: GoogleFonts.rajdhani(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: enabled ? Colors.black : Colors.white.withAlpha(51),
            ),
          ),
        ),
      ),
    );
  }
}
