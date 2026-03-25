import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dd_colors.dart';
import '../../../core/theme/dd_spacing.dart';
import '../../../core/theme/dd_typography.dart';
import '../../../components/dd_button.dart';
import '../../../components/dd_card.dart';
import '../../../components/dd_loading_indicator.dart';
import '../../../components/dd_text_field.dart';
import '../../../components/dd_toast.dart';
import '../../../providers/providers.dart';

/// /settings/remote-access — Cloudflare Tunnel remote access configuration.
class RemoteAccessScreen extends ConsumerStatefulWidget {
  const RemoteAccessScreen({super.key});

  @override
  ConsumerState<RemoteAccessScreen> createState() => _RemoteAccessScreenState();
}

class _RemoteAccessScreenState extends ConsumerState<RemoteAccessScreen> {
  bool _remoteEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _existingTunnelUrl;

  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final device = ref.read(deviceProvider);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(device.deviceId)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        final enabled = data['remoteAccessEnabled'] as bool? ?? false;
        final url = data['tunnelUrl'] as String? ?? '';
        setState(() {
          _remoteEnabled = enabled;
          _existingTunnelUrl = url.isNotEmpty ? url : null;
          _urlController.text = url;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleRemoteAccess(bool value) async {
    setState(() => _remoteEnabled = value);
    final device = ref.read(deviceProvider);
    try {
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(device.deviceId)
          .set({'remoteAccessEnabled': value}, SetOptions(merge: true));
      if (!value) {
        // Disable: clear tunnel URL in provider
        ref.read(tunnelUrlProvider.notifier).state = null;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _remoteEnabled = !value);
        DDToast.error(context, 'Failed to update setting.');
      }
    }
  }

  Future<void> _saveTunnelUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      DDToast.error(context, 'Please enter a tunnel URL.');
      return;
    }
    if (!url.startsWith('https://')) {
      DDToast.error(context, 'URL must start with https://');
      return;
    }
    setState(() => _isSaving = true);
    final device = ref.read(deviceProvider);
    try {
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(device.deviceId)
          .set({
        'tunnelUrl': url,
        'remoteAccessEnabled': true,
      }, SetOptions(merge: true));
      // Update in-app provider so API calls immediately switch to tunnel
      ref.read(tunnelUrlProvider.notifier).state = url;
      setState(() {
        _existingTunnelUrl = url;
        _remoteEnabled = true;
        _isSaving = false;
      });
      if (mounted) DDToast.success(context, 'Remote access enabled');
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) DDToast.error(context, 'Failed to save tunnel URL.');
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      final api = ref.read(deviceApiProvider);
      final health = await api.getHealth().timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() => _isTesting = false);
        DDToast.success(
            context, 'Connection OK — firmware v${health.fwVersion}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isTesting = false);
        DDToast.error(context, 'Connection failed. Check your tunnel URL.');
      }
    }
  }

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Remote Access', style: DDTypography.h3),
      ),
      body: _isLoading
          ? const Center(child: DDLoadingIndicator(size: DDLoadingSize.md))
          : ListView(
              padding: const EdgeInsets.all(DDSpacing.xl),
              children: [
                DDCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Enable Remote Access',
                                    style: DDTypography.bodyM),
                                const SizedBox(height: 2),
                                Text(
                                  'Access your device from outside your home network',
                                  style: DDTypography.caption
                                      .copyWith(color: DDColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _remoteEnabled,
                            onChanged: _toggleRemoteAccess,
                            activeThumbColor: DDColors.hunterGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_remoteEnabled) ...[
                  const SizedBox(height: DDSpacing.lg),
                  DDCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DDTextField(
                          label: 'Cloudflare Tunnel URL',
                          hint: 'https://your-tunnel.trycloudflare.com',
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: DDSpacing.sm),
                        Text(
                          'Set up a Cloudflare Tunnel pointing to your device on port 80. '
                          'Enter the tunnel URL here to access your device from anywhere.',
                          style: DDTypography.caption
                              .copyWith(color: DDColors.textMuted),
                        ),
                        const SizedBox(height: DDSpacing.lg),
                        DDButton.primary(
                          label: 'Save Tunnel URL',
                          isLoading: _isSaving,
                          onPressed: _isSaving ? null : _saveTunnelUrl,
                        ),
                        if (_existingTunnelUrl != null) ...[
                          const SizedBox(height: DDSpacing.sm),
                          DDButton.secondary(
                            label: _isTesting
                                ? 'Testing...'
                                : 'Test Connection',
                            isLoading: _isTesting,
                            onPressed: _isTesting ? null : _testConnection,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: DDSpacing.lg),
                DDCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How it works',
                          style: DDTypography.label
                              .copyWith(color: DDColors.textMuted)),
                      const SizedBox(height: DDSpacing.sm),
                      const _HelpRow(
                        icon: Icons.cloud_outlined,
                        text:
                            'Cloudflare Tunnel creates a secure connection from your device to Cloudflare\'s network.',
                      ),
                      const SizedBox(height: DDSpacing.sm),
                      const _HelpRow(
                        icon: Icons.lock_outline,
                        text:
                            'Your tunnel URL is private — only you can access it with your DingDong credentials.',
                      ),
                      const SizedBox(height: DDSpacing.sm),
                      const _HelpRow(
                        icon: Icons.wifi_outlined,
                        text:
                            'When on your home Wi-Fi, the app automatically uses the local connection for lower latency.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HelpRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: DDColors.hunterGreen),
        const SizedBox(width: DDSpacing.sm),
        Expanded(
          child: Text(text,
              style: DDTypography.caption.copyWith(color: DDColors.textMuted)),
        ),
      ],
    );
  }
}
