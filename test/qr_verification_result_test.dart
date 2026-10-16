
import 'package:flutter_test/flutter_test.dart';
import 'package:clone/models/qr_verification_result.dart';

void main() {
  test('Successful QR response', () {
    final result = QrVerificationResult.fromJson({
      'success': true,
      'status': 'present',
      'message': 'Attendance recorded successfully.',
      'student_name': 'Sample Student',
      'event_title': 'CCS Programming Competition',
      'check_in_time': '11:47 AM',
    });

    expect(result.success, true);
    expect(result.status, 'present');
    expect(result.studentName, 'Sample Student');
    expect(result.checkInTime, '11:47 AM');
  });

  test('Duplicate QR response', () {
    final result = QrVerificationResult.fromJson({
      'success': false,
      'status': 'duplicate',
      'message': 'Attendance already recorded.',
    });

    expect(result.success, false);
    expect(result.status, 'duplicate');
  });
}
