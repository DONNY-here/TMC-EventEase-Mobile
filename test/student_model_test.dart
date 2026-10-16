
import 'package:flutter_test/flutter_test.dart';

import 'package:clone/models/student_model.dart';

import 'package:flutter/foundation.dart';

void main() {
  test('Student model should store correct information', () {

    // Create a sample student
    const student = Student(
      studentId: '2026-0001',
      fullName: 'Sample Student',
      email: 'student@example.com',
      department: 'College of Computer Studies',
      program: 'BSIT',
      yearLevel: 3,
      block: 'Block 1',
    );

    // Display student information
    debugPrint('Name: ${student.fullName}');
    debugPrint('Email: ${student.email}');
    debugPrint('Department: ${student.department}');
    debugPrint('Program: ${student.program}');
    debugPrint('Year Level: ${student.yearLevel}');
    debugPrint('Block: ${student.block}');

    // Verify student information
    expect(student.studentId, '2026-0001');
    expect(student.fullName, 'Sample Student');
    expect(student.department, 'College of Computer Studies');
    expect(student.program, 'BSIT');
    expect(student.yearLevel, 3);
    expect(student.block, 'Block 1');
  });

  test('Student should convert correctly to and from JSON', () {
    const student = Student(
      studentId: '2026-0001',
      fullName: 'Sample Student',
      email: 'student@example.com',
      department: 'College of Computer Studies',
      program: 'BSIT',
      yearLevel: 3,
      block: 'Block 1',
    );

    final json = student.toJson();
    final restoredStudent = Student.fromJson(json);

    expect(restoredStudent.studentId, student.studentId);
    expect(restoredStudent.fullName, student.fullName);
    expect(restoredStudent.email, student.email);
    expect(restoredStudent.department, student.department);
    expect(restoredStudent.program, student.program);
    expect(restoredStudent.yearLevel, student.yearLevel);
    expect(restoredStudent.block, student.block);

    debugPrint('Student JSON conversion successful!');
  });
}
