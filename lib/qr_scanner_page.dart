part of 'main.dart';

// ======================================================
// TMC EVENTEASE - IMPROVED QR ATTENDANCE SCANNER
// ======================================================

class QRCodePage extends StatefulWidget {
  const QRCodePage({super.key});

  @override
  State<QRCodePage> createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  // ====================================================
  // THEME-AWARE QR SCANNER COLORS
  // ====================================================

  Color get _surfaceColor => Theme.of(context).colorScheme.surface;

  Color get _titleColor => Theme.of(context).colorScheme.onSurface;

  Color get _subtitleColor => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _outlineColor => Theme.of(context).colorScheme.outlineVariant;

  final QrVerificationService qrVerificationService = QrVerificationService();

  Event? selectedEvent;

  bool get canScanAttendance =>
      savedUserRole == 'scanner' || savedUserRole == 'admin';

  final MobileScannerController scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  // SCANNER STATES
  bool processingScan = false;
  bool isVerifyingScan = false;

  String? lastMessage;
  String? lastResultStatus;
  bool lastScanSuccessful = false;

  Event? lastScannedEvent;
  String? lastScannedStudent;
  String? lastCheckInTime;

  String get scannerDisplayName =>
      savedName.trim().isNotEmpty ? savedName : demoScannerName;

  // ====================================================
  // RESULT COLORS AND ICONS
  // ====================================================

  Color get resultColor {
    switch (lastResultStatus) {
      case 'present':
        return const Color(0xFF27834A);

      case 'duplicate':
        return const Color(0xFFAB6900);

      default:
        return const Color(0xFFC94747);
    }
  }

  Color get resultBackground {
    switch (lastResultStatus) {
      case 'present':
        return const Color(0xFFE7F6EC);

      case 'duplicate':
        return const Color(0xFFFFF3D9);

      default:
        return const Color(0xFFFCE8E8);
    }
  }

  IconData get resultIcon {
    switch (lastResultStatus) {
      case 'present':
        return Icons.check_circle_rounded;

      case 'duplicate':
        return Icons.warning_amber_rounded;

      case 'network_error':
        return Icons.wifi_off_rounded;

      default:
        return Icons.error_outline_rounded;
    }
  }

  String get resultTitle {
    switch (lastResultStatus) {
      case 'present':
        return 'Attendance Recorded!';

      case 'duplicate':
        return 'Already Checked In';

      case 'wrong_event':
        return 'Wrong Event QR Code';

      case 'invalid':
        return 'Invalid QR Code';

      case 'network_error':
        return 'Verification Failed';

      default:
        return lastScanSuccessful ? 'QR Verified' : 'Scan Not Accepted';
    }
  }

  // ====================================================
  // EXISTING LOCAL TEST REGISTRATIONS
  // ====================================================

