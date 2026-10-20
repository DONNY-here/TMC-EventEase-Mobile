part of 'main.dart';

// Authenticated Laravel student profile editing. No changes to login/logout.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController schoolIdController;
  late final TextEditingController currentPasswordController;
  late final TextEditingController blockController;
  late final TextEditingController departmentController;
  String selectedCourse = '';
  String selectedYear = '';
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String _originalEmail = '';
  String _originalSchoolId = '';
  bool _passwordVisible = false;
  String _originalName = '';
  String _originalCourse = '';
  String _originalYear = '';
  String _originalBlock = '';
  String _originalDepartment = '';

  // r department codes. Course options match the registration UI;
  // AcademicStructure on Laravel remains the final authority.
  static const Map<String, String> _departmentNames = {
    'CCS': 'College of Computer Studies',
    'COED': 'College of Education',
    'CCJE': 'College of Criminal Justice Education',
    'COAD': 'College of Office Administration',
    'CAS': 'College of Arts and Sciences',
  };

  static const Map<String, List<String>> _departmentCourses = {
    'CCS': ['BSIT'],
    'COED': ['BEED', 'BSED'],
    'CCJE': ['BSCRIM'],
    'COAD': ['BSOA'],
    'CAS': ['AB Political Science', 'AB Communication'],
  };

  String selectedDepartment = '';

  String _resolveDepartment(String raw, String course) {
    final normalized = raw.trim().toLowerCase();
    for (final entry in _departmentNames.entries) {
      if (entry.key.toLowerCase() == normalized ||
          entry.value.toLowerCase() == normalized) {
        return entry.key;
      }
    }
    // Infer only when the API does not provide department.
    if (normalized.isEmpty) {
      for (final entry in _departmentCourses.entries) {
        if (entry.value.any(
          (c) => c.toLowerCase() == course.trim().toLowerCase(),
        )) {
          return entry.key;
        }
      }
    }
    return raw.trim();
  }

  static const _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: savedName);
    emailController = TextEditingController(text: savedEmail);
    schoolIdController = TextEditingController(text: savedStudentId);
    currentPasswordController = TextEditingController();
    _originalEmail = savedEmail;
    _originalSchoolId = savedStudentId;
    blockController = TextEditingController();
    departmentController = TextEditingController(text: savedDepartment);
    _originalDepartment = savedDepartment;
    selectedDepartment = _resolveDepartment(savedDepartment, savedCourse);
    _applyFields(
      name: savedName,
      course: savedCourse,
      year: savedYear,
      block: savedBlock,
    );
    if (ApiConfig.useRealApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchProfile();
      });
    }
  }

  String _str(Object? value) => value == null ? '' : value.toString().trim();

  Uri _endpoint(String path) {
    final base = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw StateError('The secure API URL is not configured.');
    }
    return base.replace(path: path, query: null, fragment: null);
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await authTokenStorage.readValidToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Your session expired. Please log in again.');
    }
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _userRecord(Object? decoded) {
    if (decoded is! Map) {
      throw const FormatException('Invalid profile response.');
    }
    final body = Map<String, dynamic>.from(decoded);
    final inner = body['user'] ?? body['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return body;
  }

  String _serverError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        final errors = body['errors'];
        if (errors is Map && errors.isNotEmpty) {
          const fieldNames = {
            'department': 'Department',
            'course': 'Course / Program',
            'year': 'Year Level',
            'block_no': 'Block',
            'student_id': 'School ID',
            'school_id': 'School ID',
            'email': 'Email',
            'current_password': 'Current Password',
            'name': 'Full Name',
          };
          for (final entry in errors.entries) {
            final messages = entry.value;
            final message = messages is List && messages.isNotEmpty
                ? messages.first.toString()
                : messages is String
                ? messages
                : '';
            if (message.isNotEmpty) {
              return '${fieldNames[entry.key] ?? entry.key}: $message';
            }
          }
        }
        if (body['message'] is String) return body['message'];
      }
    } catch (_) {}
    if (response.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }
    if (response.statusCode == 403) {
      return 'Only Student accounts can update profiles.';
    }
    return 'eventEase returned HTTP ${response.statusCode}.';
  }

  // Laravel accepts nullable block_no strings of up to 50 characters,
  // including alphanumeric values such as B, 12, and Block 12.
  String _readBlock(Object? raw) => _str(raw);

  // Keep the two-digit prefix and up to six digits after the dash.
  String _formatSchoolId(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    if (limited.length <= 2) return limited;
    return '${limited.substring(0, 2)}-${limited.substring(2)}';
  }

  void _applyFields({
    required String name,
    required String course,
    required String year,
    required String block,
  }) {
    nameController.text = name;
    selectedCourse = course;
    selectedYear = year;
    blockController.text = _readBlock(block);
    _originalName = name;
    _originalCourse = course;
    _originalYear = year;
    _originalBlock = blockController.text;
  }

  Future<void> _fetchProfile() async {
    if (_loading || _saving) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http
          .get(_endpoint('/api/auth/me'), headers: await _headers())
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError(_serverError(response));
      final user = _userRecord(jsonDecode(response.body));
      // Don't silently overwrite the UI with a malformed API response.
      if (!user.containsKey('name')) {
        throw const FormatException('Profile response is missing name.');
      }
      if (!mounted) return;
      setState(() {
        final name = _str(user['name']);
        final course = _str(user['course']);
        final year = _str(user['year']);
        final block = _str(user['block_no']);
        // Department may be a top-level string or a related object.
        final departmentValue = user['department'];
        final department = departmentValue is Map
            ? _str(departmentValue['name'] ?? departmentValue['code'])
            : _str(departmentValue);
        selectedDepartment = _resolveDepartment(department, course);
        savedDepartment = selectedDepartment;
        departmentController.text = selectedDepartment;
        _originalDepartment = selectedDepartment;
        _applyFields(name: name, course: course, year: year, block: block);
        savedName = name;
        savedCourse = course;
        savedYear = year;
        savedBlock = block;
        if (user['email'] != null) {
          savedEmail = _str(user['email']);
          emailController.text = savedEmail;
          _originalEmail = savedEmail;
        }
        // Some Laravel account responses use student_id instead of school_id.
        final rawId = user['school_id'] ?? user['student_id'];
        if (rawId != null) {
          savedStudentId = _str(rawId);
          schoolIdController.text = savedStudentId;
          _originalSchoolId = savedStudentId;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is StateError
              ? e.message.toString()
              : e is FormatException
              ? e.message
              : 'Could not retrieve your profile. Please retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> saveChanges() async {
    if (_saving || _loading || (ApiConfig.useRealApi && _error != null)) return;
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final schoolId = schoolIdController.text.trim();
    final blockText = blockController.text.trim();
    final department = selectedDepartment;

    final emailChanged = email != _originalEmail;
    final schoolIdChanged = schoolId != _originalSchoolId;
    final identifierChanged = emailChanged || schoolIdChanged;

    if (name.isEmpty || name.length > 255) {
      showMessage(context, 'Enter a name between 1 and 255 characters.');
      return;
    }
    if (blockText.length > 50) {
      showMessage(context, 'Block must not exceed 50 characters.');
      return;
    }
    if (!_departmentCourses.containsKey(department)) {
      showMessage(context, 'Select a valid department.');
      return;
    }
    if (!_departmentCourses[department]!.contains(selectedCourse) &&
        !(department ==
                _resolveDepartment(_originalDepartment, _originalCourse) &&
            selectedCourse == _originalCourse)) {
      showMessage(context, 'Select a course offered by your department.');
      return;
    }
    if (selectedCourse.isEmpty || selectedYear.isEmpty) {
      showMessage(context, 'Course and year are required.');
      return;
    }
    if (emailChanged &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      showMessage(context, 'Enter a valid email address.');
      return;
    }
    if (schoolIdChanged && !RegExp(r'^\d{2}-\d{6}$').hasMatch(schoolId)) {
      showMessage(context, 'Enter a School ID such as 24-123456.');
      return;
    }
    if (identifierChanged && currentPasswordController.text.isEmpty) {
      showMessage(
        context,
        'Enter your current password to change School ID or email.',
      );
      return;
    }

    final changes = <String, dynamic>{};
    if (name != _originalName) changes['name'] = name;
    if (department !=
        _resolveDepartment(_originalDepartment, _originalCourse)) {
      changes['department'] = department;
      // Changing department requires a compatible course in the same PUT.
      changes['course'] = selectedCourse;
    }
    if (selectedCourse != _originalCourse) changes['course'] = selectedCourse;
    if (selectedYear != _originalYear) changes['year'] = selectedYear;
    if (blockText != _originalBlock) {
      changes['block_no'] = blockText.isEmpty ? null : blockText;
    }
    if (emailChanged) changes['email'] = email;
    if (schoolIdChanged) changes['school_id'] = schoolId;
    if (identifierChanged) {
      changes['current_password'] = currentPasswordController.text;
    }
    if (changes.isEmpty) {
      showMessage(context, 'No changes to save.');
      return;
    }

    if (!ApiConfig.useRealApi) {
      savedName = name;
      savedDepartment = department;
      savedCourse = selectedCourse;
      savedYear = selectedYear;
      savedBlock = blockText;
      savedEmail = email;
      savedStudentId = schoolId;
      currentPasswordController.clear();
      if (!mounted) return;
      showMessage(context, 'Demo profile updated locally.');
      Navigator.pop(context, true);
      return;
    }

    setState(() => _saving = true);
    try {
      final response = await http
          .put(
            _endpoint('/api/auth/profile'),
            headers: await _headers(json: true),
            body: jsonEncode(changes),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError(_serverError(response));
      final user = _userRecord(jsonDecode(response.body));
      if (!user.containsKey('name')) {
        throw const FormatException('Invalid profile update response.');
      }
      if (!mounted) return;
      // Laravel derives department from the persisted course. Compare its
      // canonical department code, not a display name.
      final responseDepartment = user['department'];
      final savedValue = responseDepartment is Map
          ? _str(responseDepartment['code'] ?? responseDepartment['name'])
          : _str(responseDepartment);
      final confirmedDepartment = _resolveDepartment(
        savedValue,
        _str(user['course']),
      );
      if (confirmedDepartment != department) {
        throw StateError(
          'eventEase did not confirm the selected department. '
          'Refresh the profile and verify department/course compatibility.',
        );
      }
      savedDepartment = confirmedDepartment;
      savedName = _str(user['name']);
      savedCourse = _str(user['course']);
      savedYear = _str(user['year']);
      final returnedBlock = _str(user['block_no']);
      savedBlock = returnedBlock;
      savedEmail = _str(user['email'] ?? email);
      savedStudentId = _str(
        user['school_id'] ?? user['student_id'] ?? schoolId,
      );
      currentPasswordController.clear();
      showMessage(context, 'Profile updated!');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showMessage(
        context,
        e is StateError
            ? e.message.toString()
            : e is FormatException
            ? e.message
            : 'Update could not be confirmed. Refresh before retrying.',
      );
    } finally {
      currentPasswordController.clear();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    schoolIdController.dispose();
    currentPasswordController.dispose();
    blockController.dispose();
    departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final courseChoices = <String>{
      ...?_departmentCourses[selectedDepartment],
      if (selectedCourse.isNotEmpty &&
          selectedDepartment ==
              _resolveDepartment(_originalDepartment, _originalCourse))
        selectedCourse,
    }.toList();
    final departmentChoices = <String>{
      ..._departmentCourses.keys,
      if (selectedDepartment.isNotEmpty &&
          !_departmentCourses.containsKey(selectedDepartment))
        selectedDepartment,
    }.toList();
    final yearChoices = <String>{
      if (selectedYear.isNotEmpty) selectedYear,
      ..._years,
    }.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (ApiConfig.useRealApi)
            IconButton(
              onPressed: (_loading || _saving) ? null : _fetchProfile,
              tooltip: 'Refresh profile',
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: appGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.manage_accounts_rounded,
                          color: yellow,
                          size: 34,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Update Profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Keep your student information up to date.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        children: [
                          Text(_error!, style: TextStyle(color: scheme.error)),
                          TextButton.icon(
                            onPressed: _fetchProfile,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: nameController,
                            enabled: !_loading && !_saving,
                            maxLength: 255,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: emailController,
                            enabled: !_loading && !_saving,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: schoolIdController,
                            enabled: !_loading && !_saving,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              TextInputFormatter.withFunction((
                                oldValue,
                                newValue,
                              ) {
                                final text = _formatSchoolId(newValue.text);
                                return TextEditingValue(
                                  text: text,
                                  selection: TextSelection.collapsed(
                                    offset: text.length,
                                  ),
                                );
                              }),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'School ID',
                              hintText: '24-123456',
                              helperText:
                                  'Auto-formatted after the first two digits',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            key: ValueKey('department:$selectedDepartment'),
                            initialValue: selectedDepartment.isEmpty
                                ? null
                                : selectedDepartment,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              prefixIcon: Icon(Icons.account_balance_outlined),
                            ),
                            items: departmentChoices
                                .map(
                                  (department) => DropdownMenuItem<String>(
                                    value: department,
                                    child: Text(
                                      department,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (_loading || _saving)
                                ? null
                                : (value) {
                                    if (value == null ||
                                        !_departmentCourses.containsKey(
                                          value,
                                        )) {
                                      return;
                                    }
                                    setState(() {
                                      selectedDepartment = value;
                                      selectedCourse =
                                          _departmentCourses[value]!.first;
                                    });
                                  },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'course:$selectedDepartment:$selectedCourse',
                            ),
                            initialValue: courseChoices.contains(selectedCourse)
                                ? selectedCourse
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Course / Program',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            items: courseChoices
                                .map(
                                  (course) => DropdownMenuItem<String>(
                                    value: course,
                                    child: Text(
                                      course,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged:
                                (_loading || _saving || courseChoices.isEmpty)
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => selectedCourse = value);
                                    }
                                  },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            key: ValueKey('year:$selectedYear'),
                            initialValue: selectedYear.isEmpty
                                ? null
                                : selectedYear,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Year Level',
                              prefixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                            items: yearChoices
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (_loading || _saving)
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => selectedYear = value);
                                    }
                                  },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: blockController,
                            enabled: !_loading && !_saving,
                            keyboardType: TextInputType.text,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(50),
                            ],
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (value) =>
                                value != null && value.trim().length > 50
                                ? 'Block must not exceed 50 characters.'
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Block',
                              hintText: 'e.g. 1',
                              helperText: 'Enter your block number',
                              prefixIcon: Icon(Icons.groups_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Course and year values must be accepted by eventEase. '
                            'The server validates all edits.',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: currentPasswordController,
                            enabled: !_loading && !_saving,
                            obscureText: !_passwordVisible,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Current Password',
                              helperText:
                                  'Required when changing School ID or email',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _passwordVisible
                                    ? 'Hide password'
                                    : 'Show password',
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed:
                                  (_saving ||
                                      _loading ||
                                      (ApiConfig.useRealApi && _error != null))
                                  ? null
                                  : saveChanges,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                _saving
                                    ? 'Saving...'
                                    : ApiConfig.useRealApi
                                    ? 'Save Changes'
                                    : 'Save Demo Changes',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const ProfileInfo({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: lightNavy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: navy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
