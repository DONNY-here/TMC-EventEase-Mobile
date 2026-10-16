part of 'main.dart';

// TMC EventEase: student-only attendance / fine details.
// Requires GET /api/my/attendance-fines/general-assembly in Laravel.
// No fine is invented when the endpoint is missing or unavailable.
class GeneralAssemblyFinePage extends StatefulWidget {
  const GeneralAssemblyFinePage({super.key});

  @override
  State<GeneralAssemblyFinePage> createState() =>
      _GeneralAssemblyFinePageState();
}

class _GeneralAssemblyFinePageState extends State<GeneralAssemblyFinePage> {
  static const _maroon = Color(0xFF711B38);
  static const _endpoint = '/api/my/attendance-fines/general-assembly';
  bool loading = true;
  String? error;
  Map<String, dynamic>? record;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!ApiConfig.useRealApi) {
        throw Exception('Official fine records require Real API Mode.');
      }
      final token = await authTokenStorage.readValidToken();
      if (token == null) {
        throw Exception('Session expired. Please sign in again.');
      }
      final base = Uri.tryParse(ApiConfig.baseUrl.trim());
      if (base == null ||
          !['https', 'http'].contains(base.scheme) ||
          base.host.isEmpty) {
        throw Exception('EventEase server address is not configured.');
      }
      final uri = base.replace(path: _endpoint, query: null, fragment: null);
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        throw Exception(
          'The General Assembly fine service is not yet available on the web server.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'You are not authorized to view this attendance record.',
        );
      }
      if (response.statusCode != 200) {
        throw Exception(
          'Server could not load details (HTTP ${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(response.body);
      final payload = decoded is Map ? (decoded['data'] ?? decoded) : null;
      if (payload is! Map) {
        throw const FormatException('Unexpected response format.');
      }
      final item = Map<String, dynamic>.from(payload);
      if (item['event'] is! Map ||
          item['attendance'] is! Map ||
          item['fine'] is! Map) {
        throw const FormatException('Attendance and fine data is incomplete.');
      }
      if (mounted) {
        setState(() {
          record = item;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('FormatException: ', '');
          loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _string(Object? value, [String fallback = 'Not available']) =>
      value == null || value.toString().trim().isEmpty
      ? fallback
      : value.toString();

  double _amount(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  String _money(Object? value) => '₱${_amount(value).toStringAsFixed(2)}';

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _maroon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _scan(String label, Object? value) {
    final present = value != null && value.toString().trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            present ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: present ? const Color(0xFF168566) : const Color(0xFFC04D4D),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: Text(
              present ? value.toString() : 'Not recorded',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, Object? value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Text(
              _money(value),
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                color: bold ? _maroon : null,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final event = _map(record?['event']);
    final attendance = _map(record?['attendance']);
    final fine = _map(record?['fine']);
    final status = _string(attendance['status']);
    final paymentStatus = _string(fine['payment_status'], 'Not assessed');
    final assessment = _string(fine['assessment_status'], 'Not assessed');
    final balance = _amount(fine['balance']);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Attendance & Fine Details'),
        backgroundColor: _maroon,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: _maroon,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Attendance details unavailable',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [_maroon, Color(0xFF9C3657)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TMC EVENTEASE  •  COMPULSORY EVENT',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1,
                            color: Color(0xFFFFDEEA),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _string(event['title'], 'General Assembly'),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Attendance: $status',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fine Assessment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _money(fine['balance']),
                          style: const TextStyle(
                            color: _maroon,
                            fontSize: 33,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Assessment: $assessment  •  Payment: $paymentStatus',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (assessment.toLowerCase() == 'pending' ||
                            assessment.toLowerCase() == 'on_hold')
                          const Padding(
                            padding: EdgeInsets.only(top: 9),
                            child: Text(
                              'Assessment is under review. No payment is requested yet.',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Event Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _infoRow(
                          Icons.calendar_month,
                          'Date',
                          _string(event['date']),
                        ),
                        _infoRow(
                          Icons.schedule,
                          'Schedule',
                          _string(event['time']),
                        ),
                        _infoRow(
                          Icons.place_outlined,
                          'Venue',
                          _string(event['venue']),
                        ),
                        _infoRow(
                          Icons.groups_outlined,
                          'Required participants',
                          _string(event['required_participants']),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attendance Verification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _scan('Time In', attendance['time_in']),
                        const Divider(),
                        _scan('Time Out', attendance['time_out']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fine Breakdown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _amountRow('Approved fine', fine['amount']),
                        _amountRow('Payments received', fine['paid_amount']),
                        _amountRow(
                          'Waivers / credits',
                          fine['adjustment_amount'],
                        ),
                        const Divider(),
                        _amountRow('Remaining balance', balance, bold: true),
                        if (fine['reason'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Reason: ${fine['reason']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Request an attendance review'),
                        content: const Text(
                          'Appeal submission must be enabled by the Laravel server. Contact the authorized event officer for a correction until the endpoint is implemented.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Request Attendance Review'),
                  ),
                  if (balance > 0 && assessment.toLowerCase() == 'approved')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Payment Information'),
                            content: const Text(
                              'Please contact the authorized TMC collection officer. In-app payment is not yet enabled.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('Payment Information'),
                        style: FilledButton.styleFrom(backgroundColor: _maroon),
                      ),
                    ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
    );
  }
}
