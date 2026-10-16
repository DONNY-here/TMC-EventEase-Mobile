class QrVerificationResult {
  final bool success;
  final String status;
  final String message;
  final String? studentName;
  final String? eventTitle;
  final String? checkInTime;

  const QrVerificationResult({
    required this.success,
    required this.status,
    required this.message,
    this.studentName,
    this.eventTitle,
    this.checkInTime,
  });

  factory QrVerificationResult.fromJson(Map<String, dynamic> json) {
    return QrVerificationResult(
      success: json['success'] == true,
      status: json['status'] as String? ?? 'error',
      message: json['message'] as String? ?? '',
      studentName: json['student_name'] as String?,
      eventTitle: json['event_title'] as String?,
      checkInTime: json['check_in_time'] as String?,
    );
  }
}
