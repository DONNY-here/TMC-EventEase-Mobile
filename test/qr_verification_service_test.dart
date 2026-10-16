
import 'package:flutter_test/flutter_test.dart';

import 'package:clone/services/qr_verification_service.dart';

void main() {
  group('QR Verification Service Tests', () {
    test('Valid student QR records attendance', () async {
      final service = QrVerificationService();

      service.addTestRegistration(
        token: 'TEST_TOKEN_001',
        eventId: 'EVENT_001',
        studentName: 'Sample Student',
      );

      final result = await service.verifyQr(
        token: 'TEST_TOKEN_001',
        eventId: 'EVENT_001',
        eventTitle: 'CCS Programming Competition',
      );

      expect(result.success, true);
      expect(result.status, 'present');
      expect(result.studentName, 'Sample Student');
      expect(result.checkInTime, isNotNull);
    });

    test('Duplicate QR is rejected', () async {
      final service = QrVerificationService();

      service.addTestRegistration(
        token: 'TEST_TOKEN_001',
        eventId: 'EVENT_001',
        studentName: 'Sample Student',
      );

      await service.verifyQr(
        token: 'TEST_TOKEN_001',
        eventId: 'EVENT_001',
        eventTitle: 'CCS Programming Competition',
      );

      final duplicate = await service.verifyQr(
        token: 'TEST_TOKEN_001',
        eventId: 'EVENT_001',
        eventTitle: 'CCS Programming Competition',
      );

      expect(duplicate.success, false);
      expect(duplicate.status, 'duplicate');
    });

    test('Unknown QR is rejected', () async {
      final service = QrVerificationService();

      final result = await service.verifyQr(
        token: 'UNKNOWN_TOKEN',
        eventId: 'EVENT_001',
        eventTitle: 'CCS Programming Competition',
      );

      expect(result.success, false);
      expect(result.status, 'invalid');
    });

    test('QR for another event is rejected', () async {
      final service = QrVerificationService();

      service.addTestRegistration(
        token: 'TEST_TOKEN_001',
        eventId: 'EVENT_001',
        studentName: 'Sample Student',
      );

      final result = await service.verifyQr(
        token: 'TEST_TOKEN_001',
        eventId: 'EVENT_002',
        eventTitle: 'TMC Leadership Training',
      );

      expect(result.success, false);
      expect(result.status, 'invalid');
    });
  });
}
