import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoOpenSafe = false;
  bool _saveHistory = true;
  bool _hapticFeedback = true;
  bool _showRedirectChain = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: BackButton(color: AppTheme.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Behaviour'),
          _ToggleTile(
            icon: Icons.open_in_browser_rounded,
            title: 'Auto-open SAFE destinations',
            subtitle: 'Skip the verdict screen for verified safe URLs',
            value: _autoOpenSafe,
            onChanged: (v) => setState(() => _autoOpenSafe = v),
          ),
          _ToggleTile(
            icon: Icons.history_rounded,
            title: 'Save scan history',
            subtitle: 'Store a local record of each scan and its verdict',
            value: _saveHistory,
            onChanged: (v) => setState(() => _saveHistory = v),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Display'),
          _ToggleTile(
            icon: Icons.alt_route_rounded,
            title: 'Show redirect chain',
            subtitle: 'Display the full hop-by-hop redirect path on results',
            value: _showRedirectChain,
            onChanged: (v) => setState(() => _showRedirectChain = v),
          ),
          _ToggleTile(
            icon: Icons.vibration_rounded,
            title: 'Haptic feedback',
            subtitle: 'Vibrate on scan and verdict events',
            value: _hapticFeedback,
            onChanged: (v) => setState(() => _hapticFeedback = v),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Sandbox Engine'),
          _InfoTile(
            icon: Icons.dns_rounded,
            title: 'Sandbox endpoint',
            value: 'sandbox.sentinelqr.app',
          ),
          _InfoTile(
            icon: Icons.lock_rounded,
            title: 'Transport',
            value: 'TLS 1.3 enforced',
          ),
          const SizedBox(height: 32),
          // About
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_rounded, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('SentinelQR',
                        style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0 · Built for security',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Every QR code is treated as hostile until proven otherwise.',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
