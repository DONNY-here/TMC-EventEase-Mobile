part of 'main.dart';

// ==============================================================
// TMC EVENTEASE • SCANNER WORKSPACE
// Modern responsive UI, with the existing local QR logic preserved.
// This file remains a part of main.dart (do not import Flutter here).
// ==============================================================

class QRCodePage extends StatefulWidget {
  const QRCodePage({super.key});

  @override
  State<QRCodePage> createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  final QrVerificationService qrVerificationService = QrVerificationService();

  final MobileScannerController scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  Event? selectedEvent;
  bool processingScan = false;
  bool isVerifyingScan = false;
  bool _torchEnabled = false;
  bool _showAllHistory = false;

  String? lastMessage;
  String? lastResultStatus;
  bool lastScanSuccessful = false;
  Event? lastScannedEvent;
  String? lastScannedStudent;
  String? lastCheckInTime;

  bool get canScanAttendance =>
      savedUserRole == 'scanner' || savedUserRole == 'admin';

  String get scannerDisplayName =>
      savedName.trim().isNotEmpty ? savedName : demoScannerName;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _isDark ? const Color(0xFF0B1424) : const Color(0xFFF3F6FB);
  Color get _surface => _isDark ? const Color(0xFF17263C) : Colors.white;
  Color get _border =>
      _isDark ? const Color(0xFF31445C) : const Color(0xFFE1E8F1);
  Color get _ink =>
      _isDark ? const Color(0xFFF1F6FD) : const Color(0xFF15283E);
  Color get _muted =>
      _isDark ? const Color(0xFFB0BED1) : const Color(0xFF6A7B90);

  Color get _resultColor {
    switch (lastResultStatus) {
      case 'present':
        return const Color(0xFF16875A);
      case 'duplicate':
        return const Color(0xFFBA790C);
      default:
        return const Color(0xFFD64A56);
    }
  }

  IconData get _resultIcon {
    switch (lastResultStatus) {
      case 'present':
        return Icons.task_alt_rounded;
      case 'duplicate':
        return Icons.history_rounded;
      case 'wrong_event':
        return Icons.event_busy_rounded;
      case 'verification_error':
        return Icons.error_outline_rounded;
      default:
        return Icons.qr_code_2_rounded;
    }
  }

  String get _resultTitle {
    switch (lastResultStatus) {
      case 'present':
        return 'Attendance recorded';
      case 'duplicate':
        return 'Already checked in';
      case 'wrong_event':
        return 'QR belongs to another event';
      case 'invalid':
        return 'Invalid QR pass';
      case 'verification_error':
        return 'Could not verify QR';
      default:
        return lastScanSuccessful ? 'QR verified' : 'Scan not accepted';
    }
  }

