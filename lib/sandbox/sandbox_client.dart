import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Sandbox Analysis Client ────────────────────────────────────────────────
// Sends QR payloads to the sandboxed analysis engine and returns a structured
// threat report. The raw URL or payload is never handed to the phone browser
// until the verdict gate clears.

class SandboxClient {
  static const String _baseUrl = 'https://sandbox.sentinelqr.app/api/v1';
  // For local dev: 'http://10.0.2.2:8000/api/v1'  (Android emulator loopback)

  final Dio _dio;

  SandboxClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
            headers: {
              'Content-Type': 'application/json',
              'X-Client': 'SentinelQR-Flutter/1.0',
            },
          ),
        );

  /// Submit a raw QR payload for sandbox analysis.
  /// Returns a full [AnalysisReport] on success, or throws [SandboxException].
  Future<AnalysisReport> analysePayload({
    required String payload,
    required String format,
  }) async {
    try {
      final response = await _dio.post(
        '/analyse',
        data: {
          'payload': payload,
          'format': format,
          'requested_at': DateTime.now().toIso8601String(),
        },
      );

      return AnalysisReport.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const SandboxException(
          code: 'TIMEOUT',
          message: 'Sandbox analysis timed out. Please try again.',
        );
      }
      if (e.response != null) {
        throw SandboxException(
          code: e.response!.data['code'] ?? 'SERVER_ERROR',
          message: e.response!.data['message'] ?? 'Sandbox returned an error.',
        );
      }
      throw const SandboxException(
        code: 'NETWORK_ERROR',
        message: 'Could not reach the sandbox engine. Check your connection.',
      );
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final sandboxClientProvider = Provider<SandboxClient>((ref) => SandboxClient());

// ── Models ────────────────────────────────────────────────────────────────

class AnalysisReport {
  final String id;
  final String verdict;           // SAFE | SUSPICIOUS | DANGER
  final int riskScore;            // 0–100
  final String payloadType;       // URL | UPI | WIFI | VCARD | TEXT
  final String rawPayload;
  final UrlAnalysis? urlAnalysis;
  final List<ThreatIndicator> threats;
  final List<String> categories;
  final String analysedAt;
  final int durationMs;

  const AnalysisReport({
    required this.id,
    required this.verdict,
    required this.riskScore,
    required this.payloadType,
    required this.rawPayload,
    this.urlAnalysis,
    required this.threats,
    required this.categories,
    required this.analysedAt,
    required this.durationMs,
  });

  factory AnalysisReport.fromJson(Map<String, dynamic> json) {
    return AnalysisReport(
      id: json['id'] as String,
      verdict: json['verdict'] as String,
      riskScore: json['risk_score'] as int,
      payloadType: json['payload_type'] as String,
      rawPayload: json['raw_payload'] as String,
      urlAnalysis: json['url_analysis'] != null
          ? UrlAnalysis.fromJson(json['url_analysis'] as Map<String, dynamic>)
          : null,
      threats: (json['threats'] as List<dynamic>)
          .map((e) => ThreatIndicator.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: List<String>.from(json['categories'] as List<dynamic>),
      analysedAt: json['analysed_at'] as String,
      durationMs: json['duration_ms'] as int,
    );
  }
}

class UrlAnalysis {
  final String originalUrl;
  final String finalUrl;
  final List<RedirectHop> redirectChain;
  final int httpStatus;
  final String? pageTitle;
  final bool hasSsl;
  final int? certAgeDays;
  final int? domainAgeDays;
  final String? ipAddress;
  final String? country;
  final List<String> suspiciousPatterns;

  const UrlAnalysis({
    required this.originalUrl,
    required this.finalUrl,
    required this.redirectChain,
    required this.httpStatus,
    this.pageTitle,
    required this.hasSsl,
    this.certAgeDays,
    this.domainAgeDays,
    this.ipAddress,
    this.country,
    required this.suspiciousPatterns,
  });

  factory UrlAnalysis.fromJson(Map<String, dynamic> json) {
    return UrlAnalysis(
      originalUrl: json['original_url'] as String,
      finalUrl: json['final_url'] as String,
      redirectChain: (json['redirect_chain'] as List<dynamic>)
          .map((e) => RedirectHop.fromJson(e as Map<String, dynamic>))
          .toList(),
      httpStatus: json['http_status'] as int,
      pageTitle: json['page_title'] as String?,
      hasSsl: json['has_ssl'] as bool,
      certAgeDays: json['cert_age_days'] as int?,
      domainAgeDays: json['domain_age_days'] as int?,
      ipAddress: json['ip_address'] as String?,
      country: json['country'] as String?,
      suspiciousPatterns: List<String>.from(
          json['suspicious_patterns'] as List<dynamic>),
    );
  }
}

class RedirectHop {
  final int hop;
  final String url;
  final int statusCode;

  const RedirectHop({
    required this.hop,
    required this.url,
    required this.statusCode,
  });

  factory RedirectHop.fromJson(Map<String, dynamic> json) {
    return RedirectHop(
      hop: json['hop'] as int,
      url: json['url'] as String,
      statusCode: json['status_code'] as int,
    );
  }
}

class ThreatIndicator {
  final String type;
  final String severity;   // low | medium | high | critical
  final String description;
  final String? evidence;

  const ThreatIndicator({
    required this.type,
    required this.severity,
    required this.description,
    this.evidence,
  });

  factory ThreatIndicator.fromJson(Map<String, dynamic> json) {
    return ThreatIndicator(
      type: json['type'] as String,
      severity: json['severity'] as String,
      description: json['description'] as String,
      evidence: json['evidence'] as String?,
    );
  }
}

// ── Exception ─────────────────────────────────────────────────────────────

class SandboxException implements Exception {
  final String code;
  final String message;

  const SandboxException({required this.code, required this.message});

  @override
  String toString() => 'SandboxException($code): $message';
}
