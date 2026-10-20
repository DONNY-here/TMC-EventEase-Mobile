part of 'main.dart';

// ======================================================
// TMC EVENTEASE - STUDENT QR PASS
// COMPLETE LIGHT AND DARK MODE SUPPORT
// ======================================================

class StudentQrPassPage extends StatelessWidget {
  final Event event;

  const StudentQrPassPage({super.key, required this.event});

  // ====================================================
  // STUDENT INFORMATION ROW
  // ====================================================

  Widget _info(String label, String value, bool isDark) {
    final labelColor = isDark
        ? const Color(0xFFB7C6D9)
        : const Color(0xFF758194);

    final valueColor = isDark
        ? const Color(0xFFF4F7FD)
        : const Color(0xFF17283E);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

          const SizedBox(width: 8),

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
  // MAIN STUDENT QR PASS
  // ====================================================

  @override
  Widget build(BuildContext context) {
    final key = eventKey(event);

    // Demo credentials are available only for a locally registered event.
    // Never generate or display demo credentials in Real API Mode.
    final registered =
        !ApiConfig.useRealApi &&
        registeredEvents.any((item) => eventKey(item) == key);
    final token = registered ? qrTokens[key] : null;
    final validToken =
        token != null && RegExp(r'^[A-Za-z0-9]{40}$').hasMatch(token);
    final qrData = validToken ? '$studentQrPrefix$token' : '';

    // ==================================================
    // LIGHT AND DARK MODE COLORS
    // ==================================================

    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    final pageBackground = isDark
        ? const Color(0xFF101B2D)
        : const Color(0xFFF5F8FC);

    final cardBackground = isDark ? const Color(0xFF19283D) : Colors.white;

    final cardBorder = isDark
        ? const Color(0xFF344861)
        : const Color(0xFFE1E8F2);

    final primaryText = isDark
        ? const Color(0xFFF4F7FD)
        : const Color(0xFF0E3062);

    final secondaryText = isDark
        ? const Color(0xFFB7C6D9)
        : const Color(0xFF758194);

    final successColor = isDark
        ? const Color(0xFF85E4AB)
        : const Color(0xFF27834A);

    final successBackground = isDark
        ? const Color(0xFF203E30)
        : const Color(0xFFE7F6EC);

    // ==================================================
    // NO ACTIVE QR PASS
    // ==================================================

    // Never create a QR token merely by opening this page.
    if (qrData.isEmpty) {
      return Scaffold(
        backgroundColor: pageBackground,

        appBar: AppBar(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Student QR Pass'),
        ),

        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 35),
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_2_rounded, color: secondaryText, size: 60),

                  const SizedBox(height: 18),

                  Text(
                    'No Active QR Pass',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 9),

                  Text(
                    'No active QR pass is available '
                    'for this event.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Use only the validated scanner-compatible demo QR data.

    // ==================================================
    // ACTIVE STUDENT QR PASS
    // ==================================================

    return Scaffold(
      backgroundColor: pageBackground,

      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Student QR Pass'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),

              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 27, 20, 24),

                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.15 : 0.05,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),

                child: Column(
                  children: [
                    // ==================================
                    // SCHOOL ICON
                    // ==================================
                    Icon(
                      Icons.school_rounded,
                      color: isDark ? yellow : navy,
                      size: 43,
                    ),

                    const SizedBox(height: 12),

                    // ==================================
                    // SYSTEM TITLE
                    // ==================================
                    Text(
                      'TMC EVENTEASE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'STUDENT EVENT PASS',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'DEMO PASS · NOT OFFICIAL ATTENDANCE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================================
                    // SCANNABLE QR CODE
                    // ALWAYS BLACK ON WHITE
                    // ==================================
                    Container(
                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E7EE)),
                      ),

                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final qrSize = (constraints.maxWidth - 16)
                              .clamp(0.0, 230.0)
                              .toDouble();

                          return QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.white,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ==================================
                    // QR CODE INSTRUCTION
                    // ==================================
                    Text(
                      'Present this QR code to '
                      'authorized event personnel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 25),

                    Divider(color: cardBorder, thickness: 1),

                    const SizedBox(height: 9),

                    // ==================================
                    // STUDENT INFORMATION
                    // ==================================
                    _info('Student', savedName, isDark),

                    _info('Department', savedDepartment, isDark),

                    _info('Course', savedCourse, isDark),

                    _info('Year Level', savedYear, isDark),

                    _info('Event', event.title, isDark),

                    _info('Date', event.date, isDark),

                    const SizedBox(height: 19),

                    // ==================================
                    // REGISTRATION STATUS
                    // ==================================
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: successBackground,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: successColor.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: successColor,
                            size: 20,
                          ),

                          const SizedBox(width: 8),

                          Flexible(
                            child: Text(
                              'Registration Confirmed',
                              style: TextStyle(
                                color: successColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
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
