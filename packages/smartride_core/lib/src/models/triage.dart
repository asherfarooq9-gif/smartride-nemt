class TriageResult {
  const TriageResult({
    required this.symptomText,
    required this.predictedSpecialty,
    required this.confidenceScore,
    required this.severityLevel,
  });

  final String symptomText;
  final String predictedSpecialty;
  final double confidenceScore;
  final String severityLevel;

  bool get isCritical => severityLevel == 'critical' || severityLevel == 'high';

  factory TriageResult.fromJson(Map<String, dynamic> json) => TriageResult(
        symptomText: json['symptom_text'] as String? ?? '',
        predictedSpecialty: json['predicted_specialty'] as String? ?? '',
        confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
        severityLevel: json['severity_level'] as String? ?? 'medium',
      );
}
