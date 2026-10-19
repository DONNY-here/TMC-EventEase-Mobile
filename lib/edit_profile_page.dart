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
  late final TextEditingController blockController;
  String selectedCourse = '';
  String selectedYear = '';
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String _originalName = '';
  String _originalCourse = '';
  String _originalYear = '';
  String _originalBlock = '';

  static const _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: savedName);
    emailController = TextEditingController(text: savedEmail);
    blockController = TextEditingController();
    _applyFields(name: savedName, course: savedCourse,
        year: savedYear, block: savedBlock);
    if (ApiConfig.useRealApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchProfile();
      });
    }
  }

  String _str(Object? value) => value == null ? '' : value.toString().trim();

  Uri _endpoint(String path) {
    final base = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty || (base.path.isNotEmpty && base.path != '/')) {
      throw StateError('The secure Laravel API URL is not configured.');
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
    if (decoded is! Map) throw const FormatException('Invalid profile response.');
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
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
          if (first is String && first.isNotEmpty) return first;
        }
        if (body['message'] is String) return body['message'];
      }
    } catch (_) {}
    if (response.statusCode == 401) return 'Session expired. Please log in again.';
    if (response.statusCode == 403) return 'Only Student accounts can update profiles.';
    return 'Laravel returned HTTP ${response.statusCode}.';
  }

  String _readBlock(Object? raw) {
    final normalized = normalizeTmcBlock(raw);
    return normalized == null ? _str(raw) : normalized.substring(6);
  }

  void _applyFields({required String name, required String course,
    required String year, required String block}) {
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
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(_endpoint('/api/auth/me'),
          headers: await _headers()).timeout(const Duration(seconds: 20));
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
        _applyFields(name: name, course: course, year: year, block: block);
        savedName = name;
        savedCourse = course;
        savedYear = year;
        savedBlock = normalizeTmcBlock(block) ?? block;
        // Keep identifiers read-only and update their display only when supplied.
        if (user['email'] != null) {
          savedEmail = _str(user['email']);
          emailController.text = savedEmail;
        }
        if (user['school_id'] != null) savedStudentId = _str(user['school_id']);
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e is StateError ? e.message.toString()
            : e is FormatException ? e.message
            : 'Could not retrieve your profile. Please retry.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> saveChanges() async {
    if (_saving || _loading || (ApiConfig.useRealApi && _error != null)) return;
    final name = nameController.text.trim();
    final blockText = blockController.text.trim();
    final normalizedBlock = blockText.isEmpty ? null : normalizeTmcBlock(blockText);
    if (name.isEmpty || name.length > 255) {
      showMessage(context, 'Enter a name between 1 and 255 characters.');
      return;
    }
    if (blockText.isNotEmpty && normalizedBlock == null) {
      showMessage(context, 'Enter a valid block number from 1 to 11.');
      return;
    }
    if (selectedCourse.isEmpty || selectedYear.isEmpty) {
      showMessage(context, 'Course and year are required.');
      return;
    }
    if (!ApiConfig.useRealApi) {
      savedName = name;
      savedCourse = selectedCourse;
      savedYear = selectedYear;
      savedBlock = normalizedBlock ?? '';
      if (!mounted) return;
      showMessage(context, 'Demo profile updated locally.');
      Navigator.pop(context, true);
      return;
    }

    final changes = <String, dynamic>{};
    if (name != _originalName) changes['name'] = name;
    if (selectedCourse != _originalCourse) changes['course'] = selectedCourse;
    if (selectedYear != _originalYear) changes['year'] = selectedYear;
    if (blockText != _originalBlock) changes['block_no'] = blockText.isEmpty ? null
        : (normalizedBlock!.substring(6));
    if (changes.isEmpty) {
      showMessage(context, 'No changes to save.');
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await http.put(
        _endpoint('/api/auth/profile'),
        headers: await _headers(json: true),
        body: jsonEncode(changes),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError(_serverError(response));
      final user = _userRecord(jsonDecode(response.body));
      if (!user.containsKey('name')) throw const FormatException('Invalid update response.');
      if (!mounted) return;
      // The PUT response is authoritative; reopening will GET fresh data again.
      savedName = _str(user['name']);
      savedCourse = _str(user['course']);
      savedYear = _str(user['year']);
      final returnedBlock = _str(user['block_no']);
      savedBlock = normalizeTmcBlock(returnedBlock) ?? returnedBlock;
      showMessage(context, 'Profile updated in Laravel.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, e is StateError ? e.message.toString()
          : e is FormatException ? e.message
          : 'Update could not be confirmed. Refresh before retrying.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    blockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final courseChoices = <String>{
      if (selectedCourse.isNotEmpty) selectedCourse,
      ...courseOptions,
    }.toList();
    final yearChoices = <String>{
      if (selectedYear.isNotEmpty) selectedYear,
      ..._years,
    }.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'),
          actions: [if (ApiConfig.useRealApi)
            IconButton(onPressed: (_loading || _saving) ? null : _fetchProfile,
                tooltip: 'Refresh Laravel profile', icon: const Icon(Icons.refresh))]),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: appGradient,
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  Icon(Icons.manage_accounts_rounded, color: yellow, size: 34),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Update Profile', style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Keep your student information up to date.',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 14),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(children: [
                  Text(_error!, style: TextStyle(color: scheme.error)),
                  TextButton.icon(onPressed: _fetchProfile,
                      icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ]),
              ),
              Card(child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: nameController,
                    enabled: !_loading && !_saving,
                    maxLength: 255,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: emailController, readOnly: true,
                      decoration: const InputDecoration(labelText: 'Email (read-only)',
                          prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 14),
                  TextFormField(initialValue: savedStudentId, readOnly: true,
                      decoration: const InputDecoration(labelText: 'School ID (read-only)',
                          prefixIcon: Icon(Icons.badge_outlined))),
                  const SizedBox(height: 14),
                  TextFormField(initialValue: savedDepartment, readOnly: true,
                      decoration: const InputDecoration(labelText: 'Department (read-only)',
                          prefixIcon: Icon(Icons.account_balance_outlined))),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey('course:$selectedCourse'),
                    initialValue: selectedCourse.isEmpty ? null : selectedCourse,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Course / Program',
                        prefixIcon: Icon(Icons.school_outlined)),
                    items: courseChoices.map((value) => DropdownMenuItem<String>(
                        value: value, child: Text(value, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (_loading || _saving) ? null : (value) {
                      if (value != null) setState(() => selectedCourse = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey('year:$selectedYear'),
                    initialValue: selectedYear.isEmpty ? null : selectedYear,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Year Level',
                        prefixIcon: Icon(Icons.calendar_month_outlined)),
                    items: yearChoices.map((value) => DropdownMenuItem<String>(
                        value: value, child: Text(value, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (_loading || _saving) ? null : (value) {
                      if (value != null) setState(() => selectedYear = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: blockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (normalizeTmcBlock(value) == null) {
                        return 'Please enter a valid positive block number.';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Block Number',
                      hintText: 'e.g. 1',
                      helperText: 'Enter your assigned block number',
                      prefixIcon: Icon(Icons.groups_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Course and year values must be accepted by Laravel. '
                      'The server validates all edits.',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  SizedBox(height: 52, child: FilledButton.icon(
                    onPressed: (_saving || _loading ||
                        (ApiConfig.useRealApi && _error != null)) ? null : saveChanges,
                    icon: _saving ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Saving to Laravel...' :
                    ApiConfig.useRealApi ? 'Save Changes' : 'Save Demo Changes'),
                  )),
                ]),
              )),
            ]),
          )),
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
