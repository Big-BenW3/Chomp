enum QualitativeRating { critical, poor, standard, good, great, excellent }

/// Extension methods for [QualitativeRating].
///
/// Provides conversion between enum values and their string labels,
/// which is needed for JSON serialization/deserialization.
extension QualitativeRatingX on QualitativeRating {
  /// Creates a [QualitativeRating] from a case-insensitive string label.
  static QualitativeRating fromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'excellent':
        return QualitativeRating.excellent;
      case 'great':
        return QualitativeRating.great;
      case 'good':
        return QualitativeRating.good;
      case 'standard':
        return QualitativeRating.standard;
      case 'poor':
        return QualitativeRating.poor;
      case 'critical':
      default:
        return QualitativeRating.critical;
    }
  }

  /// Human-readable label for this rating.
  String get label {
    switch (this) {
      case QualitativeRating.excellent:
        return 'Excellent';
      case QualitativeRating.great:
        return 'Great';
      case QualitativeRating.good:
        return 'Good';
      case QualitativeRating.standard:
        return 'Standard';
      case QualitativeRating.poor:
        return 'Poor';
      case QualitativeRating.critical:
        return 'Critical';
    }
  }
}

/// Complete scan result for a single repository.
///
/// Contains numeric scores (0-100) from NVIDIA and qualitative ratings
/// from Groq, plus a list of specific findings/issues discovered.
class ScanResult {
  /// Unique identifier for this scan result.
  final String id;

  /// Foreign key to the scanned repository.
  final String repoId;

  /// Security score from NVIDIA (0-100, higher is better).
  final int? securityScore;

  /// Code quality score from NVIDIA (0-100, higher is better).
  final int? codeQualityScore;

  /// Documentation quality rating from Groq.
  final QualitativeRating? docsRating;

  /// One-sentence Groq rationale for the docs rating.
  final String? docsReasoning;

  /// Test coverage rating from Groq.
  final QualitativeRating? testsRating;

  /// One-sentence Groq rationale for the tests rating.
  final String? testsReasoning;

  /// List of specific findings/issues discovered during the scan.
  final List<String> findings;

  /// Timestamp when the scan was completed.
  final DateTime scannedAt;

  const ScanResult({
    required this.id,
    required this.repoId,
    this.securityScore,
    this.codeQualityScore,
    this.docsRating,
    this.docsReasoning,
    this.testsRating,
    this.testsReasoning,
    this.findings = const [],
    required this.scannedAt,
  });

  /// Creates a [ScanResult] from a JSON map returned by the backend.
  ///
  /// Handles null scores/ratings and parses the findings array from
  /// JSONB in the database.
  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        id: json['id'] as String,
        repoId: json['repo_id'] as String,
        securityScore: json['security_score'] as int?,
        codeQualityScore: json['code_quality_score'] as int?,
        docsRating: json['docs_rating'] != null
            ? QualitativeRatingX.fromLabel(json['docs_rating'] as String)
            : null,
        docsReasoning: _cleanReasoning(json['docs_reasoning']),
        testsRating: json['tests_rating'] != null
            ? QualitativeRatingX.fromLabel(json['tests_rating'] as String)
            : null,
        testsReasoning: _cleanReasoning(json['tests_reasoning']),
        findings: (json['findings'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        scannedAt: DateTime.parse(json['scanned_at'] as String),
      );

  /// Normalizes a reasoning string: blank becomes null so the UI can
  /// treat it as absent.
  static String? _cleanReasoning(dynamic raw) {
    if (raw is! String) return null;
    final s = raw.trim();
    return s.isEmpty ? null : s;
  }
}
