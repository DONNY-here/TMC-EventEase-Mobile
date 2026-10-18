part of 'main.dart';

// ======================================================
// TMC EVENTEASE - EVENT DETAILS
// COMPLETE LIGHT AND DARK MODE SUPPORT
// ======================================================

class EventDetailsPage extends StatefulWidget {
  final Event event;

  const EventDetailsPage({super.key, required this.event});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  bool _showRequirements = false;

  // Shown only for 5 seconds after a successful demo registration.
  // Registration itself stays in registeredEvents.
  bool _showRegistrationConfirmation = false;

  bool get _isRegistered => registeredEvents.any(
        (event) => eventKey(event) == eventKey(widget.event),
  );

  int get _passedRequirementCount => [
    _profileComplete,
    _departmentEligible,
    _courseEligible,
    _yearEligible,
    _hasAvailableSlot,
    _isRegistered || widget.event.registrationOpen,
    !_deadlinePassed,
    _blockEligible,
  ].where((passed) => passed).length;

  // ====================================================
  // THEME COLORS
  // ====================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageBackground =>
      _isDark ? const Color(0xFF101B2D) : const Color(0xFFF5F8FC);

  Color get _cardBackground => _isDark ? const Color(0xFF19283D) : Colors.white;

  Color get _primaryText =>
      _isDark ? const Color(0xFFF0F5FF) : const Color(0xFF17283E);

  Color get _secondaryText =>
      _isDark ? const Color(0xFFB7C5D8) : const Color(0xFF69798C);

  Color get _cardBorder =>
      _isDark ? const Color(0xFF30445F) : const Color(0xFFE1E8F2);

  Color get _iconBackground =>
      _isDark ? const Color(0xFF273F60) : const Color(0xFFEAF2FB);

  Color get _iconColor => _isDark ? const Color(0xFFAED4FF) : navy;

  Color get _accentColor => _isDark ? yellow : navy;

  // ====================================================
  // PROFILE AND REGISTRATION REQUIREMENTS
  // ====================================================

  bool get _profileComplete =>
      savedName.trim().isNotEmpty &&
          savedDepartment.trim().isNotEmpty &&
          savedCourse.trim().isNotEmpty &&
          savedYear.trim().isNotEmpty &&
          savedBlock.trim().isNotEmpty;

  bool get _courseEligible => widget.event.allowedCourses.contains(savedCourse);

  bool get _departmentCourseValid {
    final programs = TmcDepartments.programs[savedDepartment];

    if (programs == null) return false;

    return programs.contains(savedCourse);
  }

  bool get _departmentEligible {
    if (!_departmentCourseValid) {
      return false;
    }

    if (widget.event.scope == 'School-Wide') {
      return true;
    }

    if (widget.event.scope == 'Department-Specific') {
      return widget.event.department == savedDepartment;
    }

    return false;
  }

  bool get _yearEligible => widget.event.allowedYears.contains(savedYear);

  bool get _blockEligible {
    final block = normalizeTmcBlock(savedBlock);
    return block != null && widget.event.allowedBlocks.contains(block);
  }

  bool get _hasAvailableSlot {
    final registered = _isRegistered;

    final total = widget.event.currentParticipants + (registered ? 1 : 0);

    return total < widget.event.capacity || registered;
  }

  bool get _eligibleToRegister =>
      _profileComplete &&
          _departmentEligible &&
          _courseEligible &&
          _yearEligible &&
          _blockEligible &&
          _hasAvailableSlot &&
          !_deadlinePassed &&
          widget.event.registrationOpen;

  int get _displayParticipantCount {
    final registered = _isRegistered;

    return widget.event.currentParticipants + (registered ? 1 : 0);
  }

  int get _availableSlots =>
      max(0, widget.event.capacity - _displayParticipantCount);

  // ====================================================
  // E-CERTIFICATE ELIGIBILITY
  // ====================================================

  bool get _certificateEligible {
    final key = eventKey(widget.event);

    final rating = eventRatings[key] ?? 0;

    // Certificates here are local previews, not backend-issued records.
    return !ApiConfig.useRealApi &&
        _isRegistered &&
        attendanceStatus[key] == 'Present' &&
        rating >= 1 &&
        rating <= 5;
  }

  // ====================================================
  // REGISTRATION DEADLINE
  // ====================================================

