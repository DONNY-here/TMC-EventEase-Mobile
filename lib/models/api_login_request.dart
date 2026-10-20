class ApiLoginRequest {
  final String schoolId;
  final String password;

  const ApiLoginRequest({required this.schoolId, required this.password});

  Map<String, dynamic> toJson() {
    return {'school_id': schoolId.trim(), 'password': password};
  }
}
