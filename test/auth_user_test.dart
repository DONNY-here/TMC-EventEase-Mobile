
import 'package:flutter_test/flutter_test.dart';
import 'package:clone/models/auth_user.dart';

void main() {
  test('Student role is recognized correctly', () {
    const user = AuthUser(
      id: '1',
      name: 'Student User',
      email: 'student@tmc.edu.ph',
      role: 'student',
    );

    expect(user.isStudent, true);
    expect(user.isScanner, false);
  });

  test('Scanner role is recognized correctly', () {
    const user = AuthUser(
      id: '2',
      name: 'Event Officer',
      email: 'scanner@tmc.edu.ph',
      role: 'scanner',
    );

    expect(user.isScanner, true);
    expect(user.isStudent, false);
  });

  test('User data can be read from API JSON', () {
    final user = AuthUser.fromJson({
      'id': 3,
      'name': 'TMC Student',
      'email': 'user@tmc.edu.ph',
      'role': 'student',
    });

    expect(user.id, '3');
    expect(user.name, 'TMC Student');
    expect(user.role, 'student');
  });
}
