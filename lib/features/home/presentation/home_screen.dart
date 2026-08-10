import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SentinelQR',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Zero-trust QR scanner',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pushNamed('history'),
                        icon: const Icon(Icons.history_rounded),
                        color: AppTheme.textSecondary,
                      ),
                      IconButton(
                        onPressed: () => context.pushNamed('settings'),
                        icon: const Icon(Icons.settings_outlined),
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              // Scan button
              Center(
                child: GestureDetector(
                  onTap: () => context.pushNamed('scanner'),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF1A3A4A),
                          AppTheme.surface,
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.15),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 64,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'TAP TO SCAN',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().scale(
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                ),
              ),
              const SizedBox(height: 48),
              // Info cards
              _SecurityPrincipleCard(
                icon: Icons.shield_outlined,
                title: 'Zero Trust Scanning',
                description: 'Every QR code is treated as hostile until verified by our sandbox engine.',
              ),
              const SizedBox(height: 12),
              _SecurityPrincipleCard(
                icon: Icons.link_rounded,
                title: 'Redirect Chain Resolution',
                description: 'Full redirect chains are traced before any URL is opened.',
              ),
              const SizedBox(height: 12),
              _SecurityPrincipleCard(
                icon: Icons.verified_outlined,
                title: 'Threat Intelligence',
                description: 'Cross-referenced against known phishing and malware domains.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityPrincipleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SecurityPrincipleCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
