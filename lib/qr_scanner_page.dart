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

  // REAL API MODE: separate from all local demo records.
  List<Map<String, dynamic>> _liveEvents = [];
  Map<String, dynamic>? _liveSelectedEvent;
  List<Map<String, dynamic>> _liveSessions = [];
  int? _liveSessionId;
  String _liveDirection = 'in';
  List<Map<String, dynamic>> _liveHistory = [];
  Map<String, dynamic>? _liveSummary;
  bool _liveLoadingEvents = false;
  bool _liveLoadingSessions = false;
  bool _liveLoadingHistory = false;
  String? _liveError;
  String? _liveSessionError;
  String? _liveHistoryError;
  String? _liveScannedEventTitle;
  int _liveSelectionSerial = 0;
  int _liveHistorySerial = 0;

  bool get canScanAttendance =>
      savedUserRole.trim().toLowerCase() == 'scanner' ||
      savedUserRole.trim().toLowerCase() == 'admin';

  String get scannerDisplayName =>
      savedName.trim().isNotEmpty ? savedName : demoScannerName;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _isDark ? const Color(0xFF0B1424) : const Color(0xFFF3F6FB);
  Color get _surface => _isDark ? const Color(0xFF17263C) : Colors.white;
  Color get _border =>
      _isDark ? const Color(0xFF31445C) : const Color(0xFFE1E8F1);
  Color get _ink => _isDark ? const Color(0xFFF1F6FD) : const Color(0xFF15283E);
  Color get _muted =>
      _isDark ? const Color(0xFFB0BED1) : const Color(0xFF6A7B90);

  Color get _resultColor {
    switch (lastResultStatus) {
      case 'present':
        return const Color(0xFF16875A);
      case 'duplicate':
        return const Color(0xFFBA790C);
      case 'connection_error':
        return const Color(0xFFB97713);
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
      case 'connection_error':
        return Icons.wifi_off_rounded;
      default:
        return Icons.qr_code_2_rounded;
    }
  }

  String get _resultTitle {
    switch (lastResultStatus) {
      case 'present':
        if (ApiConfig.useRealApi) {
          return _liveDirection == 'out'
              ? 'Time Out recorded'
              : 'Time In recorded';
        }
        return 'Attendance recorded';
      case 'duplicate':
        if (ApiConfig.useRealApi) {
          return _liveDirection == 'in'
              ? 'Already checked in'
              : 'Already checked out';
        }
        return 'Already checked in';
      case 'wrong_event':
        return 'QR belongs to another event';
      case 'invalid':
        return 'Invalid QR pass';
      case 'verification_error':
        return 'Could not verify QR';
      case 'connection_error':
        return 'Connection interrupted';
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
  // Authenticated Laravel scanner API. Authorization, event assignment,
  // session windows, and duplicate detection are enforced server-side.
  // --------------------------------------------------------------
  Map<String, dynamic>? get _activeLiveSession {
    for (final session in _liveSessions) {
      if (_liveSessionId == _liveInt(session['id'])) {
        return session;
      }
    }
    return null;
  }

  bool get _canLiveScan {
    if (!ApiConfig.useRealApi || !canScanAttendance) {
      return false;
    }
    if (_liveLoadingEvents ||
        _liveLoadingSessions ||
        _liveError != null ||
        _liveSessionError != null ||
        _liveSelectedEvent == null) {
      return false;
    }
    final eventToken = '${_liveSelectedEvent?['checkin_token'] ?? ''}'.trim();
    final session = _activeLiveSession;
    return eventToken.isNotEmpty && session != null && session['open'] == true;
  }

  static int? _liveInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('${value ?? ''}');
  }

  static String _liveText(Object? value, [String fallback = '']) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? fallback : text;
  }

  static Map<String, dynamic> _liveMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Unexpected Laravel response.');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> _liveItems(Object? payload) {
    final list = payload is List
        ? payload
        : (payload is Map ? payload['data'] : null);
    if (list is! List) {
      throw const FormatException('Unexpected Laravel list response.');
    }
    return list.map(_liveMap).toList();
  }

  static Uri _liveUri(String path, {Map<String, String>? query}) {
    final base = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw StateError('The secure Laravel API URL is not configured.');
    }
    return base.replace(path: path, queryParameters: query, fragment: null);
  }

  static String _liveHttpError(http.Response response) {
    if (response.statusCode == 401) {
      return 'Your scanner session expired. Sign in again.';
    }
    if (response.statusCode == 403) {
      return 'Laravel denied scanner access. Check your role and event assignment.';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          for (final error in errors.values) {
            if (error is List && error.isNotEmpty) {
              return '${error.first}';
            }
          }
        }
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Some gateway errors do not return JSON.
    }
    if (response.statusCode == 404) {
      return 'This event, session, or QR credential was not found in Laravel.';
    }
    return 'Laravel could not complete this request (HTTP ${response.statusCode}).';
  }

  Future<dynamic> _liveRequest(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final token = await authTokenStorage.readValidToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Your scanner login expired. Please sign in again.');
    }
    final uri = _liveUri(path, query: query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
      if (body != null) 'Content-Type': 'application/json',
    };
    final http.Response response;
    if (method == 'GET') {
      response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    } else if (method == 'POST') {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } else {
      throw StateError('Unsupported scanner request method.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_liveHttpError(response));
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('Laravel returned invalid JSON.');
    }
  }

  static String _friendlyLiveError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    if (error is FormatException) {
      return error.message;
    }
    return 'Unable to contact Laravel. Check ngrok and your internet connection.';
  }

  Future<void> _loadLiveEvents() async {
    if (!ApiConfig.useRealApi || !canScanAttendance || _liveLoadingEvents) {
      return;
    }
    if (mounted) {
      setState(() {
        _liveLoadingEvents = true;
        _liveError = null;
      });
    }
    try {
      final rows = _liveItems(await _liveRequest('GET', '/api/scanner/events'));
      if (!mounted) {
        return;
      }
      final currentRef = _liveSelectedEvent?['reference'];
      setState(() {
        _liveEvents = rows;
        _liveLoadingEvents = false;
        _liveSelectedEvent = null;
        processingScan = true;
        _liveSessions = [];
        _liveSessionId = null;
        _liveSessionError = null;
      });
      final match = rows
          .where((row) => row['reference'] == currentRef)
          .toList();
      if (match.isNotEmpty) {
        await _selectLiveEvent(match.first);
      }
      _loadLiveHistory();
      _loadLiveSummary();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveLoadingEvents = false;
        _liveError = _friendlyLiveError(error);
      });
    }
  }

  Future<void> _selectLiveEvent(Map<String, dynamic> event) async {
    final serial = ++_liveSelectionSerial;
    try {
      await scannerController.stop();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _liveSelectedEvent = event;
      _liveSessions = [];
      _liveSessionId = null;
      _liveSessionError = null;
      _liveLoadingSessions = true;
      processingScan = true;
      lastMessage = null;
      _liveScannedEventTitle = null;
      _liveHistory = [];
    });
    _loadLiveHistory();
    final token = _liveText(event['checkin_token']);
    if (token.isEmpty) {
      setState(() {
        _liveLoadingSessions = false;
        _liveSessionError =
            'This event has no check-in token. An administrator '
            'must generate its check-in poster in Laravel first.';
      });
      return;
    }
    try {
      final payload = _liveMap(
        await _liveRequest('GET', '/api/checkin/${Uri.encodeComponent(token)}'),
      );
      final sessions = _liveItems(payload['sessions']);
      if (!mounted || serial != _liveSelectionSerial) {
        return;
      }
      final openSessions = sessions.where((s) => s['open'] == true).toList();
      setState(() {
        _liveSessions = sessions;
        _liveSessionId = openSessions.isEmpty
            ? null
            : _liveInt(openSessions.first['id']);
        _liveLoadingSessions = false;
      });
      if (_canLiveScan) {
        await _scanAgain();
      }
    } catch (error) {
      if (!mounted || serial != _liveSelectionSerial) {
        return;
      }
      setState(() {
        _liveLoadingSessions = false;
        _liveSessionError = _friendlyLiveError(error);
      });
    }
  }

  Future<void> _loadLiveHistory() async {
    if (!ApiConfig.useRealApi || !canScanAttendance) {
      return;
    }
    final serial = ++_liveHistorySerial;
    // Laravel's history method allows Scanner, but not Admin, accounts.
    if (savedUserRole.trim().toLowerCase() == 'admin') {
      if (mounted) {
        setState(() {
          _liveHistoryError =
              'Personal scan history is available to assigned Scanner accounts.';
          _liveHistory = [];
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _liveLoadingHistory = true;
        _liveHistoryError = null;
      });
    }
    try {
      final query = <String, String>{};
      final selected = _liveText(_liveSelectedEvent?['reference']);
      if (selected.isNotEmpty) query['event_reference'] = selected;
      final data = await _liveRequest(
        'GET',
        '/api/scanner/history',
        query: query.isEmpty ? null : query,
      );
      final rows = _liveItems(data);
      if (!mounted || serial != _liveHistorySerial) {
        return;
      }
      setState(() {
        _liveHistory = rows;
        _liveLoadingHistory = false;
      });
    } catch (error) {
      if (!mounted || serial != _liveHistorySerial) {
        return;
      }
      setState(() {
        _liveHistoryError = _friendlyLiveError(error);
        _liveLoadingHistory = false;
        _liveHistory = [];
      });
    }
  }

  Future<void> _loadLiveSummary() async {
    if (!ApiConfig.useRealApi ||
        !canScanAttendance ||
        savedUserRole.trim().toLowerCase() == 'admin') {
      return;
    }
    try {
      final result = _liveMap(
        await _liveRequest('GET', '/api/scanner/summary'),
      );
      if (mounted) {
        setState(() => _liveSummary = result);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _liveSummary = null);
      }
    }
  }

  Future<void> _handleLiveQrCode(String rawValue) async {
    if (!_canLiveScan || processingScan || isVerifyingScan) {
      return;
    }
    final qr = rawValue.trim();
    if (qr.isEmpty) {
      return;
    }
    if (qr.length > 100) {
      try {
        await scannerController.stop();
      } catch (_) {}
      _showScanResult(
        status: 'invalid',
        message: "The scanned QR exceeds Laravel's allowed credential length.",
      );
      return;
    }
    final event = _liveSelectedEvent!;
    final checkinToken = _liveText(event['checkin_token']);
    final sessionId = _liveSessionId!;
    final direction = _liveDirection;
    setState(() {
      processingScan = true;
      isVerifyingScan = true;
      lastMessage = null;
      lastResultStatus = null;
      _liveScannedEventTitle = null;
    });
    try {
      await scannerController.stop();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    try {
      final payload = _liveMap(
        await _liveRequest(
          'POST',
          '/api/checkin/${Uri.encodeComponent(checkinToken)}/scan',
          body: {
            'qr_code': qr,
            'session_id': sessionId,
            'direction': direction,
          },
        ),
      );
      if (!mounted) {
        return;
      }
      final attendance = payload['attendance'];
      final attendanceMap = attendance is Map ? _liveMap(attendance) : null;
      final skipped = payload['skipped'];
      final hasSkipped = skipped is Map
          ? skipped.isNotEmpty
          : (skipped is List && skipped.isNotEmpty);
      final successful =
          attendanceMap != null &&
          !hasSkipped &&
          (direction == 'in'
              ? attendanceMap['time_in'] != null
              : attendanceMap['time_out'] != null);
      final registration = payload['registration'];
      final student = payload['student'];
      final identity = registration is Map ? registration : student;
      final name = identity is Map ? _liveText(identity['participant']) : '';
      final message = _liveText(
        payload['message'],
        successful ? 'Attendance saved in Laravel.' : 'Scan was not recorded.',
      );
      final scannedTimeValue = attendanceMap == null
          ? null
          : attendanceMap[direction == 'in' ? 'time_in' : 'time_out'];
      final duplicate =
          !successful && message.toLowerCase().contains('already');
      _liveScannedEventTitle = _liveText(event['title']);
      _showScanResult(
        status: successful
            ? 'present'
            : duplicate
            ? 'duplicate'
            : 'verification_error',
        message: message,
        success: successful,
        studentName: name.isEmpty ? null : name,
        checkInTime: successful ? _liveText(scannedTimeValue) : null,
      );
      if (successful) {
        _loadLiveHistory();
        _loadLiveSummary();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _friendlyLiveError(error);
      final isDuplicate = message.toLowerCase().contains('already');
      final isWrongEvent =
          message.toLowerCase().contains('not registered') ||
          message.toLowerCase().contains('does not belong');
      // A transport failure never confirms or rejects attendance.
      // Keep the scan paused until the operator checks the server record.
      final isConnectionError =
          error is! StateError && error is! FormatException;
      _showScanResult(
        status: isConnectionError
            ? 'connection_error'
            : isDuplicate
            ? 'duplicate'
            : isWrongEvent
            ? 'wrong_event'
            : 'verification_error',
        message: isConnectionError
            ? 'Could not confirm the scan with Laravel. Attendance status is unknown. '
                  'Check server scan history before trying again to avoid duplicates.'
            : message,
      );
    }
  }

  // --------------------------------------------------------------
  // Demo registration loading. Demo data is separate from the API.
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
    if (ApiConfig.useRealApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLiveEvents();
      });
    } else {
      loadMockRegistrations();
    }
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
    if (ApiConfig.useRealApi) {
      await _handleLiveQrCode(rawValue);
      return;
    }
    if (processingScan || !canScanAttendance || selectedEvent == null) {
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
      _liveScannedEventTitle = null;
    });
    try {
      // Never start the camera before an event (and live session) is ready.
      if ((ApiConfig.useRealApi && _canLiveScan) ||
          (!ApiConfig.useRealApi &&
              canScanAttendance &&
              selectedEvent != null)) {
        await scannerController.start();
      }
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
        const SnackBar(
          content: Text('Flashlight is unavailable on this camera.'),
        ),
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
          color: _isDark ? const Color(0xFF293F60) : const Color(0xFFEAF1FA),
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
        Text(hint, style: TextStyle(color: _muted, fontSize: 11)),
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
    final totalDuplicates = scanHistory
        .where((r) => r.status == 'Duplicate')
        .length;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD46C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ApiConfig.useRealApi ? 'LIVE LARAVEL' : 'DEMO MODE',
                  style: const TextStyle(
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
            'Ready for ${scannerDisplayName.trim().isEmpty ? 'scanner testing' : scannerDisplayName}',
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
              _metric(
                ApiConfig.useRealApi
                    ? '${_liveSummary?['scans_today'] ?? '—'}'
                    : '$totalPresent',
                ApiConfig.useRealApi ? 'Scans today' : 'Demo check-ins',
                Icons.check_circle_outline,
              ),
              const SizedBox(width: 10),
              _metric(
                ApiConfig.useRealApi
                    ? '${_liveSummary?['events_today'] ?? '—'}'
                    : '$totalDuplicates',
                ApiConfig.useRealApi ? 'Events today' : 'Duplicate attempts',
                Icons.shield_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventPicker() => ApiConfig.useRealApi
      ? _liveEventPicker()
      : Container(
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

  Widget _liveEventPicker() {
    final ref = _liveText(_liveSelectedEvent?['reference']);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader('01', 'Assigned event', hint: 'Laravel'),
              ),
              IconButton(
                tooltip: 'Refresh assigned events',
                onPressed: _liveLoadingEvents || isVerifyingScan
                    ? null
                    : _loadLiveEvents,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Only approved events assigned by Laravel can be scanned.',
            style: TextStyle(color: _muted, fontSize: 12.5),
          ),
          if (_liveLoadingEvents)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: LinearProgressIndicator(),
            ),
          if (_liveError != null) ...[
            const SizedBox(height: 12),
            Text(_liveError!, style: const TextStyle(color: Color(0xFFD64A56))),
          ],
          if (!_liveLoadingEvents &&
              _liveError == null &&
              _liveEvents.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'No approved events assigned to this scanner. '
              'Ask an administrator to assign an event and prepare its sessions.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            key: ValueKey('live-event-picker-$ref'),
            initialValue: ref.isEmpty ? null : ref,
            isExpanded: true,
            hint: const Text('Choose an assigned event'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.event_available_outlined),
              filled: true,
              fillColor: _isDark
                  ? const Color(0xFF1E324E)
                  : const Color(0xFFF6F8FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            items: _liveEvents
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: _liveText(e['reference']),
                    child: Text(
                      _liveText(e['title'], 'Untitled event'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _liveLoadingEvents || isVerifyingScan
                ? null
                : (selected) {
                    if (selected == null) return;
                    final matches = _liveEvents
                        .where((e) => _liveText(e['reference']) == selected)
                        .toList();
                    if (matches.isNotEmpty) _selectLiveEvent(matches.first);
                  },
          ),
          if (_liveSelectedEvent != null) ...[
            const SizedBox(height: 11),
            Text(
              '${_liveText(_liveSelectedEvent?['event_date'], 'Date unavailable')} '
              ' • ${_liveText(_liveSelectedEvent?['venue'], 'Venue unavailable')}',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            if (_liveLoadingSessions)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: LinearProgressIndicator(),
              ),
            if (_liveSessionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _liveSessionError!,
                  style: const TextStyle(color: Color(0xFFD64A56)),
                ),
              ),
            if (!_liveLoadingSessions && _liveSessionError == null) ...[
              const SizedBox(height: 16),
              _sectionHeader('02', 'Attendance session', hint: 'Required'),
              const SizedBox(height: 9),
              if (_liveSessions.isEmpty)
                Text(
                  'This event has no attendance sessions. Ask the admin to create sessions.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              if (_liveSessions.isNotEmpty)
                DropdownButtonFormField<int>(
                  key: ValueKey('live-session-$_liveSessionId'),
                  initialValue: _liveSessionId,
                  isExpanded: true,
                  hint: const Text('Choose an open session'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.schedule_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  items: _liveSessions
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: _liveInt(s['id']),
                          enabled: s['open'] == true,
                          child: Text(
                            '${_liveText(s['label'], 'Session')} '
                            '(${_liveText(s['session_date'])})'
                            '${s['open'] == true ? ' • OPEN' : ' • CLOSED'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isVerifyingScan
                      ? null
                      : (value) {
                          setState(() => _liveSessionId = value);
                          if (_canLiveScan) _scanAgain();
                        },
                ),
              if (_liveSessions.isNotEmpty && _liveSessionId == null)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    'No open session is selected. Closed sessions cannot accept scans.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              _sectionHeader('03', 'Attendance action', hint: 'Choose one'),
              const SizedBox(height: 9),
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Time In'),
                    selected: _liveDirection == 'in',
                    onSelected: isVerifyingScan
                        ? null
                        : (_) {
                            setState(() => _liveDirection = 'in');
                            _scanAgain();
                          },
                  ),
                  ChoiceChip(
                    label: const Text('Time Out'),
                    selected: _liveDirection == 'out',
                    onSelected: isVerifyingScan
                        ? null
                        : (_) {
                            setState(() => _liveDirection = 'out');
                            _scanAgain();
                          },
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

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
                    if (processingScan ||
                        (ApiConfig.useRealApi
                            ? !_canLiveScan
                            : selectedEvent == null)) {
                      return;
                    }
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
                        (ApiConfig.useRealApi
                                ? !_canLiveScan
                                : selectedEvent == null)
                            ? 'SELECT EVENT AND OPEN SESSION'
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
                if ((ApiConfig.useRealApi
                        ? !_canLiveScan
                        : selectedEvent == null) ||
                    lastMessage != null ||
                    isVerifyingScan)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Center(
                          child: isVerifyingScan
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color(0xFFFFD46C),
                                    ),
                                    SizedBox(height: 14),
                                    Text(
                                      ApiConfig.useRealApi
                                          ? 'Verifying with Laravel...'
                                          : 'Verifying demo QR...',
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
                                          ? (ApiConfig.useRealApi
                                                ? 'Select an event and open session above'
                                                : 'Choose an event above')
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
              (ApiConfig.useRealApi ? !_canLiveScan : selectedEvent == null)
                  ? Icons.info_outline_rounded
                  : lastMessage != null
                  ? Icons.pause_circle_outline_rounded
                  : Icons.radio_button_checked_rounded,
              color:
                  (ApiConfig.useRealApi ? !_canLiveScan : selectedEvent == null)
                  ? _muted
                  : lastMessage != null
                  ? const Color(0xFFBA790C)
                  : const Color(0xFF159F79),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (ApiConfig.useRealApi ? !_canLiveScan : selectedEvent == null)
                    ? (ApiConfig.useRealApi
                          ? 'Select an assigned event and OPEN session before scanning.'
                          : 'Camera is ready. Select an event to enable verification.')
                    : lastMessage != null
                    ? 'Scanning paused. Use the button below to continue.'
                    : (ApiConfig.useRealApi
                          ? 'Scanning ${_liveText(_liveSelectedEvent?['title'])} • '
                                '${_liveDirection == 'in' ? 'Time In' : 'Time Out'}.'
                          : 'Scanning ${selectedEvent!.title}. Hold the QR code steady.'),
                style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
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
                    _eyebrow(
                      ApiConfig.useRealApi
                          ? 'Laravel verification result'
                          : 'Demo verification result',
                    ),
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
          if (lastResultStatus == 'connection_error') ...[
            const SizedBox(height: 10),
            Text(
              'Do not assume the student is absent or present. '
              'A request can reach Laravel even if its reply is lost.',
              style: TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (lastScannedEvent != null ||
              (ApiConfig.useRealApi && _liveScannedEventTitle != null)) ...[
            const SizedBox(height: 12),
            Divider(color: color.withValues(alpha: 0.2)),
            const SizedBox(height: 4),
            _resultDetail(
              Icons.event_outlined,
              ApiConfig.useRealApi
                  ? _liveScannedEventTitle!
                  : lastScannedEvent!.title,
            ),
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
              label: Text(
                lastResultStatus == 'connection_error'
                    ? 'Resume scanner after checking history'
                    : isSuccess || lastResultStatus == 'duplicate'
                    ? 'Scan another QR'
                    : 'Try scanning again',
              ),
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
          child: Text(value, style: TextStyle(color: _ink, fontSize: 12.5)),
        ),
      ],
    ),
  );

  Widget _historyPanel() {
    if (ApiConfig.useRealApi) return _liveHistoryPanel();
    final visible = _showAllHistory
        ? scanHistory
        : scanHistory.take(4).toList();
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            '03',
            'Recent scans',
            hint: '${scanHistory.length} total',
          ),
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
                  Icon(
                    Icons.history_toggle_off_rounded,
                    color: _muted,
                    size: 32,
                  ),
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
              onPressed: () =>
                  setState(() => _showAllHistory = !_showAllHistory),
              icon: Icon(
                _showAllHistory
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(_showAllHistory ? 'Show fewer' : 'View all scans'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _liveHistoryPanel() {
    final rows = _showAllHistory ? _liveHistory : _liveHistory.take(4).toList();
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  '04',
                  'Recent server scans',
                  hint: '${_liveHistory.length} loaded',
                ),
              ),
              IconButton(
                tooltip: 'Refresh recent scans',
                onPressed: _liveLoadingHistory ? null : _loadLiveHistory,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_liveLoadingHistory) const LinearProgressIndicator(),
          if (_liveHistoryError != null)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                _liveHistoryError!,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          if (!_liveLoadingHistory &&
              _liveHistory.isEmpty &&
              _liveHistoryError == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No server-recorded scans for this selection.',
                  style: TextStyle(color: _muted),
                ),
              ),
            ),
          const SizedBox(height: 7),
          ...rows.map(_liveHistoryRow),
          if (_liveHistory.length > 4)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _showAllHistory = !_showAllHistory),
                icon: Icon(
                  _showAllHistory
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
                label: Text(
                  _showAllHistory ? 'Show fewer' : 'View loaded scans',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _liveHistoryRow(Map<String, dynamic> record) {
    final registration = record['registration'] is Map
        ? Map<String, dynamic>.from(record['registration'] as Map)
        : <String, dynamic>{};
    final session = record['session'] is Map
        ? Map<String, dynamic>.from(record['session'] as Map)
        : <String, dynamic>{};
    final name = _liveText(registration['participant'], 'Student');
    final status = _liveText(record['status'], 'Recorded');
    final time = DateTime.tryParse(_liveText(record['recorded_at']))?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: Color(0xFF16875A)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${_liveText(session['label'], 'Event session')} • $status',
                  style: TextStyle(color: _muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            time == null ? '—' : formatCheckInTime(time),
            style: TextStyle(color: _muted, fontSize: 11.5),
          ),
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
      color: _isDark ? const Color(0xFF253248) : const Color(0xFFEDF1F7),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: _muted, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ApiConfig.useRealApi
                ? 'LIVE LARAVEL MODE • The server checks scanner assignment, '
                      'event registration, session windows, and duplicate scans. '
                      'Only a successful server response counts as attendance.'
                : 'LOCAL DEMONSTRATION ONLY  •  QR checks and attendance '
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
    if (!canScanAttendance) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Scanner')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Scanner access unavailable',
              message: ApiConfig.useRealApi
                  ? 'Sign in with an active Scanner account assigned by Laravel. '
                        'Student accounts cannot record attendance.'
                  : 'This scanner view is for authorized event personnel. '
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