  bool get _deadlinePassed {
    final dateText = widget.event.registrationDeadline
        .replaceAll(',', '')
        .trim();

    final parts = dateText.split(RegExp(r'\s+'));

    const months = {
      'January': 1,
      'February': 2,
      'March': 3,
      'April': 4,
      'May': 5,
      'June': 6,
      'July': 7,
      'August': 8,
      'September': 9,
      'October': 10,
      'November': 11,
      'December': 12,
    };

    if (parts.length != 3) return true;

    final month = months[parts[0]];
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (month == null || day == null || year == null) {
      return true;
    }

    final deadline = DateTime(year, month, day);

    if (deadline.year != year ||
        deadline.month != month ||
        deadline.day != day) {
      return true;
    }

    final closingTime = DateTime(year, month, day + 1);

    return !DateTime.now().isBefore(closingTime);
  }

  // ====================================================
  // OPEN EVALUATION
  // ====================================================

  Future<void> _openEvaluation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EvaluationPage(event: widget.event)),
    );

    if (!mounted) return;

    setState(() {});
  }

  // ====================================================
  // OPEN E-CERTIFICATE
  // ====================================================

  void _openCertificate() {
    // Recheck requirements even if called outside the visible button.
    if (!_certificateEligible) {
      showMessage(
        context,
        'Complete demo attendance and event evaluation first.',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ECertificatePage(
          event: widget.event,
          studentName: savedName,
          course: savedCourse,
          yearLevel: savedYear,
          eventTitle: widget.event.title,
          eventDate: widget.event.date,
        ),
      ),
    );
  }

  // ====================================================
  // CONFIRMATION INFORMATION ROW
  // ====================================================

  Widget _confirmationLine(
      BuildContext dialogContext,
      String label,
      String value,
      ) {
    final dark = Theme.of(dialogContext).brightness == Brightness.dark;

    final labelColor = dark ? const Color(0xFFB9C8DA) : const Color(0xFF68778B);

    final valueColor = dark ? Colors.white : const Color(0xFF17283E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Not provided' : value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // REGISTRATION CONFIRMATION DIALOG
  // ====================================================

  Future<bool> _showRegistrationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dark = Theme.of(dialogContext).brightness == Brightness.dark;

        final background = dark ? const Color(0xFF1B2D44) : Colors.white;

        final primary = dark ? Colors.white : const Color(0xFF17283E);

        final secondary = dark
            ? const Color(0xFFBCCBDD)
            : const Color(0xFF66758A);

        final border = dark ? const Color(0xFF405570) : const Color(0xFFE0E6EE);

        return AlertDialog(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          scrollable: true,

          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: border),
          ),

          icon: Icon(
            Icons.verified_user_rounded,
            color: dark ? yellow : navy,
            size: 42,
          ),

          iconPadding: const EdgeInsets.only(top: 22, bottom: 12),

          title: Text(
            'Confirm Event Registration',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),

          titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 19),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 4,
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmationLine(dialogContext, 'Event', widget.event.title),

              _confirmationLine(dialogContext, 'Student', savedName),

              _confirmationLine(dialogContext, 'Department', savedDepartment),

              _confirmationLine(dialogContext, 'Course', savedCourse),

              _confirmationLine(dialogContext, 'Year Level', savedYear),

              _confirmationLine(dialogContext, 'Block', savedBlock),

              const SizedBox(height: 8),

              Divider(color: border),

              const SizedBox(height: 10),

              Text(
                'By continuing, you confirm that you '
                    'want to participate in this event.',
                style: TextStyle(color: secondary, fontSize: 13, height: 1.5),
              ),
            ],
          ),

          actionsPadding: const EdgeInsets.fromLTRB(14, 12, 14, 18),

          actionsAlignment: MainAxisAlignment.center,

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              style: TextButton.styleFrom(
                foregroundColor: dark ? yellow : navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),

            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: dark ? yellow : navy,
                foregroundColor: dark ? navy : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
              label: const Text(
                'Confirm Registration',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // ====================================================
  // REGISTER EVENT
  // ORIGINAL VALIDATION AND REGISTRATION PRESERVED
  // ====================================================

  Future<void> registerEvent() async {
    if (_isRegistered) {
      showMessage(context, 'You are already registered for this event.');
      return;
    }

    if (!_profileComplete) {
      showMessage(
        context,
        'Please complete your profile before registering '
            'for an event.',
      );
      return;
    }

    if (!_departmentEligible) {
      showMessage(
        context,
        'Your department or course does not meet '
            'the requirements for this event.',
      );
      return;
    }

    if (!_courseEligible || !_yearEligible || !_blockEligible) {
      showMessage(
        context,
        'Your course, year level, or block is not '
            'eligible for this event.',
      );
      return;
    }

    if (!_hasAvailableSlot) {
      showMessage(context, 'Registration is full for this event.');
      return;
    }

    if (!widget.event.registrationOpen) {
      showMessage(context, 'Registration for this event is closed.');
      return;
    }

    if (_deadlinePassed) {
      showMessage(
        context,
        'The registration deadline for this event '
            'has passed.',
      );
      return;
    }

    // Show the updated confirmation dialog.
    final confirm = await _showRegistrationDialog();

    if (!confirm || !mounted) return;

    // Recheck requirements after confirmation.
    if (_isRegistered) {
      showMessage(context, 'You are already registered for this event.');
      return;
    }

    if (!_eligibleToRegister) {
      showMessage(
        context,
        'Registration requirements are no longer '
            'satisfied.',
      );
      return;
    }

    final key = eventKey(widget.event);

    setState(() {
      registeredEvents.add(widget.event);
      attendanceStatus[key] = 'Not Recorded';
      attendanceCheckInTime.remove(key);

      // Preserve QR-token creation.
      qrTokens[key] = createLocalQrToken();
      _showRegistrationConfirmation = true;
    });

    // Only hide the confirmation UI, never the actual registration.
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _showRegistrationConfirmation = false;
      });
    });

    showMessage(context, 'Registration confirmed successfully!');
  }

  // ====================================================
  // REUSABLE SECTION HEADING
  // ====================================================

  Widget _sectionHeading(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _primaryText,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ====================================================
  // REUSABLE CARD
  // ====================================================

  Widget _card({
    required Widget child,
    double radius = 20,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _cardBorder),
      ),
      child: child,
    );
  }

  // ====================================================
  // THEME-AWARE DIVIDER
  // ====================================================

  Widget _divider({double height = 20}) {
    return Divider(height: height, color: _cardBorder);
  }

  // ====================================================
  // EVENT INFORMATION ROW
  // ====================================================

  Widget _eventInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _iconBackground,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _iconColor, size: 23),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                value.trim().isEmpty ? 'Not provided' : value,
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ====================================================
  // PARTICIPANT INFORMATION ROW
  // ====================================================

  Widget _participantInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _iconColor, size: 20),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    fontSize: 13,
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
  // VERIFICATION ROW
  // ====================================================

  Widget _verificationRow({
    required String label,
    required String value,
    required bool passed,
  }) {
    final statusColor = passed
        ? (_isDark ? const Color(0xFF85E4AB) : const Color(0xFF27834A))
        : (_isDark ? const Color(0xFFFF9696) : const Color(0xFFC94747));

    final background = passed
        ? (_isDark ? const Color(0xFF203E30) : const Color(0xFFE7F6EC))
        : (_isDark ? const Color(0xFF45282C) : const Color(0xFFFCE8E8));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: statusColor,
            size: 21,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.35,
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
  // VERIFICATION RESULT BANNER
  // ====================================================

  Widget _verificationResult({
    required bool registered,
    required bool verified,
  }) {
    final statusColor = verified
        ? (_isDark ? const Color(0xFF85E4AB) : const Color(0xFF27834A))
        : (_isDark ? const Color(0xFFFF9696) : const Color(0xFFC94747));

    final background = verified
        ? (_isDark ? const Color(0xFF203E30) : const Color(0xFFE7F6EC))
        : (_isDark ? const Color(0xFF45282C) : const Color(0xFFFCE8E8));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.gpp_bad_rounded,
            color: statusColor,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              registered
                  ? 'REGISTRATION CONFIRMED'
                  : verified
                  ? 'ELIGIBLE TO JOIN'
                  : 'NOT ELIGIBLE TO JOIN',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // REGISTRATION CONFIRMED BANNER
  // ====================================================

  Widget _registeredBanner() {
    final background = _isDark
        ? const Color(0xFF203E30)
        : const Color(0xFFE7F6EC);

    final successColor = _isDark
        ? const Color(0xFF85E4AB)
        : const Color(0xFF27834A);

    return Container(
      key: const ValueKey('registered'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: successColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: successColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: successColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration Confirmed',
                  style: TextStyle(
                    color: successColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$savedName • $savedCourse • $savedYear',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 11.5,
                    height: 1.35,
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
  // E-CERTIFICATE SECTION
  // ====================================================

  Widget _certificateSection() {
    final attended = attendanceStatus[eventKey(widget.event)] == 'Present';

    final evaluated = (eventRatings[eventKey(widget.event)] ?? 0) >= 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('E-Certificate'),

        const SizedBox(height: 10),

        _card(
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _certificateEligible
                    ? 'Your demo certificate preview is ready to view.'
                    : 'Your certificate will unlock when '
                    'your attendance is marked Present '
                    'and your event evaluation is completed.',
                style: TextStyle(
                  color: _secondaryText,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),

              if (attended) ...[
                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _openEvaluation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentColor,
                    side: BorderSide(color: _cardBorder),
                  ),
                  icon: Icon(
                    evaluated
                        ? Icons.edit_note_rounded
                        : Icons.rate_review_outlined,
                  ),
                  label: Text(
                    evaluated
                        ? 'Edit Event Evaluation'
                        : 'Complete Event Evaluation',
                  ),
                ),
              ],

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: _certificateEligible ? _openCertificate : null,
                icon: Icon(
                  _certificateEligible
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_outline_rounded,
                ),
                label: Text(
                  _certificateEligible
                      ? 'View E-Certificate'
                      : 'E-Certificate Locked',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ====================================================
  // MAIN EVENT DETAILS UI
  // ====================================================

  @override
  Widget build(BuildContext context) {
    final registered = _isRegistered;

    final verified = registered || _eligibleToRegister;

    final courseText =
    widget.event.allowedCourses.length == courseOptions.length
        ? 'All Courses'
        : widget.event.allowedCourses.join(', ');

    final yearText = widget.event.allowedYears.length == allYearLevels.length
        ? '1st Year - 4th Year'
        : widget.event.allowedYears.join(', ');

    return Scaffold(
      backgroundColor: _pageBackground,

      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Event Details',
          style: TextStyle(color: Colors.white),
        ),
      ),

      // Remove the entire bottom bar after the 5-second confirmation.
      // Existing registrations still show in the event details status.
      bottomNavigationBar: (!_isRegistered || _showRegistrationConfirmation)
          ? SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          decoration: BoxDecoration(
            color: _cardBackground,
            border: Border(top: BorderSide(color: _cardBorder)),
          ),
          child: _isRegistered
              ? _registeredBanner()
              : SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _eligibleToRegister ? registerEvent : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: yellow,
                foregroundColor: navy,
                disabledBackgroundColor: _cardBorder,
                disabledForegroundColor: _secondaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(_eligibleToRegister
                  ? Icons.how_to_reg_rounded
                  : Icons.block_rounded),
              label: Text(_eligibleToRegister
                  ? 'Confirm Registration'
                  : 'Not Eligible to Register'),
            ),
          ),
        ),
      )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // EVENT BANNER
            // ==========================================
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.92, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: appGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.16),
                      blurRadius: 20,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -35,
                      top: -45,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),

                    const Center(
                      child: Icon(
                        Icons.event_available_rounded,
                        color: yellow,
                        size: 82,
                      ),
                    ),

                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          'TMC CAMPUS EVENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ==========================================
            // EVENT TITLE
            // ==========================================
            Text(
              widget.event.title,
              style: TextStyle(
                color: _primaryText,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(widget.event.date),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.access_time_rounded, size: 16),
                  label: Text(widget.event.time),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.place_outlined, size: 16),
                  label: Text(widget.event.venue),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: Icon(
                    _isRegistered ? Icons.check_circle_outline : Icons.info_outline,
                    size: 16,
                  ),
                  label: Text(_isRegistered
                      ? 'Registered (Demo)'
                      : _deadlinePassed || !widget.event.registrationOpen
                      ? 'Registration closed'
                      : 'Registration open (Demo)'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ==========================================
            // EVENT INFORMATION
            // ==========================================
            _card(
              child: Column(
                children: [
                  _eventInfoRow(
                    icon: Icons.category_outlined,
                    label: 'Event Type',
                    value: widget.event.scope,
                  ),

                  _divider(height: 24),

                  _eventInfoRow(
                    icon: Icons.account_balance_outlined,
                    label: 'Department',
                    value: widget.event.department,
                  ),

                  _divider(height: 24),

                  _eventInfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: widget.event.date,
                  ),

                  _divider(height: 24),

                  _eventInfoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Time',
                    value: widget.event.time,
                  ),

                  _divider(height: 24),

                  _eventInfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Venue',
                    value: widget.event.venue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // ABOUT THE EVENT
            // ==========================================
            _sectionHeading('About the Event'),

            const SizedBox(height: 10),

            Text(
              widget.event.description,
              style: TextStyle(
                color: _secondaryText,
                fontSize: 14.5,
                height: 1.55,
              ),
            ),

            const SizedBox(height: 28),

            // ==========================================
            // WHO CAN JOIN
            // ==========================================
            _sectionHeading('Who Can Join'),

            const SizedBox(height: 12),

            _card(
              child: Column(
                children: [
                  _participantInfoRow(
                    icon: Icons.groups_2_outlined,
                    label: 'Eligible Participants',
                    value: widget.event.eligibleParticipants,
                  ),

                  _divider(height: 16),

                  _participantInfoRow(
                    icon: Icons.school_outlined,
                    label: 'Allowed Courses',
                    value: courseText,
                  ),

                  _divider(height: 16),

                  _participantInfoRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Year Level',
                    value: yearText,
                  ),

                  _divider(height: 16),

                  _participantInfoRow(
                    icon: Icons.people_alt_outlined,
                    label: 'Available Slots',
                    value:
                    '$_availableSlots available out of '
                        '${widget.event.capacity} slots',
                  ),

                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: widget.event.capacity <= 0
                        ? 0
                        : (_displayParticipantCount / widget.event.capacity)
                        .clamp(0.0, 1.0),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                    backgroundColor: _cardBorder,
                    color: _accentColor,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Demo estimate · not live server availability',
                    style: TextStyle(color: _secondaryText, fontSize: 11),
                  ),
                  _divider(height: 16),

                  _participantInfoRow(
                    icon: Icons.event_busy_outlined,
                    label: 'Registration Deadline',
                    value: widget.event.registrationDeadline,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ==========================================
            // REGISTRATION VERIFICATION - COMPACT SUMMARY
            // ==========================================
            _sectionHeading('Registration Verification'),
            const SizedBox(height: 12),
            _card(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _showRequirements = !_showRequirements),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(
                            _isRegistered || _eligibleToRegister
                                ? Icons.verified_rounded
                                : Icons.fact_check_outlined,
                            color: _isRegistered || _eligibleToRegister
                                ? Colors.green
                                : _accentColor,
                            size: 27,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isRegistered
                                      ? 'Registration confirmed'
                                      : _eligibleToRegister
                                      ? 'Eligible to join'
                                      : 'Requirements need attention',
                                  style: TextStyle(
                                    color: _primaryText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_passedRequirementCount of 8 checks passed · View requirements',
                                  style: TextStyle(
                                    color: _secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _showRequirements
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: _secondaryText,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showRequirements) ...[
                    const SizedBox(height: 10),
                    ...[
                      _verificationRow(
                        label: 'Profile Information',
                        value: _profileComplete
                            ? 'Student profile is complete'
                            : 'Complete your profile first',
                        passed: _profileComplete,
                      ),

                      _verificationRow(
                        label: 'Department Eligibility',
                        value: _departmentEligible
                            ? '$savedDepartment is eligible'
                            : 'Your department or program '
                            'is not eligible',
                        passed: _departmentEligible,
                      ),

                      _verificationRow(
                        label: 'Course Eligibility',
                        value: _courseEligible
                            ? '$savedCourse is allowed'
                            : '${savedCourse.isEmpty ? 'No course selected' : savedCourse} '
                            'is not allowed',
                        passed: _courseEligible,
                      ),

                      _verificationRow(
                        label: 'Year Level Eligibility',
                        value: _yearEligible
                            ? '$savedYear is allowed'
                            : '${savedYear.isEmpty ? 'No year level selected' : savedYear} '
                            'is not allowed',
                        passed: _yearEligible,
                      ),

                      _verificationRow(
                        label: 'Registration Availability',
                        value: _hasAvailableSlot
                            ? 'Slots are still available'
                            : 'Registration is already full',
                        passed: _hasAvailableSlot,
                      ),

                      _verificationRow(
                        label: 'Registration Status',
                        value: registered
                            ? 'Registration confirmed'
                            : widget.event.registrationOpen
                            ? 'Registration is open'
                            : 'Registration is closed',
                        passed: registered || widget.event.registrationOpen,
                      ),

                      _verificationRow(
                        label: 'Registration Deadline',
                        value: _deadlinePassed
                            ? 'Registration deadline '
                            'has passed'
                            : 'Within the registration period',
                        passed: !_deadlinePassed,
                      ),

                      _verificationRow(
                        label: 'Block Eligibility',
                        value: _blockEligible
                            ? '$savedBlock is allowed'
                            : 'Your block is not eligible '
                            'for this event',
                        passed: _blockEligible,
                      ),

                    ],
                    _verificationResult(
                      registered: registered,
                      verified: verified,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            // ==========================================
            // E-CERTIFICATE
            // ==========================================
            if (registered) ...[
              const SizedBox(height: 22),
              _certificateSection(),
            ],

            // ==========================================
            // REGISTRATION REQUIREMENT REMINDER
            // ==========================================
            if (!registered && !_eligibleToRegister) ...[
              const SizedBox(height: 10),
              Text(
                'Your profile must meet the event '
                    'requirements before you can register.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
