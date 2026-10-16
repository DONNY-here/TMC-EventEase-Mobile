class ApiLoginRequest {
  final String email;
  final String password;

  const ApiLoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() {
    return {'email': email.trim(), 'password': password};
  }
}
