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


// =============================================================
// STEP 13: OFFICIAL LARAVEL CERTIFICATE (REAL API ONLY)
// Independent of the existing DEMO ECertificatePage above.
// Requires imports in main.dart:
//   import 'dart:typed_data';
//   import 'package:printing/printing.dart';
// =============================================================
class LaravelCertificatePage extends StatefulWidget {
  final String eventTitle;
  final String eventDate;

  const LaravelCertificatePage({
    super.key,
    required this.eventTitle,
    this.eventDate = '',
  });

  @override
  State<LaravelCertificatePage> createState() =>
      _LaravelCertificatePageState();
}

class _LaravelCertificatePageState extends State<LaravelCertificatePage> {
  static const _navy = Color(0xFF102A4C);
  static const _blue = Color(0xFF215B99);
  static const _gold = Color(0xFFFFCB4D);

  bool _loading = true;
  bool _pdfLoading = false;
  String? _error;
  List<Map<String, dynamic>> _certificates = [];
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  static String _value(Map<String, dynamic> row, String key,
      [String fallback = '']) {
    final raw = row[key];
    return raw == null ? fallback : raw.toString().trim();
  }

  static Uri _uri(List<String> path, {int? page}) {
    final origin = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (origin == null || origin.scheme != 'https' ||
        origin.host.isEmpty || origin.userInfo.isNotEmpty ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw StateError('The secure Laravel API URL is not configured.');
    }
    return origin.replace(
      pathSegments: path,
      queryParameters: page == null ? null : {'page': '$page'},
      fragment: null,
    );
  }

