part of 'main.dart';

// Student-facing editor. Official identity/enrollment fields are read-only.
// Laravel must independently enforce this policy on PUT /api/auth/profile.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _blockController;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String _name = '';
  String _email = '';
  String _schoolId = '';
  String _department = '';
  String _course = '';
  String _year = '';
  String _studentStatus = '';
  String _originalBlock = '';

  @override
  void initState() {
    super.initState();
    _name = savedName;
    _email = savedEmail;
    _schoolId = savedStudentId;
    _department = savedDepartment;
    _course = savedCourse;
    _year = savedYear;
    _blockController = TextEditingController(text: _blockNumber(savedBlock));
    _originalBlock = _blockNumber(savedBlock);
    if (ApiConfig.useRealApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchProfile();
      });
    }
  }

  String _str(Object? value) => value == null ? '' : value.toString().trim();

  // Accept legacy "Block 5" records, but always display digits only.
  // No arbitrary upper block number is imposed by the Flutter form.
  String _blockNumber(Object? value) {
    final text = _str(value).replaceFirst(
      RegExp(r'^Block\s*', caseSensitive: false),
      '',
    );
    if (!RegExp(r'^[0-9]+$').hasMatch(text)) return '';
    final normalized = text.replaceFirst(RegExp(r'^0+'), '');
    return normalized.isEmpty ? '' : normalized;
  }

  Uri _uri(String path) {
    final base = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw StateError('Configure a valid HTTPS API URL.');
    }
    return base.replace(path: path, query: null, fragment: null);
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await authTokenStorage.readValidToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Your session has expired. Sign in again.');
    }
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _user(Object? decoded) {
    if (decoded is! Map) throw const FormatException('Invalid profile response.');
    final map = Map<String, dynamic>.from(decoded);
    final nested = map['user'] ?? map['data'];
    return nested is Map ? Map<String, dynamic>.from(nested) : map;
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final fields = decoded['errors'];
        if (fields is Map) {
          for (final value in fields.values) {
            if (value is List && value.isNotEmpty) return '${value.first}';
            if (value is String && value.isNotEmpty) return value;
          }
        }
        if (decoded['message'] is String) return decoded['message'];
      }
    } catch (_) {}
    if (response.statusCode == 401) return 'Session expired. Sign in again.';
    if (response.statusCode == 403) return 'Your account cannot update this profile.';
    return 'Request failed (HTTP ${response.statusCode}).';
  }

  String _status(Object? value) {
    final raw = _str(value).toLowerCase();
    if (raw == 'regular') return 'Regular';
    if (raw == 'irregular') return 'Irregular';
    return 'Not provided';
  }

  void _fill(Map<String, dynamic> user) {
    _name = _str(user['name']);
    _email = _str(user['email']);
    _schoolId = _str(user['student_id'] ?? user['school_id']);
    _course = _str(user['course']);
    _year = _str(user['year']);
    _studentStatus = _status(user['student_status']);
    final dept = user['department'];
    _department = dept is Map
        ? _str(dept['name'] ?? dept['code'])
        : _str(user['department_name'] ?? dept);
    if (_department.isEmpty) _department = savedDepartment;
    _originalBlock = _blockNumber(user['block_no'] ?? user['block']);
    _blockController.text = _originalBlock;
    savedName = _name;
    savedEmail = _email;
    savedStudentId = _schoolId;
    savedDepartment = _department;
    savedCourse = _course;
    savedYear = _year;
    savedBlock = _originalBlock;
  }

  Future<void> _fetchProfile() async {
    if (_loading || _saving) return;
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(
        _uri('/api/auth/me'), headers: await _headers(),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError(_errorMessage(response));
      final user = _user(jsonDecode(response.body));
      if (!user.containsKey('name')) {
        throw const FormatException('Profile response does not contain student details.');
      }
      if (!mounted) return;
      setState(() => _fill(user));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message.toString()
            : error is FormatException
            ? error.message
            : 'Could not connect. Check your internet.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_loading || _saving || (ApiConfig.useRealApi && _error != null)) return;
    final rawBlock = _blockController.text.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(rawBlock) ||
        !RegExp(r'[1-9]').hasMatch(rawBlock)) {
      showMessage(context, 'Enter your block number.');
      return;
    }
    final block = _blockNumber(rawBlock);
    if (block == _originalBlock) {
      showMessage(context, 'No changes to save.');
      return;
    }
    if (!ApiConfig.useRealApi) {
      savedBlock = block;
      if (!mounted) return;
      showMessage(context, 'Demo block updated locally.');
      Navigator.pop(context, true);
      return;
    }
    setState(() => _saving = true);
    try {
      // Only the block is sent. Read-only fields are never included in the request.
      final response = await http.put(
        _uri('/api/auth/profile'),
        headers: await _headers(json: true),
        body: jsonEncode({'block_no': block.isEmpty ? null : block}),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError(_errorMessage(response));
      final user = _user(jsonDecode(response.body));
      if (!user.containsKey('block_no')) {
        throw const FormatException('Failed to confirm the block update.');
      }
      final saved = _blockNumber(user['block_no']);
      if (saved != block) {
        throw StateError('Returned a different block. Refresh the profile.');
      }
      if (!mounted) return;
      setState(() => _fill(user));
      showMessage(context, 'Block updated successfully.');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      showMessage(context, error is StateError
          ? error.message.toString()
          : error is FormatException
          ? error.message
          : 'Update could not be confirmed. Refresh before retrying.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _blockController.dispose();
    super.dispose();
  }

  Widget _readOnlyTile(IconData icon, String label, String value,
      Color ink, Color muted, Color border) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        Icon(icon, color: muted, size: 21),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(value.isEmpty ? 'Not provided' : value,
              style: TextStyle(color: ink, fontSize: 14, fontWeight: FontWeight.w600)),
        ])),
        Icon(Icons.lock_outline_rounded, color: muted, size: 16),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0B1424) : const Color(0xFFF3F6FB);
    final surface = dark ? const Color(0xFF17263C) : Colors.white;
    final ink = dark ? const Color(0xFFF1F6FD) : const Color(0xFF17283F);
    final muted = dark ? const Color(0xFFB2C0D0) : const Color(0xFF657489);
    final border = dark ? const Color(0xFF31445C) : const Color(0xFFE0E7EF);
    Widget panel(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: child,
    );
    Widget split() => Divider(height: 1, color: border);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(
            color: ink, fontWeight: FontWeight.w800, fontSize: 20)),
        backgroundColor: bg,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        actions: [if (ApiConfig.useRealApi)
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _loading || _saving ? null : _fetchProfile,
            icon: const Icon(Icons.refresh_rounded),
          )],
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: appGradient,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.manage_accounts_rounded, color: yellow, size: 32),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manage your profile', style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 19)),
                    SizedBox(height: 4),
                    Text('Review school records and update your block.',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                )),
              ]),
            ),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator()),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: panel(Column(children: [
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                TextButton.icon(onPressed: _loading ? null : _fetchProfile,
                    icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ])),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Icon(Icons.lock_outline_rounded, color: muted, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Official school information',
                  style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 17))),
            ]),
            const SizedBox(height: 5),
            Text('To correct these details, contact the school administrator.',
                style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 10),
            panel(Column(children: [
              _readOnlyTile(Icons.person_outline, 'Full Name', _name, ink, muted, border),
              split(),
              _readOnlyTile(Icons.badge_outlined, 'School ID', _schoolId, ink, muted, border),
              split(),
              _readOnlyTile(Icons.account_balance_outlined, 'Department',
                  _department, ink, muted, border),
              split(),
              _readOnlyTile(Icons.school_outlined, 'Course / Program',
                  _course, ink, muted, border),
              split(),
              _readOnlyTile(Icons.calendar_month_outlined, 'Year Level',
                  _year, ink, muted, border),
              split(),
              _readOnlyTile(Icons.verified_user_outlined, 'Student Status',
                  _studentStatus, ink, muted, border),
            ])),
            const SizedBox(height: 20),
            Text('Contact information',
                style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 10),
            panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _readOnlyTile(Icons.email_outlined, 'Email Address',
                  _email, ink, muted, border),
              Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(
                  'Email changes are temporarily unavailable until verification is enabled.',
                  style: TextStyle(color: muted, fontSize: 12))),
            ])),
            const SizedBox(height: 20),
            Text('Editable information',
                style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 10),
            panel(Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: TextFormField(
                controller: _blockController,
                enabled: !_loading && !_saving && _error == null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Block',
                  hintText: 'e.g. 1',

                  prefixIcon: Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            )),
            const SizedBox(height: 16),
            SizedBox(height: 52, child: FilledButton.icon(
              onPressed: _loading || _saving || _error != null ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: navy,
                  foregroundColor: Colors.white),
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save Block Changes'),
            )),
            const SizedBox(height: 10),
            Text('All profile changes are checked by the Laravel server.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11)),
          ]),
        )),
      )),
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
