import 'package:flutter/material.dart';
import 'app_theme_controller.dart';

/// Profile presentation only. Authenticated data and callbacks are supplied by
/// ProfilePage, which remains responsible for GET /api/auth/me and logout.
class EventEaseProfileView extends StatelessWidget {
  final String name;
  final String email;
  final String studentId;
  final String department;
  final String course;
  final String year;
  final String block;
  final VoidCallback onEdit;
  final VoidCallback onLogout;
  final VoidCallback onResetPassword;

  const EventEaseProfileView({
    super.key,
    required this.name,
    required this.email,
    required this.studentId,
    required this.department,
    required this.course,
    required this.year,
    required this.block,
    required this.onEdit,
    required this.onLogout,
    required this.onResetPassword,
  });

  static const _navy = Color(0xFF0E3062);
  static const _blue = Color(0xFF194E91);
  static const _yellow = Color(0xFFFFCA40);

  bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;
  Color _line(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;
  Color _text(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  Color _muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  String _display(String value) =>
      value.trim().isEmpty ? 'Not provided' : value.trim();

  String _formattedBlock(String raw) {
    final value = raw.trim();
    final match = RegExp(
      r'^(?:Block\s*)?(\d+)$',
      caseSensitive: false,
    ).firstMatch(value);
    return match == null ? value : 'Block ${match.group(1)}';
  }

  String _formattedYear(String raw) {
    final value = raw.trim();
    final match = RegExp(
      r'^([1-4])(?:st|nd|rd|th)?(?:\s*Year)?$',
      caseSensitive: false,
    ).firstMatch(value);
    const years = {
      '1': '1st Year',
      '2': '2nd Year',
      '3': '3rd Year',
      '4': '4th Year',
    };
    return match == null ? value : years[match.group(1)] ?? value;
  }

  List<String> get _missingFields => {
    'Name': name,
    'School ID': studentId,
    'Email': email,
    'Department': department,
    'Course': course,
    'Year level': year,
    'Block': block,
  }.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key).toList();

  Widget _header(BuildContext context) {
    final details = [
      if (course.trim().isNotEmpty) course.trim(),
      if (year.trim().isNotEmpty) _formattedYear(year),
      if (block.trim().isNotEmpty) _formattedBlock(block),
    ].join(' • ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_navy, _blue]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .14),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _yellow,
                  size: 42,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STUDENT PROFILE',
                      style: TextStyle(
                        color: _yellow,
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _display(name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                    ),
                    if (studentId.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ID ${studentId.trim()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 17),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: onEdit,
              style: FilledButton.styleFrom(
                backgroundColor: _yellow,
                foregroundColor: _navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(
                'Edit Profile',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingReminder(BuildContext context) {
    final missing = _missingFields;
    if (missing.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your student information',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Missing: ${missing.join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onEdit,
                    child: const Text('Update profile'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      children: [
        Icon(icon, size: 19, color: _dark(context) ? _yellow : _blue),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: _text(context),
          ),
        ),
      ],
    ),
  );

  Widget _group(BuildContext context, List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: _surface(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line(context)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i != 0) Divider(height: 1, color: _line(context)),
            rows[i],
          ],
        ],
      ),
    ),
  );

  Widget _info(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (_dark(context) ? _yellow : _blue).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: _dark(context) ? _yellow : _blue, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11.5, color: _muted(context)),
              ),
              const SizedBox(height: 4),
              Text(
                _display(value),
                style: TextStyle(
                  color: _text(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _settingsRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 23, color: _dark(context) ? _yellow : _blue),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _text(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: _muted(context)),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, color: _muted(context)),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final darkMode = _dark(context);
    return Scaffold(
      backgroundColor: darkMode
          ? const Color(0xFF101B2D)
          : const Color(0xFFF5F8FC),
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 17, 16, 30),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  if (_missingFields.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _missingReminder(context),
                  ],
                  const SizedBox(height: 25),
                  _heading(
                    context,
                    'Personal Information',
                    Icons.badge_outlined,
                  ),
                  _group(context, [
                    _info(
                      context,
                      Icons.person_outline_rounded,
                      'Full Name',
                      name,
                    ),
                    _info(
                      context,
                      Icons.badge_outlined,
                      'School ID',
                      studentId,
                    ),
                    _info(
                      context,
                      Icons.mail_outline_rounded,
                      'Email Address',
                      email,
                    ),
                  ]),
                  const SizedBox(height: 23),
                  _heading(
                    context,
                    'Academic Information',
                    Icons.school_outlined,
                  ),
                  _group(context, [
                    _info(
                      context,
                      Icons.account_balance_outlined,
                      'Department',
                      department,
                    ),
                    _info(
                      context,
                      Icons.school_outlined,
                      'Course / Program',
                      course,
                    ),
                    _info(
                      context,
                      Icons.calendar_month_outlined,
                      'Year Level',
                      _formattedYear(year),
                    ),
                    _info(
                      context,
                      Icons.groups_outlined,
                      'Block',
                      _formattedBlock(block),
                    ),
                  ]),
                  const SizedBox(height: 23),
                  _heading(
                    context,
                    'Account Settings',
                    Icons.settings_outlined,
                  ),
                  _group(context, [
                    _settingsRow(
                      context,
                      icon: darkMode
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      title: 'Dark Mode',
                      subtitle: darkMode
                          ? 'Dark appearance enabled'
                          : 'Light appearance enabled',
                      trailing: Switch.adaptive(
                        value: darkMode,
                        onChanged: (enabled) =>
                            appThemeController.setDarkMode(enabled),
                      ),
                    ),
                    _settingsRow(
                      context,
                      icon: Icons.lock_reset_rounded,
                      title: 'Reset Password',
                      subtitle: 'Recover your password using email',
                      onTap: onResetPassword,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: onLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkMode
                          ? const Color(0xFFFFA7A7)
                          : const Color(0xFFB93636),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TMC EventEase • Student Event Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted(context), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