  BoxDecoration _panelDecoration({double radius = 23}) => BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _border),
    boxShadow: _isDark
        ? null
        : [
      const BoxShadow(
        color: Color(0x0C15283E),
        blurRadius: 22,
        offset: Offset(0, 8),
      ),
    ],
  );

  // --------------------------------------------------------------
  // Demo registration loading. No API calls are made in this page.
  // --------------------------------------------------------------
  void loadMockRegistrations() {
    if (ApiConfig.useRealApi) return;
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
      processingScan = true;
      lastResultStatus = status;
      lastScanSuccessful = success;
      lastMessage = message;
      lastScannedEvent = event;
      lastScannedStudent = studentName;
      lastCheckInTime = checkInTime;
    });
  }

  // --------------------------------------------------------------
  // Existing verification protections retained:
  // selected event, registration token, duplicate attendance, demo.
  // --------------------------------------------------------------
  Future<void> _handleQrCode(String rawValue) async {
    if (ApiConfig.useRealApi ||
        processingScan ||
        !canScanAttendance ||
        selectedEvent == null) {
      return;
    }

    final event = selectedEvent!;
    final key = eventKey(event);
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
      // It is safe if the camera was already stopped.
    }
    if (!mounted) return;

    try {
      final token = decodeStudentEventQr(rawValue);
      if (token == null) {
        _showScanResult(
          status: 'invalid',
          message: 'This code is not a valid EventEase demo student QR pass.',
        );
        return;
      }

      final registeredForEvent = registeredEvents.any(
            (entry) => eventKey(entry) == key,
      );
      final tokenMatchesEvent = registeredForEvent && qrTokens[key] == token;

      if (!tokenMatchesEvent) {
        final belongsToAnotherEvent = qrTokens.entries.any(
              (entry) =>
          entry.key != key &&
              entry.value == token &&
              registeredEvents.any((item) => eventKey(item) == entry.key),
        );
        _showScanResult(
          status: belongsToAnotherEvent ? 'wrong_event' : 'invalid',
          message: belongsToAnotherEvent
              ? 'Choose the event associated with this demo QR pass.'
              : 'No matching demo registration was found for this QR pass.',
        );
        return;
      }

      // Reopening the scanner must not allow attendance to be recorded twice.
      if (attendanceStatus[key] == 'Present') {
        scanHistory.insert(
          0,
          ScanHistory(
            eventTitle: event.title,
            studentName: savedName,
            scannerName: scannerDisplayName,
            status: 'Duplicate',
            scannedAt: DateTime.now(),
          ),
        );
        _showScanResult(
          status: 'duplicate',
          message: 'Demo attendance was already recorded for this event.',
          event: event,
          studentName: savedName,
          checkInTime: attendanceCheckInTime[key],
        );
        return;
      }

      final result = await qrVerificationService.verifyQr(
        token: token,
        eventId: key,
        eventTitle: event.title,
      );
      if (!mounted) return;

      final now = DateTime.now();
      final status = result.status.toString().toLowerCase().split('.').last;
      final accepted = status == 'present' && result.success;
      final duplicate = status == 'duplicate';
      final scannedTime = result.checkInTime;

      if (accepted && tokenMatchesEvent) {
        attendanceStatus[key] = 'Present';
        attendanceCheckInTime[key] = scannedTime ?? formatCheckInTime(now);
      }

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

      _showScanResult(
        status: status,
        message: result.message,
        success: accepted,
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
      debugPrint('Demo QR verification error: $error');
      _showScanResult(
        status: 'verification_error',
        message: 'Demo verification failed. Please try again.',
      );
    }
  }

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
      // The scanner may already be running.
    }
  }

  Future<void> _toggleTorch() async {
    if (isVerifyingScan) return;
    try {
      await scannerController.toggleTorch();
      if (mounted) setState(() => _torchEnabled = !_torchEnabled);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flashlight is unavailable on this camera.')),
      );
    }
  }

  Future<void> _switchCamera() async {
    if (isVerifyingScan) return;
    try {
      await scannerController.switchCamera();
      if (mounted) setState(() => _torchEnabled = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera switching is unavailable.')),
      );
    }
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------
  // Reusable UI components
  // --------------------------------------------------------------
  Widget _eyebrow(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: _muted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.7,
    ),
  );

  Widget _sectionHeader(String number, String title, {String? hint}) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isDark
              ? const Color(0xFF293F60)
              : const Color(0xFFEAF1FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          number,
          style: TextStyle(
            color: _isDark ? const Color(0xFFFFD36B) : navy,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      if (hint != null)
        Text(
          hint,
          style: TextStyle(color: _muted, fontSize: 11),
        ),
    ],
  );

  Widget _metric(String number, String label, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFFD46C)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD2E0F4),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _hero() {
    final totalPresent = scanHistory.where((r) => r.status == 'Present').length;
    final totalDuplicates =
        scanHistory.where((r) => r.status == 'Duplicate').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF092B58), Color(0xFF13508B), Color(0xFF1A618F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFFFFD46C),
                  size: 25,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'EVENTEASE  /  SCAN STATION',
                  style: TextStyle(
                    color: Color(0xFFE4F0FC),
                    fontSize: 11,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD46C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'DEMO MODE',
                  style: TextStyle(
                    color: Color(0xFF102A4C),
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Attendance scanner',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Ready for ${scannerDisplayName.trim().isEmpty ? 'demo testing' : scannerDisplayName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFCFDFF1),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _metric('$totalPresent', 'Demo check-ins', Icons.check_circle_outline),
              const SizedBox(width: 10),
              _metric('$totalDuplicates', 'Duplicate attempts', Icons.shield_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventPicker() => Container(
    padding: const EdgeInsets.all(17),
    decoration: _panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('01', 'Choose an event', hint: 'Required'),
        const SizedBox(height: 6),
        Text(
          'Select the event before scanning a student pass.',
          style: TextStyle(color: _muted, fontSize: 12.5),
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<Event>(
          key: ValueKey(selectedEvent),
          initialValue: selectedEvent,
          isExpanded: true,
          hint: const Text('Select campus event'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.event_available_outlined),
            filled: true,
            fillColor: _isDark
                ? const Color(0xFF1E324E)
                : const Color(0xFFF6F8FC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: _border),
            ),
          ),
          items: eventList
              .map(
                (event) => DropdownMenuItem<Event>(
              value: event,
              child: Text(
                event.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
              .toList(),
          onChanged: isVerifyingScan
              ? null
              : (value) {
            if (value == null) return;
            setState(() => selectedEvent = value);
            _scanAgain();
          },
        ),
        if (selectedEvent != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF19966B),
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${selectedEvent!.date}  ·  ${selectedEvent!.venue}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _cameraButton(IconData icon, String tooltip, VoidCallback callback) =>
      Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.15),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: isVerifyingScan ? null : callback,
            icon: Icon(icon, color: Colors.white),
          ),
        ),
      );

  Widget _cameraPanel() => Container(
    decoration: _panelDecoration(),
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('02', 'Scan student pass'),
        const SizedBox(height: 13),
        ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: SizedBox(
            height: 340,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF071321)),
                MobileScanner(
                  controller: scannerController,
                  onDetect: (capture) {
                    if (selectedEvent == null || processingScan) return;
                    if (capture.barcodes.isEmpty) return;
                    final raw = capture.barcodes.first.rawValue;
                    if (raw == null || raw.isEmpty) return;
                    _handleQrCode(raw);
                  },
                ),
                // Subtle lens tint to anchor the QR frame.
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.10),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 218,
                    height: 218,
                    child: CustomPaint(
                      painter: _EventEaseScanCorners(
                        color: const Color(0xFFFFD46C),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 13,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        selectedEvent == null
                            ? 'SELECT AN EVENT TO BEGIN'
                            : lastMessage != null
                            ? 'SCANNER PAUSED'
                            : 'ALIGN QR INSIDE THE FRAME',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
                if (selectedEvent == null || lastMessage != null || isVerifyingScan)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Center(
                          child: isVerifyingScan
                              ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFFFFD46C),
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Verifying demo QR...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          )
                              : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                lastMessage == null
                                    ? Icons.event_note_rounded
                                    : Icons.pause_circle_outline_rounded,
                                color: const Color(0xFFFFD46C),
                                size: 42,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                lastMessage == null
                                    ? 'Choose an event above'
                                    : 'Review the result below',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 13,
                  right: 13,
                  child: Row(
                    children: [
                      _cameraButton(
                        _torchEnabled
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        'Toggle flashlight',
                        _toggleTorch,
                      ),
                      const SizedBox(width: 7),
                      _cameraButton(
                        Icons.cameraswitch_rounded,
                        'Switch camera',
                        _switchCamera,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 13),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selectedEvent == null
                  ? Icons.info_outline_rounded
                  : lastMessage != null
                  ? Icons.pause_circle_outline_rounded
                  : Icons.radio_button_checked_rounded,
              color: selectedEvent == null
                  ? _muted
                  : lastMessage != null
                  ? const Color(0xFFBA790C)
                  : const Color(0xFF159F79),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedEvent == null
                    ? 'Camera is ready. Select an event to enable verification.'
                    : lastMessage != null
                    ? 'Scanning paused. Use the button below to continue.'
                    : 'Scanning ${selectedEvent!.title}. Hold the QR code steady.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _resultPanel() {
    if (lastMessage == null) return const SizedBox.shrink();
    final color = _resultColor;
    final isSuccess = lastResultStatus == 'present';
    final background = _isDark
        ? color.withValues(alpha: 0.12)
        : color.withValues(alpha: 0.07);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(_resultIcon, color: color, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _eyebrow('Demo verification result'),
                    const SizedBox(height: 4),
                    Text(
                      _resultTitle,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSuccess ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lastMessage!,
            style: TextStyle(color: _muted, fontSize: 12.5, height: 1.5),
          ),
          if (lastScannedEvent != null) ...[
            const SizedBox(height: 12),
            Divider(color: color.withValues(alpha: 0.2)),
            const SizedBox(height: 4),
            _resultDetail(Icons.event_outlined, lastScannedEvent!.title),
            if (lastScannedStudent != null && lastScannedStudent!.isNotEmpty)
              _resultDetail(Icons.person_outline, lastScannedStudent!),
            if (lastCheckInTime != null && lastCheckInTime!.isNotEmpty)
              _resultDetail(Icons.schedule_rounded, lastCheckInTime!),
          ],
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _scanAgain,
              style: FilledButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(isSuccess || lastResultStatus == 'duplicate'
                  ? 'Scan another QR'
                  : 'Try scanning again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultDetail(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      children: [
        Icon(icon, color: _muted, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: _ink, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );

  Widget _historyPanel() {
    final visible = _showAllHistory ? scanHistory : scanHistory.take(4).toList();
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('03', 'Recent scans', hint: '${scanHistory.length} total'),
          const SizedBox(height: 14),
          if (scanHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 23, horizontal: 12),
              decoration: BoxDecoration(
                color: _isDark
                    ? const Color(0xFF1D3049)
                    : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off_rounded, color: _muted, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'No scans yet',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verified demo check-ins will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...visible.map(_historyRow),
          if (scanHistory.length > 4) ...[
            const SizedBox(height: 3),
            TextButton.icon(
              onPressed: () => setState(() => _showAllHistory = !_showAllHistory),
              icon: Icon(_showAllHistory
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded),
              label: Text(_showAllHistory ? 'Show fewer' : 'View all scans'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyRow(ScanHistory record) {
    final present = record.status == 'Present';
    final color = present ? const Color(0xFF16875A) : const Color(0xFFBA790C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 41,
            height: 41,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              present ? Icons.check_circle_outline : Icons.history_rounded,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  record.eventTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.status.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formatCheckInTime(record.scannedAt),
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notice() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _isDark
          ? const Color(0xFF253248)
          : const Color(0xFFEDF1F7),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: _muted, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'LOCAL DEMONSTRATION ONLY  •  QR checks and attendance '
                'history are stored in the app session, not in Laravel. '
                'Official verification requires server-side authorization.',
            style: TextStyle(color: _muted, fontSize: 11.5, height: 1.5),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (ApiConfig.useRealApi) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Scanner')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Online verification unavailable',
              message: 'The Laravel attendance verification API is not yet '
                  'connected. Switch to Demo Mode for local UI testing.',
            ),
          ),
        ),
      );
    }

    if (!canScanAttendance) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Scanner')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Scanner access unavailable',
              message: 'This scanner view is for authorized event personnel. '
                  'Demo role selection is not real authentication.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 15,
        title: Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: _isDark ? yellow : navy),
            const SizedBox(width: 9),
            Text(
              'Scan Station',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _hero(),
                const SizedBox(height: 17),
                _eventPicker(),
                const SizedBox(height: 17),
                _cameraPanel(),
                if (lastMessage != null) ...[
                  const SizedBox(height: 17),
                  _resultPanel(),
                ],
                const SizedBox(height: 17),
                _historyPanel(),
                const SizedBox(height: 17),
                _notice(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Decorative camera-frame corners. No dependencies or network calls.
class _EventEaseScanCorners extends CustomPainter {
  final Color color;
  const _EventEaseScanCorners({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const edge = 37.0;
    const inset = 2.5;
    final w = size.width - inset;
    final h = size.height - inset;

    final corners = Path()
      ..moveTo(inset, edge)
      ..lineTo(inset, 17)
      ..quadraticBezierTo(inset, inset, 17, inset)
      ..lineTo(edge, inset)
      ..moveTo(w - edge, inset)
      ..lineTo(w - 17, inset)
      ..quadraticBezierTo(w, inset, w, 17)
      ..lineTo(w, edge)
      ..moveTo(w, h - edge)
      ..lineTo(w, h - 17)
      ..quadraticBezierTo(w, h, w - 17, h)
      ..lineTo(w - edge, h)
      ..moveTo(edge, h)
      ..lineTo(17, h)
      ..quadraticBezierTo(inset, h, inset, h - 17)
      ..lineTo(inset, h - edge);
    canvas.drawPath(corners, paint);
  }

  @override
  bool shouldRepaint(covariant _EventEaseScanCorners oldDelegate) =>
      oldDelegate.color != color;
}
