class Student {
  final String studentId;
  final String fullName;
  final String email;
  final String department;
  final String program;
  final int yearLevel;
  final String block;

  const Student({
    required this.studentId,
    required this.fullName,
    required this.email,
    required this.department,
    required this.program,
    required this.yearLevel,
    required this.block,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      studentId: json['student_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      department: json['department'] as String,
      program: json['program'] as String,
      yearLevel: (json['year_level'] as num).toInt(),
      block: json['block'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'full_name': fullName,
      'email': email,
      'department': department,
      'program': program,
      'year_level': yearLevel,
      'block': block,
    };
  }
}
