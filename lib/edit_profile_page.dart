part of 'main.dart';

// ======================================================
// TMC EVENTEASE - EDIT PROFILE PAGE
// FIXED SPACING AND LIGHT / DARK MODE
// ======================================================

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController nameController;
  late TextEditingController emailController;

  String selectedDepartment = 'College of Computer Studies';
  String selectedCourse = 'BSIT';
  String selectedYear = '1st Year';
  String selectedBlock = '';

  final Map<String, List<String>> departmentCourses = {
    'College of Computer Studies': ['BSIT'],
    'College of Education': ['BEED', 'BSED'],
    'College of Criminal Justice Education': ['BSCRIM'],
    'College of Office Administration': ['BSOA'],
    'College of Arts and Sciences': [
      'AB Political Science',
      'AB Communication',
    ],
  };

  // ====================================================
  // LIGHT AND DARK MODE COLORS
  // ====================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageBackground => Theme.of(context).scaffoldBackgroundColor;

  Color get _cardBackground => _isDark ? const Color(0xFF19283D) : Colors.white;

  Color get _inputBackground =>
      _isDark ? const Color(0xFF25364D) : const Color(0xFFF6F8FC);

  Color get _primaryText => Theme.of(context).colorScheme.onSurface;

  Color get _secondaryText => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _borderColor =>
      _isDark ? const Color(0xFF40546D) : const Color(0xFFDDE5F0);

  Color get _iconColor => _isDark ? const Color(0xFFAED4FF) : navy;

  Color get _focusColor => _isDark ? yellow : navy;

  // ====================================================
  // INITIALIZE PROFILE INFORMATION
  // ====================================================

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: savedName);

    emailController = TextEditingController(text: savedEmail);

    if (departmentCourses.containsKey(savedDepartment)) {
      selectedDepartment = savedDepartment;
    }

    final availableCourses = departmentCourses[selectedDepartment]!;

    selectedCourse = availableCourses.contains(savedCourse)
        ? savedCourse
        : availableCourses.first;

    const allowedYears = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

    if (allowedYears.contains(savedYear)) {
      selectedYear = savedYear;
    }

    selectedBlock = blockOptions.contains(savedBlock) ? savedBlock : '';
  }

  // ====================================================
  // SAVE PROFILE CHANGES
  // EXISTING VALIDATION AND SAVE LOGIC PRESERVED
  // ====================================================

  void saveChanges() {
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      showMessage(context, 'Please complete all fields.');
      return;
    }

    if (!isValidEmail(email)) {
      showMessage(context, 'Please enter a valid email address.');
      return;
    }

    if (selectedBlock.isEmpty) {
      showMessage(context, 'Please select your block.');
      return;
    }

    if (!(departmentCourses[selectedDepartment]?.contains(selectedCourse) ??
        false)) {
      showMessage(context, 'Please select a valid course.');
      return;
    }

    savedName = name;
    savedEmail = email;
    savedDepartment = selectedDepartment;
    savedCourse = selectedCourse;
    savedYear = selectedYear;
    savedBlock = selectedBlock;

    showMessage(context, 'Profile updated successfully!');

    Navigator.pop(context);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  // ====================================================
  // REUSABLE FIELD LABEL
  // LABELS ARE PLACED ABOVE INPUTS
  // ====================================================

  Widget _fieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(
          label,
          style: TextStyle(
            color: _primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ====================================================
  // REUSABLE INPUT DECORATION
  // ====================================================

  InputDecoration _inputDecoration({
    required IconData icon,
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _secondaryText, fontSize: 14),

      prefixIcon: Icon(icon, color: _iconColor, size: 23),

      filled: true,
      fillColor: _inputBackground,

      isDense: true,

      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _borderColor, width: 1),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _focusColor, width: 1.6),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.6),
      ),
    );
  }

  // ====================================================
  // MAIN PAGE
  // ====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,

      appBar: AppBar(title: const Text('Edit Profile')),

      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

          padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),

              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _isDark ? 0.14 : 0.04,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [
                    // ==================================
                    // HEADER
                    // ==================================
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),

                      decoration: const BoxDecoration(gradient: appGradient),

                      child: const Row(
                        children: [
                          Icon(
                            Icons.manage_accounts_rounded,
                            color: yellow,
                            size: 32,
                          ),

                          SizedBox(width: 13),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  'Update Profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),

                                SizedBox(height: 5),

                                Text(
                                  'Keep your student information '
                                  'up to date.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==================================
                    // PROFILE FORM
                    // ==================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,

                        children: [
                          // ============================
                          // FULL NAME
                          // ============================
                          _fieldLabel('Full Name'),

                          TextField(
                            controller: nameController,

                            textCapitalization: TextCapitalization.words,

                            style: TextStyle(color: _primaryText, fontSize: 14),

                            decoration: _inputDecoration(
                              icon: Icons.person_outline,
                              hint: 'Enter your full name',
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ============================
                          // EMAIL
                          // ============================
                          _fieldLabel('Email Address'),

                          TextField(
                            controller: emailController,

                            keyboardType: TextInputType.emailAddress,

                            autocorrect: false,

                            style: TextStyle(color: _primaryText, fontSize: 14),

                            decoration: _inputDecoration(
                              icon: Icons.email_outlined,
                              hint: 'Enter your email address',
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ============================
                          // DEPARTMENT
                          // ============================
                          _fieldLabel('Department'),

                          DropdownButtonFormField<String>(
                            initialValue: selectedDepartment,
                            isExpanded: true,

                            dropdownColor: _cardBackground,

                            style: TextStyle(
                              color: _primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),

                            iconEnabledColor: _iconColor,

                            decoration: _inputDecoration(
                              icon: Icons.account_balance_outlined,
                              hint: 'Select department',
                            ),

                            items: departmentCourses.keys.map((department) {
                              return DropdownMenuItem<String>(
                                value: department,
                                child: Text(
                                  department,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),

                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedDepartment = value;

                                selectedCourse =
                                    departmentCourses[value]!.first;
                              });
                            },
                          ),

                          const SizedBox(height: 20),

                          // ============================
                          // COURSE / PROGRAM
                          // ============================
                          _fieldLabel('Course / Program'),

                          DropdownButtonFormField<String>(
                            key: ValueKey('course-$selectedDepartment'),

                            initialValue: selectedCourse,
                            isExpanded: true,

                            dropdownColor: _cardBackground,

                            style: TextStyle(
                              color: _primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),

                            iconEnabledColor: _iconColor,

                            decoration: _inputDecoration(
                              icon: Icons.school_outlined,
                              hint: 'Select course / program',
                            ),

                            items: departmentCourses[selectedDepartment]!.map((
                              course,
                            ) {
                              return DropdownMenuItem<String>(
                                value: course,
                                child: Text(
                                  course,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),

                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedCourse = value;
                              });
                            },
                          ),

                          const SizedBox(height: 20),

                          // ============================
                          // YEAR LEVEL
                          // ============================
                          _fieldLabel('Year Level'),

                          DropdownButtonFormField<String>(
                            initialValue: selectedYear,
                            isExpanded: true,

                            dropdownColor: _cardBackground,

                            style: TextStyle(
                              color: _primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),

                            iconEnabledColor: _iconColor,

                            decoration: _inputDecoration(
                              icon: Icons.calendar_month_outlined,
                              hint: 'Select year level',
                            ),

                            items: const [
                              DropdownMenuItem(
                                value: '1st Year',
                                child: Text('1st Year'),
                              ),
                              DropdownMenuItem(
                                value: '2nd Year',
                                child: Text('2nd Year'),
                              ),
                              DropdownMenuItem(
                                value: '3rd Year',
                                child: Text('3rd Year'),
                              ),
                              DropdownMenuItem(
                                value: '4th Year',
                                child: Text('4th Year'),
                              ),
                            ],

                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedYear = value;
                              });
                            },
                          ),

                          const SizedBox(height: 20),

                          // ============================
                          // BLOCK
                          // ============================
                          _fieldLabel('Block'),

                          DropdownButtonFormField<String>(
                            initialValue: selectedBlock.isEmpty
                                ? null
                                : selectedBlock,

                            isExpanded: true,

                            dropdownColor: _cardBackground,

                            style: TextStyle(
                              color: _primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),

                            iconEnabledColor: _iconColor,

                            decoration: _inputDecoration(
                              icon: Icons.groups_rounded,
                              hint: 'Select block',
                            ),

                            items: blockOptions.map((block) {
                              return DropdownMenuItem<String>(
                                value: block,
                                child: Text(
                                  block,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),

                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedBlock = value;
                              });
                            },
                          ),

                          const SizedBox(height: 30),

                          // ============================
                          // SAVE CHANGES
                          // ============================
                          SizedBox(
                            width: double.infinity,
                            height: 56,

                            child: FilledButton.icon(
                              onPressed: saveChanges,

                              icon: const Icon(Icons.save_rounded, size: 21),

                              label: const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              style: FilledButton.styleFrom(
                                backgroundColor: yellow,
                                foregroundColor: navy,

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// PROFILE INFORMATION COMPONENT
// PRESERVED FOR EXISTING PROJECT REFERENCES
// ======================================================

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
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),

      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,

            decoration: BoxDecoration(
              color: dark ? const Color(0xFF253F60) : lightNavy,

              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(
              icon,
              color: dark ? const Color(0xFFAED4FF) : navy,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value.isEmpty ? 'Not provided' : value,

                  style: TextStyle(
                    color: colors.onSurface,
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