  static Future<String> _token() async {
    final token = await authTokenStorage.readValidToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Your session has expired. Please log in again.');
    }
    return token;
  }

  static Map<String, String> _headers(String token,
      {bool pdf = false}) => {
    'Accept': pdf ? 'application/pdf' : 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': 'true',
  };

  static String _serverError(http.Response response) {
    if (response.statusCode == 401) {
      return 'Your student login has expired. Please sign in again.';
    }
    if (response.statusCode == 403) {
      return 'The server has denied access to this certificate.';
    }
    if (response.statusCode == 404) {
      return 'Certificate not found or not available for your account.';
    }
    if (response.statusCode == 422) {
      return 'This certificate is not yet eligible for PDF access.';
    }
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['message'] is String) {
        return payload['message'] as String;
      }
    } catch (_) {}
    return 'Laravel returned HTTP ${response.statusCode}.';
  }

  Future<void> _reload() async {
    if (!ApiConfig.useRealApi) return;
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
      _certificates = [];
    });
    try {
      final token = await _token();
      final all = <Map<String, dynamic>>[];
      var page = 1;
      var lastPage = 1;
      do {
        final response = await http.get(
          _uri(['api', 'certificates'], page: page),
          headers: _headers(token),
        ).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw StateError(_serverError(response));
        }
        final payload = jsonDecode(response.body);
        if (payload is! Map || payload['data'] is! List) {
          throw const FormatException('Unexpected certificate listing format.');
        }
        for (final item in payload['data'] as List) {
          if (item is! Map) {
            throw const FormatException('Invalid certificate record.');
          }
          all.add(Map<String, dynamic>.from(item));
        }
        lastPage = int.tryParse('${payload['last_page'] ?? 1}') ?? 1;
        if (lastPage > 50) {
          throw StateError('Too many certificate pages; ask the developer '
              'to add event filtering for student certificates.');
        }
        page++;
      } while (page <= lastPage);
      if (!mounted || serial != _requestSerial) return;
      setState(() => _certificates = all);
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() => _error = error is StateError
          ? error.message.toString()
          : error is FormatException
          ? error.message
          : 'Unable to contact Laravel. Check ngrok and your connection.');
    } finally {
      if (mounted && serial == _requestSerial) {
        setState(() => _loading = false);
      }
    }
  }

  // The current certificate API returns the event TITLE rather than the
  // event reference. Restrict matching to exact titles; do not guess.
  List<Map<String, dynamic>> get _matching => _certificates.where((item) =>
  _value(item, 'event').toLowerCase() ==
      widget.eventTitle.trim().toLowerCase()).toList();

  // Do not select an arbitrary certificate when multiple records use
  // the same event title. The API should supply an event reference so
  // students can open the intended certificate unambiguously.
  Map<String, dynamic>? get _selected {
    final matches = _matching;
    return matches.length == 1 ? matches.single : null;
  }

  bool get _ambiguousCertificate => _matching.length > 1;

  Widget _ambiguousCard() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.error, size: 30),
          const SizedBox(height: 12),
          const Text('Certificate selection needs verification',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          Text(
            'Laravel returned multiple certificate records for this event title. '
                'To prevent displaying the wrong certificate, PDF access is paused. '
                'Ask your web partner to include an event reference in certificate '
                'records and use that reference for exact matching.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh certificates'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPdf(Map<String, dynamic> record,
      {required bool share}) async {
    if (_pdfLoading || !ApiConfig.useRealApi ||
        _value(record, 'status').toLowerCase() != 'issued') {
      return;
    }
    final reference = _value(record, 'reference');
    if (reference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Laravel did not provide a certificate reference.'),
      ));
      return;
    }
    setState(() => _pdfLoading = true);
    try {
      final token = await _token();
      final response = await http.get(
        _uri(['api', 'certificates', reference, share ? 'download' : 'preview']),
        headers: _headers(token, pdf: true),
      ).timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        throw StateError(_serverError(response));
      }
      final bytes = response.bodyBytes;
      final isPdf = bytes.length >= 5 &&
          bytes[0] == 37 && bytes[1] == 80 && bytes[2] == 68 &&
          bytes[3] == 70 && bytes[4] == 45; // %PDF-
      if (!isPdf) {
        throw StateError('Laravel did not return a valid PDF document.');
      }
      final filename = '${reference.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';
      if (!mounted) return;
      if (share) {
        // Android's share sheet supports saving to Files/Drive, depending
        // on installed apps. It is not a direct Downloads-folder write.
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } else {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _LaravelCertificatePdfPreview(
              bytes: bytes, filename: filename),
        ));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is StateError
            ? error.message.toString()
            : 'Unable to open this PDF. Please try again.'),
      ));
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  // This page displays only statuses returned by Laravel.
  // Do not infer certificate eligibility from local attendance or ratings.
  String _eligibilityExplanation(Map<String, dynamic> record) {
    for (final field in [
      'eligibility_reason',
      'ineligibility_reason',
      'status_reason',
      'reason',
    ]) {
      final value = _value(record, field);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Widget _statusCard(Map<String, dynamic>? record) {
    final c = Theme.of(context).colorScheme;
    final status = record == null
        ? 'Not yet issued'
        : _value(record, 'status', 'Unknown');
    final normalizedStatus = status.toLowerCase();
    final issued = normalizedStatus == 'issued';
    final pending = normalizedStatus == 'pending';
    final notEligible = normalizedStatus == 'not eligible';
    final accent = issued
        ? const Color(0xFF158063)
        : notEligible
        ? c.error
        : pending
        ? const Color(0xFFAD7810)
        : _blue;
    final reason = record == null ? '' : _eligibilityExplanation(record);

    String explanation;
    if (issued) {
      explanation = 'Laravel confirms that this certificate is issued.';
    } else if (pending) {
      explanation = 'This certificate is awaiting administrator action. '
          'PDF access is unavailable until it is issued.';
    } else if (notEligible) {
      explanation = 'Laravel currently marks this certificate as not eligible. '
          'Check with the event administrator if you believe your attendance '
          'and other requirements are complete.';
    } else if (record == null) {
      explanation = 'No matching certificate record was returned for this event. '
          'This does not by itself mean you are ineligible.';
    } else {
      explanation = 'Certificate status reported by Laravel: $status. '
          'An official PDF is available only when the status is Issued.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                issued
                    ? Icons.workspace_premium_rounded
                    : notEligible
                    ? Icons.info_outline_rounded
                    : Icons.hourglass_top_rounded,
                color: accent,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  issued ? 'Official certificate available' : 'Certificate status',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            status,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: TextStyle(color: c.onSurfaceVariant, height: 1.5),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Reason provided by Laravel',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: c.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              reason,
              style: TextStyle(color: c.onSurfaceVariant, height: 1.5),
            ),
          ],
          if (record != null) ...[
            const SizedBox(height: 16),
            Divider(color: c.outlineVariant),
            const SizedBox(height: 8),
            Text('Reference: ${_value(record, 'reference', 'Unavailable')}',
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 5),
            Text('Participant: ${_value(record, 'participant', 'Unavailable')}',
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
            if (_value(record, 'date_issued').isNotEmpty) ...[
              const SizedBox(height: 5),
              Text('Issued: ${_value(record, 'date_issued')}',
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
            ],
            if (issued) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _pdfLoading
                      ? null
                      : () => _loadPdf(record, share: false),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(_pdfLoading ? 'Loading PDF...' : 'View official PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pdfLoading
                      ? null
                      : () => _loadPdf(record, share: true),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Save / Share PDF'),
                ),
              ),
            ],
          ],
          if (!issued) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading || _pdfLoading ? null : _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh certificate status'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.useRealApi) {
      return const Scaffold(body: Center(child:
      Text('Official certificates are available in Real API Mode only.')));
    }
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My E-Certificate'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh certificate status',
            onPressed: _loading || _pdfLoading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 38),
          children: [
            Container(
              padding: const EdgeInsets.all(21),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_navy, _blue]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: _gold, size: 43),
                const SizedBox(width: 13),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TMC EVENTEASE • CERTIFICATES',
                        style: TextStyle(color: _gold, fontSize: 10,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(widget.eventTitle, style: const TextStyle(
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w900)),
                    if (widget.eventDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(widget.eventDate, style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                    ],
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(padding: EdgeInsets.all(45),
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Column(children: [
                Icon(Icons.cloud_off_rounded,
                    color: c.onSurfaceVariant, size: 42),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 13),
                FilledButton.icon(onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry')),
              ])
            else if (_ambiguousCertificate)
                _ambiguousCard()
              else
                _statusCard(_selected),
            const SizedBox(height: 18),
            Text('Certificate availability is verified from your account’s '
                'Laravel records. Only Issued certificates may be viewed '
                'or exported as official PDFs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LaravelCertificatePdfPreview extends StatelessWidget {
  final Uint8List bytes;
  final String filename;

  const _LaravelCertificatePdfPreview({
    required this.bytes,
    required this.filename,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(filename)),
      body: PdfPreview(
        build: (format) async => bytes,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
      ),
    );
  }
}

