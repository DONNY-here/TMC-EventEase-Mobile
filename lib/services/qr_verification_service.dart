import '../models/qr_verification_result.dart';

// ======================================================
// TMC EVENTEASE - DEMO QR VERIFICATION SERVICE
// Local testing only - not official attendance validation
// ======================================================

class QrVerificationService {
  // Temporary in-memory registration database.
  final Map<String, String> _registrations = {};

  // Temporary attendance records.
  final Map<String, DateTime> _attendanceRecords = {};

  // Expected format of locally generated tokens.
  static final RegExp _validToken = RegExp(r'^[A-Za-z0-9]{40}$');

  // Unique key for one event registration.
  String _registrationKey(String eventId, String token) {
    return '$eventId|$token';
  }

  // ====================================================
  // ADD DEMO REGISTRATION
  // ====================================================

  void addTestRegistration({
    required String token,
    required String eventId,
    required String studentName,
  }) {
    final cleanToken = token.trim();
    final cleanEventId = eventId.trim();
    final cleanStudentName = studentName.trim();

    if (!_validToken.hasMatch(cleanToken) || cleanEventId.isEmpty) {
      return;
    }

    final key = _registrationKey(cleanEventId, cleanToken);

    // Do not overwrite existing registration details.
    _registrations.putIfAbsent(
      key,
      () => cleanStudentName.isEmpty ? 'Demo Student' : cleanStudentName,
    );
  }

  // ====================================================
  // VERIFY DEMO QR CODE
  // ====================================================

  Future<QrVerificationResult> verifyQr({
    required String token,
    required String eventId,
    required String eventTitle,
  }) async {
    // Simulate server processing for UI testing.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final cleanToken = token.trim();
    final cleanEventId = eventId.trim();

    // STEP 1: Validate token format.
    if (!_validToken.hasMatch(cleanToken) || cleanEventId.isEmpty) {
      return const QrVerificationResult(
        success: false,
        status: 'invalid',
        message: 'Invalid student QR code.',
      );
    }

    final key = _registrationKey(cleanEventId, cleanToken);

    // STEP 2: Check selected event registration.
    final studentName = _registrations[key];

    if (studentName == null) {
      // Check whether token belongs to another event.
      final wrongEvent = _registrations.keys.any(
        (registeredKey) => registeredKey.endsWith('|$cleanToken'),
      );

      if (wrongEvent) {
        return const QrVerificationResult(
          success: false,
          status: 'wrong_event',
          message: 'This QR code belongs to a different event.',
        );
      }

      return const QrVerificationResult(
        success: false,
        status: 'invalid',
        message: 'No matching demo event registration found.',
      );
    }

    // STEP 3: Reject duplicate attendance.
    final previousCheckIn = _attendanceRecords[key];

    if (previousCheckIn != null) {
      return QrVerificationResult(
        success: false,
        status: 'duplicate',
        message: 'Attendance has already been recorded.',
        studentName: studentName,
        eventTitle: eventTitle,
        checkInTime: _formatTime(previousCheckIn),
      );
    }

    // STEP 4: Record successful demo attendance.
    final now = DateTime.now();

    _attendanceRecords[key] = now;

    return QrVerificationResult(
      success: true,
      status: 'present',
      message: 'DEMO MODE: Attendance recorded successfully!',
      studentName: studentName,
      eventTitle: eventTitle,
      checkInTime: _formatTime(now),
    );
  }

  // ====================================================
  // CLEAR TEMPORARY SERVICE DATA
  // ====================================================

  void clearDemoData() {
    _registrations.clear();
    _attendanceRecords.clear();
  }

  // ====================================================
  // FORMAT CHECK-IN TIME
  // ====================================================

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;

    final minute = time.minute.toString().padLeft(2, '0');

    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}
