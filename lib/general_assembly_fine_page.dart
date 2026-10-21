part of 'main.dart';

// TMC EventEase - Registered Event Attendance & Fines.
// This page replaces the old General Assembly-only UI.
// It displays ONLY Laravel fine records whose event references also occur in
// the signed-in student's GET /api/registrations/my results.
// A fine's existence and monetary amounts must always come from Laravel.
class RegisteredEventFinesPage extends StatefulWidget {
  const RegisteredEventFinesPage({super.key});

  @override
  State<RegisteredEventFinesPage> createState() =>
      _RegisteredEventFinesPageState();
}

// Compatibility with existing navigation while the dashboard is updated.
// The class name is kept so older references in main.dart still compile.
class GeneralAssemblyFinePage extends RegisteredEventFinesPage {
  const GeneralAssemblyFinePage({super.key});
}

class _RegisteredEventFinesPageState extends State<RegisteredEventFinesPage> {
  static const _maroon = Color(0xFF711B38);
  static const _navy = Color(0xFF102A4C);

  bool _loading = true;
  String? _error;
  String? _paymentError;
  String? _attendanceError;
  List<Map<String, dynamic>> _registrations = [];
  List<Map<String, dynamic>> _matchedFines = [];
  List<Map<String, dynamic>> _obligations = [];
  List<Map<String, dynamic>> _paymentOptions = [];
  int _requestVersion = 0;
  int _unmatchedFineCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _text(Object? value, [String fallback = '']) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  num? _number(Object? value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(_text(value));
  }

  String _money(Object? value) {
    final amount = _number(value);
    return amount == null
        ? 'Not yet assessed'
        : '₱${amount.toStringAsFixed(2)}';
  }

