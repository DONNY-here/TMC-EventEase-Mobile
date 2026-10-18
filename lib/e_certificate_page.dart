part of 'main.dart';

// ======================================================
// TMC EVENTEASE - DEMO E-CERTIFICATE PREVIEW
// Step 6.3: eligibility is checked inside this page too.
// No official certificate is issued or downloaded here.
// ======================================================

class ECertificatePage extends StatelessWidget {
  // Existing constructor fields retained for compatibility.
  final String studentName;
  final String course;
  final String yearLevel;
  final String eventTitle;
  final String eventDate;

  // Pass the actual Event so this page can validate local eligibility.
  // Older calls without an Event display a locked screen instead.
  final Event? event;

  const ECertificatePage({
    super.key,
    required this.studentName,
    required this.course,
    required this.yearLevel,
    required this.eventTitle,
    required this.eventDate,
    this.event,
  });

  bool get _isEligible {
    final selectedEvent = event;
    if (ApiConfig.useRealApi || selectedEvent == null) return false;

    final key = eventKey(selectedEvent);
    final hasRegistration = registeredEvents.any(
          (registered) => eventKey(registered) == key,
    );
    final rating = eventRatings[key] ?? 0;

    return savedName.trim().isNotEmpty &&
        hasRegistration &&
        attendanceStatus[key] == 'Present' &&
        rating >= 1 &&
        rating <= 5;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final pageColor = isDark ? const Color(0xFF101B2D) : const Color(0xFFF5F8FC);
    final primaryText = isDark ? const Color(0xFFF2F5FC) : const Color(0xFF152A43);
    final secondaryText = isDark ? const Color(0xFFB7C6DA) : const Color(0xFF65768A);
    const deepBlue = Color(0xFF123867);
    const gold = Color(0xFFD2A744);

    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        title: const Text('E-Certificate'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: !_isEligible
          ? Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 42,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Certificate Locked',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  ApiConfig.useRealApi
                      ? 'Official certificates are not connected to Laravel yet.'
                      : 'Register for this event, complete QR attendance, '
                      'and submit a 1–5 star evaluation to unlock '
                      'your demo certificate preview.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryText, height: 1.5),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Event Details'),
                ),
              ],
            ),
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Certificate of Participation',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF33472B)
                            : const Color(0xFFFFF3D1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'DEMO PREVIEW',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFFFD16E)
                              : const Color(0xFF8A5B00),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Available after demo attendance and evaluation.',
                  style: TextStyle(color: secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: gold,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 30,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: deepBlue, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: gold,
                          size: 62,
                        ),
                        const SizedBox(height: 13),
                        const Text(
                          'TRINIDAD MUNICIPAL COLLEGE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: deepBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'TMC EVENTEASE',
                          style: TextStyle(
                            color: deepBlue,
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'CERTIFICATE OF PARTICIPATION',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: deepBlue,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Text(
                          'This demo certificate preview is presented to',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF58677A)),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          savedName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: deepBlue,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Divider(color: gold, height: 32, thickness: 1.5),
                        Text(
                          '$savedCourse • $savedYear',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF58677A)),
                        ),
                        const SizedBox(height: 23),
                        const Text(
                          'For participating in',
                          style: TextStyle(color: Color(0xFF58677A)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          event!.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: deepBlue,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 11),
                        Text(
                          'Held on ${event!.date}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF58677A)),
                        ),
                        const SizedBox(height: 32),
                        const Divider(color: gold),
                        const Text(
                          'DEMO ONLY • NOT AN OFFICIAL CERTIFICATE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF62738A),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This is an in-app preview. It is not a verifiable '
                      'certificate, and no PDF has been issued.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryText, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
