import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../components/dd_bottom_sheet.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_list_tile.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_toast.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/providers.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _WifiNetwork {
  final String ssid;
  final int rssi;
  final bool secured;

  const _WifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.secured,
  });

  factory _WifiNetwork.fromJson(Map<String, dynamic> j) => _WifiNetwork(
        ssid: j['ssid'] as String? ?? '',
        rssi: j['rssi'] as int? ?? -90,
        secured: j['secured'] as bool? ?? true,
      );
}

class _WifiCredentials {
  final String ssid;
  final String password;
  const _WifiCredentials(this.ssid, this.password);
}

// ── BLE Provisioning Screen ───────────────────────────────────────────────────

/// /onboard/ble-provision — Step 3/5
/// Scans for BLE devices advertising "DingDong-Setup", connects, fetches
/// Wi-Fi networks from device, and writes credentials via BLE characteristic.
/// On web: shows a manual SSID/password form that POSTs to the device HTTP API.
class BleProvisioningScreen extends ConsumerStatefulWidget {
  const BleProvisioningScreen({super.key});

  @override
  ConsumerState<BleProvisioningScreen> createState() =>
      _BleProvisioningScreenState();
}

class _BleProvisioningScreenState
    extends ConsumerState<BleProvisioningScreen> {
  // ── BLE state ──────────────────────────────────────────────────────────────
  final List<ScanResult> _devices = [];
  bool _isScanning = false;
  bool _connecting = false;
  bool _permissionDenied = false;
  String? _error;
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<ScanResult>>? _scanSub;

  // ── Web fallback state ────────────────────────────────────────────────────
  final _webFormKey = GlobalKey<FormState>();
  final _ssidCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _webSubmitting = false;

  static const _kServiceUuid = '12345678-1234-1234-1234-123456789abc';
  static const _kCharUuid = '12345678-1234-1234-1234-123456789abd';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _requestPermissionsAndScan();
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    if (!kIsWeb) {
      FlutterBluePlus.stopScan().ignore();
      _connectedDevice?.disconnect().ignore();
    }
    _ssidCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Permission + scan ─────────────────────────────────────────────────────

  Future<void> _requestPermissionsAndScan() async {
    final btScan = await Permission.bluetoothScan.request();
    final btConnect = await Permission.bluetoothConnect.request();
    final loc = await Permission.location.request();

    final granted =
        (btScan.isGranted || btScan.isLimited) &&
        (btConnect.isGranted || btConnect.isLimited) &&
        (loc.isGranted || loc.isLimited);

    if (!mounted) return;
    if (!granted) {
      setState(() => _permissionDenied = true);
      return;
    }
    _startScan();
  }

  Future<void> _startScan() async {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _devices.clear();
      _error = null;
      _permissionDenied = false;
    });

    await _scanSub?.cancel();
    _scanSub = null;

    try {
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        if (!mounted) return;
        final dd = results.where((r) {
          final name = r.advertisementData.advName;
          final platform = r.device.platformName;
          return name == 'DingDong-Setup' || platform == 'DingDong-Setup';
        }).toList();
        if (dd.isNotEmpty) {
          setState(() {
            _devices.clear();
            _devices.addAll(dd);
          });
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = 'Bluetooth scan failed. Make sure Bluetooth is on.');
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // ── BLE connection flow ───────────────────────────────────────────────────

  Future<void> _connectToDevice(ScanResult result) async {
    if (_connecting) return;
    setState(() => _connecting = true);

    final device = result.device;
    try {
      await FlutterBluePlus.stopScan();
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      if (!mounted) return;
      await _showWifiNetworksFlow(device);
    } catch (e) {
      if (mounted) DDToast.error(context, 'Connection failed. Please try again.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _showWifiNetworksFlow(BluetoothDevice device) async {
    List<_WifiNetwork> networks = [];
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.get<Map<String, dynamic>>(
        'http://192.168.4.1/wifi/scan',
      );
      final data = response.data;
      if (data != null) {
        final list = data['networks'];
        if (list is List) {
          networks = list
              .whereType<Map<String, dynamic>>()
              .map(_WifiNetwork.fromJson)
              .where((n) => n.ssid.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      // HTTP scan failed — continue with empty list (manual entry available)
    }

    if (!mounted) return;

    final deviceName =
        ref.read(onboardingProvider).deviceName ?? 'My DingDong';

    final creds = await DDBottomSheet.show<_WifiCredentials>(
      context: context,
      title: 'Select Wi-Fi Network',
      child: _WifiSelectionSheet(networks: networks),
    );

    if (creds == null || !mounted) return;

    ref.read(onboardingProvider.notifier).setWifiSsid(creds.ssid);

    await _writeBleCredentials(device, creds.ssid, creds.password, deviceName);
  }

  Future<void> _writeBleCredentials(
    BluetoothDevice device,
    String ssid,
    String password,
    String deviceName,
  ) async {
    if (!mounted) return;
    setState(() => _connecting = true);
    try {
      final services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (final svc in services) {
        if (svc.serviceUuid == Guid(_kServiceUuid)) {
          for (final chr in svc.characteristics) {
            if (chr.characteristicUuid == Guid(_kCharUuid)) {
              targetChar = chr;
              break;
            }
          }
        }
        if (targetChar != null) break;
      }

      if (targetChar == null) {
        if (mounted) {
          DDToast.error(context, 'Device service not found. Try again.');
        }
        return;
      }

      final payload = jsonEncode({
        'ssid': ssid,
        'password': password,
        'deviceName': deviceName,
      });

      await targetChar.write(
        utf8.encode(payload),
        withoutResponse: false,
      );

      if (mounted) context.go(Routes.onboardConfirming);
    } catch (e) {
      if (mounted) {
        DDToast.error(context, 'Failed to send credentials. Try again.');
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  // ── Web fallback submit ───────────────────────────────────────────────────

  Future<void> _webSubmit() async {
    if (!_webFormKey.currentState!.validate()) return;
    setState(() => _webSubmitting = true);

    final deviceName =
        ref.read(onboardingProvider).deviceName ?? 'My DingDong';

    try {
      final dio = Dio();
      await dio.post<dynamic>(
        'http://192.168.4.1/provision',
        data: {
          'ssid': _ssidCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'deviceName': deviceName,
        },
        options: Options(contentType: 'application/json'),
      );
      ref
          .read(onboardingProvider.notifier)
          .setWifiSsid(_ssidCtrl.text.trim());
      if (mounted) context.go(Routes.onboardConfirming);
    } catch (_) {
      if (mounted) {
        DDToast.error(context, 'Failed to connect. Check your credentials.');
      }
    } finally {
      if (mounted) setState(() => _webSubmitting = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Widget _rssiIcon(int rssi) {
    final IconData icon;
    final Color color;
    if (rssi >= -60) {
      icon = Icons.signal_wifi_4_bar;
      color = DDColors.hunterGreen;
    } else if (rssi >= -70) {
      icon = Icons.network_wifi_3_bar;
      color = DDColors.hunterGreen;
    } else if (rssi >= -80) {
      icon = Icons.network_wifi_2_bar;
      color = DDColors.warning;
    } else {
      icon = Icons.network_wifi_1_bar;
      color = DDColors.error;
    }
    return Icon(icon, size: 18, color: color);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DDColors.white,
      appBar: AppBar(
        backgroundColor: DDColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF355E3B)),
          onPressed: () => context.go(Routes.onboardConnectAp),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DDSpacing.xl),
            child: Text('3 of 5', style: DDTypography.caption),
          ),
        ],
      ),
      body: kIsWeb ? _buildWebFallback() : _buildBleBody(),
    );
  }

  // ── Web fallback ──────────────────────────────────────────────────────────

  Widget _buildWebFallback() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
        child: Form(
          key: _webFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: DDSpacing.xl),
              Text('Connect to Wi-Fi', style: DDTypography.h2),
              const SizedBox(height: DDSpacing.sm),
              Text(
                'BLE is not available on web. Enter your home Wi-Fi credentials to provision the device.',
                style:
                    DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              ),
              const SizedBox(height: DDSpacing.xl),
              DDTextField(
                label: 'Wi-Fi Network (SSID)',
                hint: 'My Home Network',
                controller: _ssidCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'SSID is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: DDSpacing.md),
              DDTextField(
                label: 'Password',
                controller: _passwordCtrl,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _webSubmit(),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  return null;
                },
              ),
              const SizedBox(height: DDSpacing.sm),
              Text(
                'Your credentials are sent directly to the device and never stored in the cloud.',
                style: DDTypography.caption.copyWith(color: DDColors.textMuted),
              ),
              const Spacer(),
              DDButton.primary(
                label: _webSubmitting ? 'Connecting...' : 'Connect Device',
                onPressed: _webSubmitting ? null : _webSubmit,
              ),
              const SizedBox(height: DDSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  // ── BLE body ──────────────────────────────────────────────────────────────

  Widget _buildBleBody() {
    if (_permissionDenied) {
      return _buildPermissionDenied();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DDSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: DDSpacing.xl),
            Text('Find DingDong Device', style: DDTypography.h2),
            const SizedBox(height: DDSpacing.sm),
            Text(
              'Make sure your device is plugged in with the LED blinking blue.',
              style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
            ),
            const SizedBox(height: DDSpacing.xl),
            if (_isScanning && _devices.isEmpty)
              _buildScanningState()
            else if (_error != null)
              _buildErrorState(_error!)
            else if (_devices.isEmpty)
              _buildEmptyState()
            else
              _buildDeviceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: DDColors.hunterGreen,
              strokeWidth: 3,
            ),
            const SizedBox(height: DDSpacing.lg),
            Text(
              'Searching for DingDong device...',
              style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DDColors.hunterGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_searching,
                size: 40,
                color: DDColors.hunterGreen,
              ),
            ),
            const SizedBox(height: DDSpacing.lg),
            Text('No Device Found',
                style: DDTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: DDSpacing.sm),
            Text(
              'Make sure your DingDong device is powered on\nand the LED is blinking blue.',
              style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DDSpacing.xl),
            DDButton.primary(
              label: 'Retry',
              onPressed: _requestPermissionsAndScan,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DDColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_disabled,
                size: 40,
                color: DDColors.error,
              ),
            ),
            const SizedBox(height: DDSpacing.lg),
            Text('Bluetooth Error',
                style: DDTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: DDSpacing.sm),
            Text(
              message,
              style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DDSpacing.xl),
            DDButton.primary(
              label: 'Try Again',
              onPressed: _requestPermissionsAndScan,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DDSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DDColors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_disabled,
                size: 40,
                color: DDColors.warning,
              ),
            ),
            const SizedBox(height: DDSpacing.lg),
            Text(
              'Bluetooth Permission Required',
              style: DDTypography.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DDSpacing.sm),
            Text(
              'Please grant Bluetooth and Location permissions to find your DingDong device.',
              style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DDSpacing.xl),
            const DDButton.primary(
              label: 'Open Settings',
              onPressed: openAppSettings,
            ),
            const SizedBox(height: DDSpacing.sm),
            DDButton.secondary(
              label: 'Try Again',
              onPressed: _requestPermissionsAndScan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return Expanded(
      child: Stack(
        children: [
          ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final result = _devices[index];
              final name = result.advertisementData.advName.isNotEmpty
                  ? result.advertisementData.advName
                  : result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : 'DingDong-Setup';
              return DDCard(
                child: DDListTile(
                  showDivider: false,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: DDColors.hunterGreen.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(DDSpacing.radiusSm),
                    ),
                    child: const Icon(
                      Icons.doorbell_outlined,
                      size: 20,
                      color: DDColors.hunterGreen,
                    ),
                  ),
                  title: name,
                  subtitle: 'Tap to connect',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _rssiIcon(result.rssi),
                      const SizedBox(width: DDSpacing.sm),
                      DDButton.primary(
                        label: 'Connect',
                        fullWidth: false,
                        onPressed:
                            _connecting ? null : () => _connectToDevice(result),
                      ),
                    ],
                  ),
                  onTap:
                      _connecting ? null : () => _connectToDevice(result),
                ),
              );
            },
          ),
          if (_connecting)
            Container(
              color: DDColors.white.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: DDColors.hunterGreen,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: DDSpacing.md),
                    Text(
                      'Connecting...',
                      style:
                          DDTypography.bodyM.copyWith(color: DDColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Wi-Fi selection bottom sheet ──────────────────────────────────────────────

/// Stateful sheet that handles both network list and password entry in one widget.
class _WifiSelectionSheet extends StatefulWidget {
  final List<_WifiNetwork> networks;

  const _WifiSelectionSheet({required this.networks});

  @override
  State<_WifiSelectionSheet> createState() => _WifiSelectionSheetState();
}

class _WifiSelectionSheetState extends State<_WifiSelectionSheet> {
  _WifiNetwork? _selected;
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selected == null) {
      return _buildNetworkList(context);
    }
    return _buildPasswordEntry(context);
  }

  Widget _buildNetworkList(BuildContext context) {
    if (widget.networks.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: DDColors.textMuted),
          const SizedBox(height: DDSpacing.md),
          Text(
            'No networks found.',
            style: DDTypography.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DDSpacing.sm),
          Text(
            'Could not scan Wi-Fi networks. Enter your network details manually.',
            style: DDTypography.bodyM.copyWith(color: DDColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DDSpacing.xl),
          DDButton.primary(
            label: 'Enter Manually',
            onPressed: () => setState(
              () => _selected = const _WifiNetwork(
                ssid: '',
                rssi: -90,
                secured: true,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.networks.length,
          itemBuilder: (context, index) {
            final network = widget.networks[index];
            return DDListTile(
              title: network.ssid,
              subtitle: network.secured ? 'Secured' : 'Open',
              leading: _networkSignalIcon(network.rssi),
              trailing: network.secured
                  ? const Icon(Icons.lock_outline,
                      size: 18, color: DDColors.textMuted)
                  : null,
              showDivider: index < widget.networks.length - 1,
              onTap: () {
                if (!network.secured) {
                  Navigator.of(context)
                      .pop(_WifiCredentials(network.ssid, ''));
                } else {
                  setState(() => _selected = network);
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPasswordEntry(BuildContext context) {
    final isManual = _selected!.ssid.isEmpty;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isManual) ...[
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 16, color: DDColors.hunterGreen),
                ),
                const SizedBox(width: DDSpacing.sm),
                Text(_selected!.ssid, style: DDTypography.h3),
              ],
            ),
            const SizedBox(height: DDSpacing.lg),
          ] else ...[
            DDTextField(
              label: 'Wi-Fi Network (SSID)',
              hint: 'My Home Network',
              textInputAction: TextInputAction.next,
              onChanged: (v) => _selected = _WifiNetwork(
                ssid: v.trim(),
                rssi: -90,
                secured: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'SSID is required';
                return null;
              },
            ),
            const SizedBox(height: DDSpacing.md),
          ],
          DDTextField(
            label: 'Password',
            hint: isManual ? 'Wi-Fi password' : 'Enter password for ${_selected!.ssid}',
            controller: _passCtrl,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(context),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: DDSpacing.lg),
          DDButton.primary(
            label: 'Connect',
            onPressed: () => _confirm(context),
          ),
        ],
      ),
    );
  }

  void _confirm(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final ssid = _selected?.ssid ?? '';
    Navigator.of(context).pop(_WifiCredentials(ssid, _passCtrl.text));
  }

  static Widget _networkSignalIcon(int rssi) {
    final IconData icon;
    final Color color;
    if (rssi >= -60) {
      icon = Icons.signal_wifi_4_bar;
      color = DDColors.hunterGreen;
    } else if (rssi >= -70) {
      icon = Icons.network_wifi_3_bar;
      color = DDColors.hunterGreen;
    } else if (rssi >= -80) {
      icon = Icons.network_wifi_2_bar;
      color = DDColors.warning;
    } else {
      icon = Icons.network_wifi_1_bar;
      color = DDColors.error;
    }
    return Icon(icon, size: 22, color: color);
  }
}