  String _friendlyError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '')
      .replaceFirst('FormatException: ', '');

  Uri _uri(String path, {int? page}) {
    final base = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw StateError('A secure HTTPS API address is required.');
    }
    return base.replace(
      path: path,
      queryParameters: page == null ? null : {'page': '$page'},
      fragment: null,
    );
  }

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': 'true',
  };

  Future<Object?> _getJson(String path, String token, {int? page}) async {
    final response = await http
        .get(_uri(path, page: page), headers: _headers(token))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      throw StateError('Your session has expired. Please sign in again.');
    }
    if (response.statusCode == 403) {
      throw StateError('Your account is not authorized to view these records.');
    }
    if (response.statusCode != 200) {
      throw StateError('eventEase returned HTTP ${response.statusCode}.');
    }
    return jsonDecode(response.body);
  }

  List<Map<String, dynamic>> _rows(Object? json, {String? field}) {
    final Object? records;
    if (json is Map) {
      records = json[field ?? 'data'];
    } else {
      records = json;
    }
    if (records is! List) {
      throw const FormatException(
        'eventEase returned an unexpected list response.',
      );
    }
    return records.map((record) {
      if (record is! Map) {
        throw const FormatException('Invalid record.');
      }
      return Map<String, dynamic>.from(record);
    }).toList();
  }

  // Load every page of a student-owned Laravel collection. Never calculate
  // financial totals from only the first page of a paginated response.
  Future<List<Map<String, dynamic>>> _getAllPages(
    String path,
    String token,
  ) async {
    final all = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final response = await _getJson(path, token, page: page);
      if (response is! Map) {
        throw const FormatException('Unexpected paginated response.');
      }
      all.addAll(_rows(response));
      final pages = int.tryParse('${response['last_page'] ?? 1}');
      if (pages == null || pages < 1 || pages > 50) {
        throw const FormatException('Invalid pagination information.');
      }
      if (page >= pages) break;
      page++;
    }
    return all;
  }

  String _fineEventReference(Map<String, dynamic> fine) {
    final obligation = _map(fine['obligation']);
    final event = _map(obligation['event']);
    return _text(event['reference'] ?? obligation['reference']);
  }

  String _fineEventTitle(Map<String, dynamic> fine) {
    final obligation = _map(fine['obligation']);
    final event = _map(obligation['event']);
    return _text(event['title'] ?? obligation['title'], 'Registered event');
  }

  Map<String, dynamic>? _registrationFor(String eventReference) {
    for (final registration in _registrations) {
      if (_text(registration['event_reference']) == eventReference) {
        return registration;
      }
    }
    return null;
  }

  Map<String, dynamic>? _obligationFor(String eventReference) {
    for (final obligation in _obligations) {
      if (_text(obligation['reference']) == eventReference) {
        return obligation;
      }
    }
    return null;
  }

  Future<void> _refresh() async {
    final version = ++_requestVersion;
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _paymentError = null;
      _attendanceError = null;
      _registrations = [];
      _matchedFines = [];
      _unmatchedFineCount = 0;
      _obligations = [];
      _paymentOptions = [];
    });
    try {
      if (!ApiConfig.useRealApi) {
        throw StateError('Official fines are available only in Real API Mode.');
      }
      final token = await authTokenStorage.readValidToken();
      if (token == null || token.trim().isEmpty) {
        throw StateError('Your session has expired. Please sign in again.');
      }

      // BOTH are mandatory: do not show fines until their event matches a
      // server-confirmed registration for this authenticated student.
      final registrations = await _getAllPages('/api/registrations/my', token);
      if (registrations.any((reg) => _text(reg['event_reference']).isEmpty)) {
        throw const FormatException(
          'A registered event has no event_reference; cannot verify fine ownership.',
        );
      }
      final allFines = await _getAllPages('/api/my/fines', token);
      if (allFines.any((fine) => _fineEventReference(fine).isEmpty)) {
        throw const FormatException(
          'A fine record has no event reference; its registration cannot be verified.',
        );
      }
      final allowedReferences = registrations
          .map((registration) => _text(registration['event_reference']))
          .toSet();
      final matched = allFines.where((fine) {
        final reference = _fineEventReference(fine);
        return reference.isNotEmpty && allowedReferences.contains(reference);
      }).toList();

      List<Map<String, dynamic>> obligations = [];
      List<Map<String, dynamic>> paymentOptions = [];
      String? attendanceError;
      String? paymentError;
      try {
        obligations = _rows(await _getJson('/api/my/attendance', token))
            .where((row) => allowedReferences.contains(_text(row['reference'])))
            .toList();
      } catch (error) {
        attendanceError = _friendlyError(error);
      }
      try {
        paymentOptions = _rows(
          await _getJson('/api/my/fines/payment-options', token),
          field: 'options',
        );
      } catch (error) {
        paymentError = _friendlyError(error);
      }
      if (!mounted || version != _requestVersion) {
        return;
      }
      setState(() {
        _registrations = registrations;
        _matchedFines = matched;
        _unmatchedFineCount = allFines.length - matched.length;
        _obligations = obligations;
        _paymentOptions = paymentOptions;
        _attendanceError = attendanceError;
        _paymentError = paymentError;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );

  Widget _amountRow(String label, Object? amount, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              _money(amount),
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                color: strong ? _maroon : null,
              ),
            ),
          ],
        ),
      );

  Widget _info(String message, {IconData icon = Icons.info_outline_rounded}) =>
      _panel(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: _maroon),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(height: 1.4))),
          ],
        ),
      );

  Widget _header() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(colors: [_navy, _maroon]),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TMC EVENTEASE  •  REGISTERED EVENTS',
          style: TextStyle(
            color: Color(0xFFFFDFE9),
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Event Attendance & Fines',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Only fine records tied to your registered events appear here. '
          'eventEase determines whether a fine applies.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
      ],
    ),
  );

  Widget _summary() {
    final approved = _matchedFines
        .where(
          (fine) =>
              _text(fine['assessment_status']).toLowerCase() == 'approved',
        )
        .toList();
    final amount = approved.fold<double>(
      0,
      (total, fine) => total + (_number(fine['amount'])?.toDouble() ?? 0),
    );
    final paid = approved.fold<double>(
      0,
      (total, fine) => total + (_number(fine['amount_paid'])?.toDouble() ?? 0),
    );
    final balance = approved.fold<double>(
      0,
      (total, fine) =>
          total + (_number(fine['outstanding_balance'])?.toDouble() ?? 0),
    );
    final missingAmounts = approved.any(
      (fine) =>
          _number(fine['amount']) == null ||
          _number(fine['amount_paid']) == null ||
          _number(fine['outstanding_balance']) == null,
    );

    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_matchedFines.length} event fine record(s)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${_registrations.length} registered event record(s)',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 13),
          if (missingAmounts)
            const Text(
              'Some approved amounts are unavailable. '
              'Totals cannot be verified yet.',
            )
          else ...[
            _amountRow('Approved fines', amount),
            _amountRow('Recorded payments', paid),
            const Divider(),
            _amountRow('Outstanding balance', balance, strong: true),
          ],
          const SizedBox(height: 8),
          Text(
            'Amounts are calculated only from eventEase-approved fine records. '
            'Pending assessments are not counted as a payable balance.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fineCard(Map<String, dynamic> fine) {
    final eventRef = _fineEventReference(fine);
    final registration = _registrationFor(eventRef);
    final obligation = _obligationFor(eventRef);
    final assessment = _text(fine['assessment_status'], 'not_assessed');
    final lower = assessment.toLowerCase();
    final moneyAvailable = lower == 'approved' || lower == 'waived';
    final payments = fine['payments'] is List
        ? fine['payments'] as List
        : const [];
    final appealStatus = _text(obligation?['appeal_status']).toLowerCase();
    final eventStatus = _text(obligation?['event_status']).toLowerCase();
    final eventId = int.tryParse(
      _text(registration == null ? null : registration['event_id']),
    );
    final canAppeal =
        obligation != null &&
        eventId != null &&
        eventStatus == 'completed' &&
        appealStatus != 'under_review' &&
        appealStatus != 'excused';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available_outlined, color: _maroon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _fineEventTitle(fine),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Event: $eventRef',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text('Assessment: $assessment')),
                Chip(
                  label: Text(
                    'Payment: ${_text(fine['payment_status'], 'Not assessed')}',
                  ),
                ),
              ],
            ),
            if (obligation != null) ...[
              const SizedBox(height: 7),
              Text(
                'Attendance: ${_text(obligation['attendance_status'], 'Not recorded')}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Verified scans: ${_text(obligation['scans_recorded'], '0')} '
                '/ ${_text(obligation['required_scans'], '0')}',
                style: const TextStyle(fontSize: 12),
              ),
            ] else if (_attendanceError != null) ...[
              const SizedBox(height: 7),
              Text(
                'Attendance details temporarily unavailable.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_text(fine['reason']).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: ${_text(fine['reason'])}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const Divider(height: 22),
            if (moneyAvailable) ...[
              _amountRow('Assessed amount', fine['amount']),
              _amountRow('Payments recorded', fine['amount_paid']),
              _amountRow(
                'Remaining balance',
                fine['outstanding_balance'],
                strong: true,
              ),
            ] else
              const Text(
                'This assessment is not approved for collection. '
                'No payment is requested yet.',
                style: TextStyle(fontSize: 12),
              ),
            if (payments.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Payment history',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              for (final payment in payments)
                if (payment is Map)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${_money(payment['amount'])}  •  '
                      '${_text(payment['method'], 'Recorded payment')}'
                      '${_text(payment['receipt_reference']).isEmpty ? '' : '  •  Receipt: ${_text(payment['receipt_reference'])}'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
            ],
            if (canAppeal) ...[
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: () => _submitAppeal(eventId, _fineEventTitle(fine)),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Request attendance review'),
              ),
            ] else if (appealStatus == 'under_review' ||
                appealStatus == 'excused') ...[
              const SizedBox(height: 6),
              Text(
                'Attendance appeal: ${appealStatus == 'excused' ? 'Approved' : 'Under review'}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _paymentSection() {
    final hasOutstanding = _matchedFines.any(
      (fine) =>
          _text(fine['assessment_status']).toLowerCase() == 'approved' &&
          (_number(fine['outstanding_balance']) ?? 0) > 0,
    );
    if (!hasOutstanding) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        if (_paymentError != null)
          _info(
            'Could not load payment channels: $_paymentError',
            icon: Icons.cloud_off_outlined,
          )
        else if (_paymentOptions.isEmpty)
          _info(
            'No payment channels are currently published. '
            'Contact an authorized TMC collection officer.',
          )
        else
          for (final option in _paymentOptions) ...[
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text(
                      option['name'] ??
                          option['label'] ??
                          option['method'] ??
                          option['channel'],
                      'Payment channel',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (_text(
                    option['instructions'] ??
                        option['description'] ??
                        option['details'],
                  ).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _text(
                        option['instructions'] ??
                            option['description'] ??
                            option['details'],
                      ),
                    ),
                  ],
                  if (_text(option['account_name']).isNotEmpty)
                    Text('Account: ${_text(option['account_name'])}'),
                  if (_text(option['account_number']).isNotEmpty)
                    Text('Number: ${_text(option['account_number'])}'),
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
        const SizedBox(height: 7),
        Text(
          'Payments and adjustments are recorded by authorized TMC personnel. '
          'This screen does not collect payments.',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _submitAppeal(int eventId, String eventTitle) async {
    if (eventId <= 0) {
      return;
    }
    final controller = TextEditingController();
    var sending = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            title: const Text('Request Attendance Review'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Event: $eventTitle'),
                  const SizedBox(height: 8),
                  const Text(
                    'Give your attendance correction or excuse. '
                    'An administrator reviews submitted appeals.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      hintText: 'Reason (at least 10 characters)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        final reason = controller.text.trim();
                        if (reason.length < 10) {
                          _notice('Please provide at least 10 characters.');
                          return;
                        }
                        updateDialog(() => sending = true);
                        try {
                          final token = await authTokenStorage.readValidToken();
                          if (token == null || token.trim().isEmpty) {
                            throw StateError(
                              'Your session has expired. Sign in again.',
                            );
                          }
                          final response = await http
                              .post(
                                _uri('/api/my/attendance/$eventId/appeals'),
                                headers: {
                                  ..._headers(token),
                                  'Content-Type': 'application/json',
                                },
                                body: jsonEncode({'reason': reason}),
                              )
                              .timeout(const Duration(seconds: 20));
                          if (response.statusCode != 201) {
                            var message =
                                'eventEase returned HTTP ${response.statusCode}.';
                            try {
                              final result = jsonDecode(response.body);
                              if (result is Map) {
                                final fromServer = _text(result['message']);
                                if (fromServer.isNotEmpty) {
                                  message = fromServer;
                                }
                              }
                            } catch (_) {
                              // Keep the HTTP message if Laravel returns non-JSON.
                            }
                            throw StateError(message);
                          }
                          if (!mounted || !dialogContext.mounted) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          _notice(
                            'Your attendance appeal was submitted for review.',
                          );
                          await _refresh();
                        } catch (error) {
                          _notice(_friendlyError(error));
                          if (dialogContext.mounted) {
                            updateDialog(() => sending = false);
                          }
                        }
                      },
                child: Text(sending ? 'Submitting...' : 'Submit Appeal'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _notice(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Event Attendance & Fines'),
        backgroundColor: _maroon,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh official fine records',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _header(),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null) ...[
              _info(
                'Could not load your registered event fines. $_error',
                icon: Icons.cloud_off_rounded,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ] else ...[
              _summary(),
              const SizedBox(height: 13),
              if (_unmatchedFineCount > 0) ...[
                _info(
                  '$_unmatchedFineCount fine record(s) returned are not linked '
                  'to your current registrations and are hidden from this page. '
                  'Contact the Web Admin to review whether those assessments should exist.',
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 20),
              const Text(
                'Events with Fine Records',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (_matchedFines.isEmpty)
                _info(
                  'No fine records apply to your currently registered events. '
                  'Only eventEase-assessed fines will appear here.',
                )
              else
                for (final fine in _matchedFines) _fineCard(fine),
              const SizedBox(height: 20),
              _paymentSection(),
            ],
          ],
        ),
      ),
    );
  }
}