  void loadMockRegistrations() {
    for (final event in registeredEvents) {
      final key = eventKey(event);
      final token = qrTokens[key];

      if (token == null || token.isEmpty) continue;

      qrVerificationService.addTestRegistration(
        token: token,
        eventId: key,
        studentName: savedName,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    loadMockRegistrations();
  }

  // ====================================================
  // DISPLAY SCAN RESULT
  // ====================================================

  void _showScanResult({
    required String status,
    required String message,
    bool success = false,
    Event? event,
    String? studentName,
    String? checkInTime,
  }) {
    if (!mounted) return;

    setState(() {
      isVerifyingScan = false;

      // Keep scanner paused until officer selects
      // Scan Another QR or Try Scanning Again.
      processingScan = true;

      lastResultStatus = status;
      lastScanSuccessful = success;
      lastMessage = message;

      lastScannedEvent = event;
      lastScannedStudent = studentName;
      lastCheckInTime = checkInTime;
    });
  }

  // ====================================================
  // HANDLE QR CODE
  // ====================================================

  Future<void> _handleQrCode(String rawValue) async {
    if (processingScan || !canScanAttendance || selectedEvent == null) {
      return;
    }

    final event = selectedEvent!;
    final key = eventKey(event);

    // Lock scanning immediately to avoid repeated scans.
    setState(() {
      processingScan = true;
      isVerifyingScan = true;

      lastMessage = null;
      lastResultStatus = null;
      lastScannedEvent = null;
      lastScannedStudent = null;
      lastCheckInTime = null;
    });

    try {
      await scannerController.stop();
    } catch (_) {
      // Camera may already be stopped.
    }

    if (!mounted) return;

    try {
      // STEP 1: Decode the QR token.
      final token = decodeStudentEventQr(rawValue);

      if (token == null) {
        _showScanResult(
          status: 'invalid',
          message: 'This is not a valid student event QR pass.',
        );
        return;
      }

      // STEP 2: Use the existing verification service.
      // The current service still uses local test registrations.
      final result = await qrVerificationService.verifyQr(
        token: token,
        eventId: key,
        eventTitle: event.title,
      );

      if (!mounted) return;

      final now = DateTime.now();

      final status = result.status.toString().toLowerCase();

      final accepted = status == 'present';
      final duplicate = status == 'duplicate';
      final scannedTime = result.checkInTime;

      // Preserve existing local attendance updates.
      // Real Laravel synchronization will be added
      // when the backend verification API is available.
      if (accepted &&
          registeredEvents.contains(event) &&
          qrTokens[key] == token) {
        attendanceStatus[key] = 'Present';

        attendanceCheckInTime[key] = scannedTime ?? formatCheckInTime(now);
      }

      // Preserve recent scan history.
      if (accepted || duplicate) {
        scanHistory.insert(
          0,
          ScanHistory(
            eventTitle: result.eventTitle ?? event.title,
            studentName: result.studentName ?? 'Unknown Student',
            scannerName: scannerDisplayName,
            status: accepted ? 'Present' : 'Duplicate',
            scannedAt: now,
          ),
        );
      }

      // STEP 3: Display verification result.
      _showScanResult(
        status: status,
        message: result.message,
        success: result.success,
        event: accepted || duplicate ? event : null,
        studentName: accepted || duplicate ? result.studentName : null,
        checkInTime: accepted
            ? (scannedTime ?? formatCheckInTime(now))
            : duplicate
            ? scannedTime
            : null,
      );

      refreshNotifications();
    } catch (error) {
      debugPrint('QR verification error: $error');

      _showScanResult(
        status: 'network_error',
        message:
            'Unable to verify this QR code. '
            'Check your connection and try again.',
      );
    }
  }

  // ====================================================
  // SCAN ANOTHER QR / RETRY
  // ====================================================

  Future<void> _scanAgain() async {
    if (!mounted || isVerifyingScan) return;

    setState(() {
      processingScan = false;
      isVerifyingScan = false;

      lastMessage = null;
      lastResultStatus = null;
      lastScanSuccessful = false;

      lastScannedEvent = null;
      lastScannedStudent = null;
      lastCheckInTime = null;
    });

    try {
      await scannerController.start();
    } catch (_) {
      // Camera may already be running.
    }
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  // ====================================================
  // MAIN SCANNER PAGE
  // ====================================================

  @override
  Widget build(BuildContext context) {
    if (!canScanAttendance) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Attendance')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Authorized Personnel Only',
              message:
                  'QR attendance scanning is available '
                  'only to authorized event personnel.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Attendance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          // ============================================
          // AUTHORIZED SCANNER CARD
          // ============================================
          Container(
            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _outlineColor),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: navy,
                  size: 30,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Authorized Scanner',
                        style: TextStyle(color: textGrey, fontSize: 12),
                      ),
                      Text(
                        scannerDisplayName,
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF27834A),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ============================================
          // SELECT EVENT
          // ============================================
          DropdownButtonFormField<Event>(
            key: ValueKey(selectedEvent),
            initialValue: selectedEvent,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select Event to Scan',
              prefixIcon: Icon(Icons.event_available_outlined),
            ),
            hint: const Text('Choose an event'),
            items: eventList.map((event) {
              return DropdownMenuItem<Event>(
                value: event,
                child: Text(event.title, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: isVerifyingScan
                ? null
                : (event) {
                    if (event == null) return;

                    setState(() {
                      selectedEvent = event;
                    });

                    _scanAgain();
                  },
          ),

          const SizedBox(height: 18),

          // ============================================
          // SCANNER HEADER
          // ============================================
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: yellow, size: 36),

                SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Student QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      SizedBox(height: 4),

                      Text(
                        'Select an event and scan the QR '
                        'pass presented by a registered student.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ============================================
          // CAMERA SCANNER
          // ============================================
          Container(
            height: 360,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: scannerController,
                  onDetect: (capture) {
                    if (selectedEvent == null || processingScan) {
                      return;
                    }

                    if (capture.barcodes.isEmpty) return;

                    final rawValue = capture.barcodes.first.rawValue;

                    if (rawValue == null || rawValue.isEmpty) {
                      return;
                    }

                    _handleQrCode(rawValue);
                  },
                ),

                // QR SCAN FRAME
                Center(
                  child: Container(
                    width: 235,
                    height: 235,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: yellow, width: 3),
                    ),
                  ),
                ),

                // LOADING OVERLAY
                if (isVerifyingScan)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xC8000000),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: yellow),

                          const SizedBox(height: 18),

                          const Text(
                            'Verifying QR Code...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            'Please wait for the scan result.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  )
                // PAUSED / NO EVENT OVERLAY
                else if (lastMessage != null || selectedEvent == null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xA6000000),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            selectedEvent == null
                                ? 'Choose an event above '
                                      'to start scanning.'
                                : 'Scanner paused. Review '
                                      'the result below.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                // ACTIVE SCANNER INSTRUCTIONS
                else
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Place the QR inside the frame',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ============================================
          // SCAN RESULT CARD
          // ============================================
          if (lastMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: resultBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: resultColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(resultIcon, color: resultColor, size: 30),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resultTitle,
                              style: TextStyle(
                                color: resultColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              lastMessage!,
                              style: TextStyle(
                                color: resultColor,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // EVENT AND STUDENT INFORMATION
                  if (lastScannedEvent != null) ...[
                    const SizedBox(height: 12),

                    Divider(color: resultColor.withValues(alpha: 0.2)),

                    const SizedBox(height: 8),

                    Text(
                      lastScannedEvent!.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    if (lastScannedStudent != null &&
                        lastScannedStudent!.isNotEmpty) ...[
                      const SizedBox(height: 4),

                      Text(
                        'Student: $lastScannedStudent',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: textGrey),
                      ),
                    ],

                    if (lastCheckInTime != null &&
                        lastCheckInTime!.isNotEmpty) ...[
                      const SizedBox(height: 4),

                      Text(
                        'Check-in: $lastCheckInTime',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: textGrey),
                      ),
                    ],
                  ],

                  const SizedBox(height: 14),

                  // SCAN AGAIN BUTTON
                  OutlinedButton.icon(
                    onPressed: _scanAgain,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(
                      lastScanSuccessful || lastResultStatus == 'duplicate'
                          ? 'Scan Another QR'
                          : 'Try Scanning Again',
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // ============================================
          // RECENT SCAN HISTORY
          // ============================================
          sectionTitle('Recent Scan History'),

          const SizedBox(height: 12),

          if (scanHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No attendance scans recorded yet.',
                style: TextStyle(color: textGrey),
              ),
            )
          else
            ...scanHistory.take(10).map((record) {
              final isPresent = record.status == 'Present';

              final time = formatCheckInTime(record.scannedAt);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _outlineColor),
                ),

                child: Row(
                  children: [
                    Icon(
                      isPresent
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: isPresent ? Colors.green : Colors.orange,
                      size: 28,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.studentName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _titleColor,
                            ),
                          ),

                          Text(
                            record.eventTitle,
                            style: TextStyle(
                              color: _subtitleColor,
                              fontSize: 12,
                            ),
                          ),

                          Text(
                            '${record.status} • $time',
                            style: TextStyle(
                              color: isPresent ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 18),

          // CURRENT VERIFICATION MODE
          const Text(
            'Local verification is currently active. '
            'Scans shown here are not automatically '
            'saved to the Laravel database.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textGrey, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}
