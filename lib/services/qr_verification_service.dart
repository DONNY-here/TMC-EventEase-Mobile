import '../models/qr_verification_result.dart';

class QrVerificationService {
  // Temporary in-memory mock database.
  final Map<String, String> _registrations = {};
  final Map<String, DateTime> _attendanceRecords = {};

  // Add a test registration to the mock service.
  void addTestRegistration({
    required String token,
    required String eventId,
    required String studentName,
  }) {
    _registrations['$eventId|$token'] = studentName;
  }

  // Simulate an API request to verify attendance.
  Future<QrVerificationResult> verifyQr({
    required String token,
    required String eventId,
    required String eventTitle,
  }) async {
    // Simulate network processing.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final registrationKey = '$eventId|$token';

    if (token.isEmpty || !_registrations.containsKey(registrationKey)) {
      return const QrVerificationResult(
        success: false,
        status: 'invalid',
        message: 'QR code is not registered for the selected event.',
      );
    }

    final studentName = _registrations[registrationKey]!;

    // Reject duplicate attendance.
    if (_attendanceRecords.containsKey(registrationKey)) {
      return QrVerificationResult(
        success: false,
        status: 'duplicate',
        message: 'Attendance has already been recorded.',
        studentName: studentName,
        eventTitle: eventTitle,
        checkInTime: _formatTime(_attendanceRecords[registrationKey]!),
      );
    }

    final now = DateTime.now();
    _attendanceRecords[registrationKey] = now;

    return QrVerificationResult(
      success: true,
      status: 'present',
      message: 'TEST MODE: Attendance recorded successfully!',
      studentName: studentName,
      eventTitle: eventTitle,
      checkInTime: _formatTime(now),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;

    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}
