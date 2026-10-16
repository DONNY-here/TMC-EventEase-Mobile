
import 'package:flutter/material.dart';
import 'app_theme_controller.dart';

// ======================================================
// TMC EVENTEASE - ENHANCED PROFILE UI
// FIXED DARK MODE AND REMOVED EXTRA EDIT BUTTON
// ======================================================

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

  static const Color _navy = Color(0xFF0E3062);
  static const Color _blue = Color(0xFF194E91);
  static const Color _yellow = Color(0xFFFFCA40);
  static const Color _lightBlue = Color(0xFFAED4FF);

  // ====================================================
  // LIGHT AND DARK MODE COLORS
  // ====================================================

  bool _isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color _surface(BuildContext context) {
    return _isDark(context)
        ? const Color(0xFF19283D)
        : Colors.white;
  }

  Color _heading(BuildContext context) {
    return _isDark(context)
        ? const Color(0xFFF0F5FF)
        : const Color(0xFF12233F);
  }

  Color _secondary(BuildContext context) {
    return _isDark(context)
        ? const Color(0xFFACBBD1)
        : const Color(0xFF73829A);
  }

  Color _border(BuildContext context) {
    return _isDark(context)
        ? const Color(0xFF30445F)
        : const Color(0xFFE1E8F2);
  }

  Color _iconColor(
      BuildContext context, {
        required bool yellowIcon,
      }) {
    if (_isDark(context)) {
      return yellowIcon ? _yellow : _lightBlue;
    }

    return yellowIcon ? _navy : _blue;
  }

  // ====================================================
  // PROFILE HEADER
  // ====================================================

  Widget _profileBanner(BuildContext context) {
    final displayName =
    name.trim().isEmpty ? 'TMC Student' : name.trim();

    final studentCourse =
    course.trim().isEmpty ? 'TMC Student' : course.trim();

    final studentYear = year.trim();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _navy,
            _blue,
            Color(0xFF10376E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.11),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -55,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.055),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            right: -70,
            bottom: -90,
            child: Container(
              width: 165,
              height: 165,
              decoration: const BoxDecoration(
                color: _yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(21),
            child: Row(
              children: [
                // ====================================
                // PROFILE AVATAR
                // EXTRA EDIT BUTTON REMOVED
                // ====================================

                Container(
                  width: 91,
                  height: 91,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: 0.13,
                    ),
                    border: Border.all(
                      color: Colors.white38,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: _yellow,
                    size: 60,
                  ),
                ),

                const SizedBox(width: 18),

                // ====================================
                // STUDENT NAME AND PROGRAM
                // ====================================

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TMC EVENTEASE',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 23,
                          height: 1.13,
                        ),
                      ),

                      const SizedBox(height: 9),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: Text(
                          studentYear.isEmpty
                              ? studentCourse
                              : '$studentCourse • $studentYear',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Explore. Participate. Grow.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // SECTION HEADING
  // ====================================================

  Widget _sectionTitle(
      BuildContext context,
      String title, {
        bool showEdit = false,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _heading(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        // Only Edit Profile button to keep.
        if (showEdit)
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              size: 17,
            ),
            label: const Text('Edit Profile'),
            style: TextButton.styleFrom(
              foregroundColor:
              _isDark(context) ? _yellow : _navy,
              backgroundColor: _isDark(context)
                  ? const Color(0xFF243B5C)
                  : const Color(0xFFE7F0FF),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
      ],
    );
  }

  // ====================================================
  // ACCOUNT INFORMATION TILE
  // DARK ICON COLORS FIXED
  // ====================================================

  Widget _infoTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        required bool yellowIcon,
      }) {
    final dark = _isDark(context);

    final iconBackground = dark
        ? (yellowIcon
        ? const Color(0xFF423825)
        : const Color(0xFF233F65))
        : (yellowIcon
        ? const Color(0xFFFFF2D0)
        : const Color(0xFFE6F0FF));

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: dark ? 0.07 : 0.035,
            ),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ICON
          Container(
            width: 53,
            height: 53,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: _iconColor(
                context,
                yellowIcon: yellowIcon,
              ),
              size: 26,
            ),
          ),

          const SizedBox(width: 15),

          // INFORMATION
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _secondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  value.trim().isEmpty
                      ? 'Not provided'
                      : value,
                  style: TextStyle(
                    color: _heading(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // LIGHT AND DARK MODE SETTING
  // ====================================================

  Widget _appearanceSetting(BuildContext context) {
    final darkMode = _isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 51,
            height: 51,
            decoration: BoxDecoration(
              color: darkMode
                  ? const Color(0xFF293F62)
                  : const Color(0xFFFFF2D0),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              darkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: darkMode ? _yellow : _navy,
              size: 26,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dark Mode',
                  style: TextStyle(
                    color: _heading(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  darkMode
                      ? 'Dark appearance enabled'
                      : 'Light appearance enabled',
                  style: TextStyle(
                    color: _secondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Switch.adaptive(
            value: darkMode,
            activeTrackColor: _yellow,
            activeThumbColor: _navy,
            onChanged: (enabled) {
              appThemeController.setDarkMode(enabled);
            },
          ),
        ],
      ),
    );
  }

  // ====================================================
  // RESET PASSWORD SETTING
  // DARK MODE ICON FIXED
  // ====================================================

  Widget _passwordSetting(BuildContext context) {
    final dark = _isDark(context);

    return Material(
      color: _surface(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onResetPassword,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF253E60)
                      : const Color(0xFFE6F0FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: dark ? _lightBlue : _blue,
                  size: 26,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reset Password',
                      style: TextStyle(
                        color: _heading(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Recover your password using email.',
                      style: TextStyle(
                        color: _secondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: _secondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================
  // MAIN PROFILE SCREEN
  // ====================================================

  @override
  Widget build(BuildContext context) {
    final darkMode = _isDark(context);

    return Scaffold(
      backgroundColor: darkMode
          ? const Color(0xFF101B2D)
          : const Color(0xFFF5F8FC),

      appBar: AppBar(
        title: const Text('Profile'),
        // No extra pencil icon in the AppBar.
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          17, 20, 17, 28,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 650,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // ==================================
                  // PROFILE BANNER
                  // ==================================

                  _profileBanner(context),

                  const SizedBox(height: 29),

                  // ==================================
                  // ACCOUNT INFORMATION
                  // ==================================

                  _sectionTitle(
                    context,
                    'Account Information',
                    showEdit: true,
                  ),

                  const SizedBox(height: 13),

                  _infoTile(
                    context,
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: email,
                    yellowIcon: false,
                  ),

                  _infoTile(
                    context,
                    icon: Icons.badge_outlined,
                    title: 'Student ID',
                    value: studentId,
                    yellowIcon: true,
                  ),

                  _infoTile(
                    context,
                    icon: Icons.account_balance_outlined,
                    title: 'Department',
                    value: department,
                    yellowIcon: false,
                  ),

                  _infoTile(
                    context,
                    icon: Icons.school_outlined,
                    title: 'Course / Program',
                    value: course,
                    yellowIcon: true,
                  ),

                  _infoTile(
                    context,
                    icon: Icons.groups_rounded,
                    title: 'Year Level',
                    value: year,
                    yellowIcon: false,
                  ),

                  _infoTile(
                    context,
                    icon: Icons.grid_view_rounded,
                    title: 'Block',
                    value: block,
                    yellowIcon: true,
                  ),

                  const SizedBox(height: 18),

                  // ==================================
                  // APPEARANCE SETTINGS
                  // ==================================

                  _sectionTitle(
                    context,
                    'Appearance',
                  ),

                  const SizedBox(height: 13),

                  _appearanceSetting(context),

                  const SizedBox(height: 26),

                  // ==================================
                  // ACCOUNT SETTINGS
                  // ==================================

                  _sectionTitle(
                    context,
                    'Account Settings',
                  ),

                  const SizedBox(height: 13),

                  _passwordSetting(context),

                  const SizedBox(height: 16),

                  // ==================================
                  // LOGOUT
                  // ==================================

                  SizedBox(
                    width: double.infinity,
                    height: 53,
                    child: OutlinedButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(
                        Icons.logout_rounded,
                      ),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: darkMode
                            ? const Color(0xFFFF9292)
                            : const Color(0xFFC63636),
                        side: BorderSide(
                          color: darkMode
                              ? const Color(0xFF75434B)
                              : const Color(0xFFF0CECE),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      'TMC EventEase • Student Event Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _secondary(context),
                        fontSize: 11,
                      ),
                    ),
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
