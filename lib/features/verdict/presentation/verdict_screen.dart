import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../sandbox/sandbox_client.dart';
import '../../history/data/scan_record.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

final _verdictProvider = FutureProvider.family<AnalysisReport, Map<String, dynamic>>(
  (ref, args) async {
    final client = ref.read(sandboxClientProvider);
    return client.analysePayload(
      payload: args['payload'] as String,
      format: args['format'] as String,
    );
  },
);

class VerdictScreen extends ConsumerWidget {
  final Map<String, dynamic> analysisResult;

  const VerdictScreen({super.key, required this.analysisResult});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(_verdictProvider(analysisResult));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Report'),
        leading: BackButton(
          color: AppTheme.textPrimary,
          onPressed: () => context.goNamed('home'),
        ),
      ),
      body: reportAsync.when(
        loading: () => const _AnalysingState(),
        error: (err, st) => _ErrorState(error: err.toString()),
        data: (report) => _VerdictBody(report: report, payload: analysisResult),
      ),
    );
  }
}

// ── Loading state ──────────────────────────────────────────────────────────

class _AnalysingState extends StatelessWidget {
  const _AnalysingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.1),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 36),
          ).animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1500.ms, color: AppTheme.primary.withOpacity(0.4)),
          const SizedBox(height: 24),
          Text('Analysing in sandbox…',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            'Tracing redirects · Checking threat feeds · Inspecting content',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppTheme.danger, size: 64),
          const SizedBox(height: 16),
          Text('Sandbox Unreachable',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.goNamed('home'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to safety'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

// ── Main verdict body ──────────────────────────────────────────────────────

class _VerdictBody extends ConsumerStatefulWidget {
  final AnalysisReport report;
  final Map<String, dynamic> payload;

  const _VerdictBody({required this.report, required this.payload});

  @override
  ConsumerState<_VerdictBody> createState() => _VerdictBodyState();
}

class _VerdictBodyState extends ConsumerState<_VerdictBody> {
  @override
  void initState() {
    super.initState();
    _saveToHistory();
  }

  void _saveToHistory() {
    final box = Hive.box<ScanRecord>('scan_history');
    box.add(ScanRecord(
      id: const Uuid().v4(),
      rawPayload: widget.report.rawPayload,
      verdict: widget.report.verdict,
      riskScore: widget.report.riskScore,
      payloadType: widget.report.payloadType,
      scannedAt: DateTime.now(),
      finalUrl: widget.report.urlAnalysis?.finalUrl,
      redirectHops: widget.report.urlAnalysis?.redirectChain.length ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final color = AppTheme.forVerdict(report.verdict);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Verdict banner ──────────────────────────────────────────
        _VerdictBanner(verdict: report.verdict, score: report.riskScore, color: color),
        const SizedBox(height: 16),

        // ── Payload info card ───────────────────────────────────────
        _InfoCard(
          title: 'Scanned Payload',
          children: [
            _InfoRow('Type', report.payloadType),
            _InfoRow('Content', report.rawPayload, monospace: true, truncate: true),
            if (report.urlAnalysis?.finalUrl != null &&
                report.urlAnalysis!.finalUrl != report.rawPayload)
              _InfoRow('Final URL', report.urlAnalysis!.finalUrl,
                  monospace: true, truncate: true),
          ],
        ),
        const SizedBox(height: 12),

        // ── URL analysis ────────────────────────────────────────────
        if (report.urlAnalysis != null) ...[
          _URLAnalysisCard(analysis: report.urlAnalysis!),
          const SizedBox(height: 12),
        ],

        // ── Threat indicators ───────────────────────────────────────
        if (report.threats.isNotEmpty) ...[
          _ThreatCard(threats: report.threats),
          const SizedBox(height: 12),
        ],

        // ── Redirect chain ──────────────────────────────────────────
        if ((report.urlAnalysis?.redirectChain ?? []).isNotEmpty) ...[
          _RedirectChainCard(hops: report.urlAnalysis!.redirectChain),
          const SizedBox(height: 12),
        ],

        // ── Actions ─────────────────────────────────────────────────
        _ActionButtons(report: report, verdict: report.verdict),
        const SizedBox(height: 32),

        // Footer
        Text(
          'Analysed in ${report.durationMs}ms · Report ID: ${report.id.substring(0, 8)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Verdict banner ─────────────────────────────────────────────────────────

class _VerdictBanner extends StatelessWidget {
  final String verdict;
  final int score;
  final Color color;

  const _VerdictBanner({
    required this.verdict,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(_verdictIcon(), color: color, size: 56)
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 12),
          Text(
            verdict,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          // Risk gauge
          Column(
            children: [
              Text(
                'Risk Score: $score / 100',
                style: TextStyle(color: color, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _verdictIcon() {
    switch (verdict.toLowerCase()) {
      case 'safe':
        return Icons.verified_rounded;
      case 'suspicious':
        return Icons.warning_amber_rounded;
      case 'danger':
        return Icons.dangerous_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

// ── Info card ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              )),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;
  final bool truncate;

  const _InfoRow(
    this.label,
    this.value, {
    this.monospace = false,
    this.truncate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                )),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () => Clipboard.setData(ClipboardData(text: value)),
              child: Text(
                value,
                maxLines: truncate ? 2 : null,
                overflow: truncate ? TextOverflow.ellipsis : null,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontFamily: monospace ? 'monospace' : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── URL Analysis card ──────────────────────────────────────────────────────

class _URLAnalysisCard extends StatelessWidget {
  final UrlAnalysis analysis;

  const _URLAnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'URL Analysis',
      children: [
        _InfoRow('TLS', analysis.hasSsl ? '✓ HTTPS' : '✗ No HTTPS'),
        if (analysis.certAgeDays != null)
          _InfoRow('Cert age', '${analysis.certAgeDays} days'),
        if (analysis.domainAgeDays != null)
          _InfoRow('Domain age', '${analysis.domainAgeDays} days'),
        if (analysis.ipAddress != null)
          _InfoRow('IP', analysis.ipAddress!, monospace: true),
        if (analysis.country != null)
          _InfoRow('Origin', analysis.country!),
        if (analysis.pageTitle != null)
          _InfoRow('Page title', analysis.pageTitle!),
        _InfoRow('Redirects', '${analysis.redirectChain.length} hop(s)'),
        _InfoRow('HTTP status', '${analysis.httpStatus}'),
      ],
    );
  }
}

// ── Threat indicators card ─────────────────────────────────────────────────

class _ThreatCard extends StatelessWidget {
  final List<ThreatIndicator> threats;

  const _ThreatCard({required this.threats});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Threat Indicators',
      children: threats
          .map((t) => _ThreatRow(threat: t))
          .toList(),
    );
  }
}

class _ThreatRow extends StatelessWidget {
  final ThreatIndicator threat;

  const _ThreatRow({required this.threat});

  Color get _severityColor {
    switch (threat.severity) {
      case 'critical':
        return AppTheme.danger;
      case 'high':
        return const Color(0xFFFF6B35);
      case 'medium':
        return AppTheme.warning;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _severityColor,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        threat.description,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _severityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        threat.severity.toUpperCase(),
                        style: TextStyle(
                          color: _severityColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (threat.evidence != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    threat.evidence!,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
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
}

// ── Redirect chain card ────────────────────────────────────────────────────

class _RedirectChainCard extends StatelessWidget {
  final List<RedirectHop> hops;

  const _RedirectChainCard({required this.hops});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Redirect Chain',
      children: hops.asMap().entries.map((entry) {
        final i = entry.key;
        final hop = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (i < hops.length - 1)
                    Container(
                        width: 1,
                        height: 16,
                        color: AppTheme.border),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hop.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'HTTP ${hop.statusCode}',
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Action buttons ─────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final AnalysisReport report;
  final String verdict;

  const _ActionButtons({required this.report, required this.verdict});

  bool get _canOpen => verdict == 'SAFE';
  bool get _requiresConfirmation => verdict == 'SUSPICIOUS';
  bool get _isBlocked => verdict == 'DANGER';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isBlocked)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _open(context),
              icon: const Icon(Icons.open_in_browser_rounded),
              label: Text(_canOpen
                  ? 'Open — Verified Safe'
                  : 'Open Anyway — Not Recommended'),
              style: FilledButton.styleFrom(
                backgroundColor: _canOpen ? AppTheme.safe : AppTheme.warning,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (_isBlocked) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.block_rounded,
                    color: AppTheme.danger, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This destination has been blocked. Opening it would put you at risk.',
                    style: TextStyle(
                      color: AppTheme.danger,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: report.rawPayload));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    Share.share('SentinelQR Report\nVerdict: ${report.verdict}\nRisk Score: ${report.riskScore}/100\nPayload: ${report.rawPayload}'),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => context.goNamed('home'),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: const Text('Scan another code'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    if (_requiresConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Proceed with caution'),
          content: const Text(
            'This destination is flagged as suspicious. Are you sure you want to open it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Open anyway',
                  style: TextStyle(color: AppTheme.warning)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final url = report.urlAnalysis?.finalUrl ?? report.rawPayload;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
