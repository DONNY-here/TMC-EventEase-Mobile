part of 'main.dart';

// ======================================================
// TMC EVENTEASE - EVENT EVALUATION
// LIGHT AND DARK MODE SUPPORTED
// ======================================================

class EvaluationPage extends StatefulWidget {
  // Existing demo/EventDetails callers remain unchanged.
  final Event? event;
  // Real API callers pass the actual student registration from Laravel.
  // This avoids guessing the server's event_reference from a display title.
  final Map<String, dynamic>? laravelRegistration;

  const EvaluationPage({super.key, required this.event})
      : laravelRegistration = null;

  const EvaluationPage.forLaravelRegistration({
    super.key,
    required this.laravelRegistration,
  }) : event = null;

  @override
  State<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  int rating = 0;
  final TextEditingController commentController = TextEditingController();

  // Live mode never uses Demo Mode attendance or locally created evaluations.
  bool get _realApiMode => ApiConfig.useRealApi;
  bool _loadingPrevious = false;
  bool _submitting = false;
  bool _hasSubmittedBefore = false;
  String? _loadError;
  String? _submitError;
  String? _previousSubmissionDate;

  String _registrationField(String field, [String fallback = '']) {
    final value = widget.laravelRegistration?[field];
    return value == null ? fallback : value.toString().trim();
  }

  String get _eventReference => _registrationField('event_reference');

  // A cancelled registration must not be offered an evaluation in the UI.
  // Laravel still performs the authoritative eligibility check on submit.
  bool get _isCancelledRegistration {
    final status = _registrationField(
      'registration_status',
      _registrationField('status'),
    ).toLowerCase();
    return status == 'cancelled' || status == 'canceled';
  }

  String get _eventTitle => _realApiMode
      ? _registrationField('event_title', widget.event?.title ?? 'Campus event')
      : (widget.event?.title ?? 'Campus event');
  String get _eventDate => _realApiMode
      ? _registrationField('event_date', 'Event date unavailable')
      : (widget.event?.date ?? 'Date unavailable');
  String get _eventVenue => _realApiMode
      ? _registrationField('venue', 'Venue not announced')
      : (widget.event?.venue ?? 'Venue not announced');

  Uri _endpoint(String path, {Map<String, String>? query}) {
    final base = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw StateError('The secure Laravel API URL is not configured.');
    }
    return base.replace(path: path, queryParameters: query, fragment: null);
  }

  Future<String> _studentToken() async {
    final token = await authTokenStorage.readValidToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Your login has expired. Please sign in again.');
    }
    return token;
  }

  String _responseError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
          if (first is String && first.isNotEmpty) return first;
        }
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } catch (_) {}
    return switch (response.statusCode) {
      401 => 'Your login has expired. Please sign in again.',
      403 => 'The student account is not authorized to use evaluations.',
      404 => 'The Laravel evaluation endpoint was not found.',
      422 => 'Laravel did not approve this evaluation. Check registration and Time In.',
      _ => 'Laravel returned HTTP ${response.statusCode}.',
    };
  }

  // GET /api/my/evaluations: loads ONLY evaluations belonging to this student.
  // Supports Laravel's normal pagination and an unpaginated JSON list.
  Future<void> _loadPreviousEvaluation() async {
    if (!_realApiMode || _eventReference.isEmpty) return;
    if (mounted) {
      setState(() {
        _loadingPrevious = true;
        _loadError = null;
      });
    }
    try {
      final token = await _studentToken();
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      };
      Map<String, dynamic>? previous;
      var page = 1;
      var lastPage = 1;
      do {
        final response = await http.get(
          _endpoint('/api/my/evaluations', query: {'page': '$page'}),
          headers: headers,
        ).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw StateError(_responseError(response));
        }
        final decoded = jsonDecode(response.body);
        late final List<dynamic> rows;
        if (decoded is List) {
          rows = decoded;
          lastPage = 1;
        } else if (decoded is Map && decoded['data'] is List) {
          rows = decoded['data'] as List;
          lastPage = int.tryParse('${decoded['last_page'] ?? 1}') ?? 1;
        } else {
          throw const FormatException('Unexpected evaluation history format.');
        }
        if (lastPage > 50) {
          throw const FormatException('Evaluation history has too many pages.');
        }
        for (final row in rows) {
          if (row is! Map) {
            throw const FormatException('Invalid evaluation record.');
          }
          final record = Map<String, dynamic>.from(row);
          if (!record.containsKey('event_reference')) {
            throw const FormatException('Evaluation record missing event_reference.');
          }
          if ('${record['event_reference'] ?? ''}'.trim() == _eventReference) {
            previous = record;
            break;
          }
        }
        if (previous != null) break;
        page++;
      } while (page <= lastPage);
      if (!mounted) return;
      final existing = previous;
      if (existing != null) {
        final priorRating = int.tryParse('${existing['rating'] ?? ''}') ?? 0;
        if (priorRating < 1 || priorRating > 5) {
          throw const FormatException('Invalid rating returned by Laravel.');
        }
        setState(() {
          _submitError = null;
          rating = priorRating;
          commentController.text = '${existing['comment'] ?? ''}';
          _hasSubmittedBefore = true;
          _previousSubmissionDate =
              '${existing['submission_date'] ?? existing['submitted_at'] ?? existing['date'] ?? ''}'.trim();
        });
      } else {
        setState(() {
          _hasSubmittedBefore = false;
          _previousSubmissionDate = null;
          rating = 0;
          commentController.clear();
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is StateError
            ? error.message.toString()
            : error is FormatException
            ? error.message
            : 'Could not load your evaluations. Check Laravel and your connection.';
      });
    } finally {
      if (mounted) setState(() => _loadingPrevious = false);
    }
  }

  Future<void> _submitLiveEvaluation() async {
    if (_submitting || _loadingPrevious || _loadError != null) return;
    if (_isCancelledRegistration) {
      showMessage(context, 'Cancelled registrations cannot be evaluated.');
      return;
    }
    if (_eventReference.isEmpty) {
      showMessage(context, 'This registration is missing its Laravel event reference.');
      return;
    }
    if (rating < 1 || rating > 5) {
      showMessage(context, 'Please select a rating from 1 to 5 stars.');
      return;
    }
    if (commentController.text.trim().length > 300) {
      showMessage(context, 'Feedback must not exceed 300 characters.');
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final token = await _studentToken();
      final response = await http.post(
        _endpoint('/api/evaluations/submit'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'event_reference': _eventReference,
          'rating': rating,
          'comment': commentController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw StateError(_responseError(response));
      }
      // Only a successful Laravel response is evidence of a stored evaluation.
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Evaluation saved'),
          content: Text(_hasSubmittedBefore
              ? 'Laravel confirmed your updated evaluation.'
              : 'Laravel confirmed your evaluation was submitted.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = error is StateError
            ? error.message.toString()
            : 'The submission could not be confirmed. Check My Evaluations '
            'before trying again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _ratingDescription => switch (rating) {
    1 => 'Very dissatisfied',
    2 => 'Dissatisfied',
    3 => 'Neutral',
    4 => 'Satisfied',
    5 => 'Very satisfied',
    _ => 'Select a rating',
  };

  // ====================================================
  // THEME COLORS
  // ====================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageBackground =>
      _isDark ? const Color(0xFF101B2D) : const Color(0xFFF5F8FC);

  Color get _cardBackground => _isDark ? const Color(0xFF19283D) : Colors.white;

  Color get _inputBackground =>
      _isDark ? const Color(0xFF25364D) : const Color(0xFFF6F8FC);

  Color get _primaryText =>
      _isDark ? const Color(0xFFF0F5FF) : const Color(0xFF17283E);

  Color get _secondaryText =>
      _isDark ? const Color(0xFFB7C5D8) : const Color(0xFF69798C);

  Color get _outline =>
      _isDark ? const Color(0xFF344861) : const Color(0xFFE1E8F2);

  Color get _accent => _isDark ? yellow : navy;

  // Demo Mode alone uses local registration and attendance state.
  // Laravel is the authority on check-in eligibility in Real API Mode.
  bool get _canEvaluate {
    if (_realApiMode || widget.event == null) return false;
    final event = widget.event!;
    final key = eventKey(event);
    final isRegistered = registeredEvents.any(
          (registered) => eventKey(registered) == key,
    );
    return isRegistered && attendanceStatus[key] == 'Present';
  }

  // ====================================================
  // LOAD PREVIOUS EVALUATION
  // ====================================================

  @override
  void initState() {
    super.initState();

    if (_realApiMode) {
      // The live entry point must supply a verified Laravel registration.
      if (widget.laravelRegistration != null && _eventReference.isNotEmpty) {
        _loadingPrevious = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadPreviousEvaluation();
        });
      }
    } else if (widget.event != null) {
      final key = eventKey(widget.event!);
      rating = eventRatings[key] ?? 0;
      commentController.text = eventComments[key] ?? '';
    }
  }

  // ====================================================
  // SUBMIT / UPDATE EVALUATION
  // ORIGINAL SAVE LOGIC PRESERVED
  // ====================================================

  Future<void> submitEvaluation() async {
    if (_realApiMode) {
      await _submitLiveEvaluation();
      return;
    }
    // Check again at submission time in local Demo Mode.
    if (!_canEvaluate) {
      showMessage(
        context,
        'Registration and recorded attendance are required '
            'before submitting an evaluation.',
      );
      return;
    }

    if (rating < 1 || rating > 5) {
      showMessage(context, 'Please select a rating from 1 to 5 stars.');
      return;
    }

    if (commentController.text.trim().length > 300) {
      showMessage(context, 'Feedback must not exceed 300 characters.');
      return;
    }

    final key = eventKey(widget.event!);
    eventRatings[key] = rating;
    eventComments[key] = commentController.text.trim();

    refreshNotifications();
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  // ====================================================
  // REUSABLE CARD DECORATION
  // ====================================================

  BoxDecoration _cardDecoration({double radius = 20}) {
    return BoxDecoration(
      color: _cardBackground,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _outline),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _isDark ? 0.14 : 0.04),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  // ====================================================
  // EVENT INFORMATION
  // ====================================================

  Widget _eventInformation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.event_rounded, color: yellow, size: 28),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventTitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '$_eventDate • $_eventVenue',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 12,
                    height: 1.4,
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
  // STAR RATING CARD
  // ====================================================

  Widget _ratingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 22),
      decoration: _cardDecoration(radius: 22),
      child: Column(
        children: [
          Icon(Icons.rate_review_rounded, color: _accent, size: 32),

          const SizedBox(height: 12),

          Text(
            'How was the event?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primaryText,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Tap a star to rate your experience.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryText, fontSize: 13),
          ),

          const SizedBox(height: 22),

          // ==========================================
          // INTERACTIVE STAR RATING
          // ==========================================
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 305;
              final starSize = compact ? 35.0 : 42.0;
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: compact ? 0 : 3,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  final selected = star <= rating;
                  final disabled = _submitting ||
                      (_realApiMode && (_loadingPrevious || _loadError != null));
                  return Semantics(
                    button: true,
                    enabled: !disabled,
                    selected: rating == star,
                    label: '$star out of 5 stars',
                    child: Tooltip(
                      message: '$star out of 5 stars',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: disabled ? null : () {
                          setState(() {
                            rating = star;
                            _submitError = null;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: AnimatedScale(
                            scale: selected ? 1.08 : 1,
                            duration: const Duration(milliseconds: 170),
                            child: Icon(
                              selected
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: starSize,
                              color: selected ? yellow : _secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),

          const SizedBox(height: 15),

          // ==========================================
          // SELECTED RATING INDICATOR
          // ==========================================
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(rating),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              decoration: BoxDecoration(
                color: _isDark
                    ? const Color(0xFF293F60)
                    : const Color(0xFFEAF2FB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                rating == 0 ? 'No rating selected' : '$rating out of 5 · $_ratingDescription',
                style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // COMMENT / SUGGESTION FIELD
  // ====================================================

  Widget _commentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comment / Suggestion',
          style: TextStyle(
            color: _primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          'Share your feedback about the event.',
          style: TextStyle(color: _secondaryText, fontSize: 12.5),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: commentController,
          enabled: !_submitting &&
              (!_realApiMode || (!_loadingPrevious && _loadError == null)),
          maxLines: 5,
          maxLength: 300,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,

          style: TextStyle(color: _primaryText, fontSize: 14, height: 1.5),

          cursorColor: _accent,

          decoration: InputDecoration(
            hintText: 'Write your feedback here...',
            hintStyle: TextStyle(color: _secondaryText, fontSize: 13.5),

            filled: true,
            fillColor: _inputBackground,

            contentPadding: const EdgeInsets.all(17),

            counterStyle: TextStyle(color: _secondaryText, fontSize: 11),

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: _outline),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: _accent, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  // ====================================================
  // LOCKED SCREEN WHEN EVALUATION IS NOT ALLOWED
  // ====================================================

  Widget _lockedScreen() {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text('Event Evaluation'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(24),
            decoration: _cardDecoration(radius: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 54, color: _accent),
                const SizedBox(height: 14),
                Text(
                  'Evaluation Locked',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ApiConfig.useRealApi
                      ? (_isCancelledRegistration
                      ? 'This registration has been cancelled. Only active, '
                      'eligible registrations can be evaluated.'
                      : 'Open an eligible registration from My Passes to evaluate '
                      'it using Laravel. A valid event reference is required.')
                      : 'Register for this event and have your QR attendance '
                      'recorded as Present before completing the evaluation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _secondaryText, height: 1.45),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Real API feedback is distinct from Demo Mode evaluation state.
  Widget _liveStatusCard() {
    final blocked = _loadError != null;
    final info = _loadingPrevious
        ? 'Checking your previous evaluations in Laravel...'
        : blocked
        ? _loadError!
        : _hasSubmittedBefore
        ? 'Your previous evaluation was loaded from Laravel. '
        'You can change the rating or comment and save again.'
        : 'Laravel will confirm your registration and Time In before '
        'accepting this evaluation.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(blocked ? Icons.error_outline_rounded
              : _hasSubmittedBefore ? Icons.edit_note_rounded
              : Icons.verified_user_outlined,
              color: _accent, size: 23),
          const SizedBox(width: 9),
          Expanded(child: Text(
            _hasSubmittedBefore ? 'Edit your Laravel evaluation'
                : 'Laravel evaluation',
            style: TextStyle(color: _primaryText,
                fontWeight: FontWeight.w800),
          )),
        ]),
        const SizedBox(height: 7),
        Text(info, style: TextStyle(color: _secondaryText, height: 1.45)),
        if (_loadingPrevious) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_previousSubmissionDate != null &&
            _previousSubmissionDate!.isNotEmpty && !_loadingPrevious) ...[
          const SizedBox(height: 7),
          Text('Last submitted: $_previousSubmissionDate',
              style: TextStyle(color: _secondaryText, fontSize: 11)),
        ],
        if (blocked) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadingPrevious ? null : _loadPreviousEvaluation,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry loading evaluations'),
          ),
        ],
      ]),
    );
  }

  // ====================================================
  // MAIN EVALUATION PAGE
  // ====================================================

  @override
  Widget build(BuildContext context) {
    if (_realApiMode) {
      if (widget.laravelRegistration == null ||
          _eventReference.isEmpty ||
          _isCancelledRegistration) {
        return _lockedScreen();
      }
    } else if (!_canEvaluate) {
      return _lockedScreen();
    }
    return Scaffold(
      backgroundColor: _pageBackground,

      appBar: AppBar(
        title: const Text('Event Evaluation'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 35),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _eventInformation(),

                  if (_realApiMode) ...[
                    const SizedBox(height: 16),
                    _liveStatusCard(),
                  ],

                  const SizedBox(height: 23),

                  _ratingCard(),

                  const SizedBox(height: 25),

                  _commentSection(),

                  const SizedBox(height: 25),

                  // ==================================
                  // SUBMIT EVALUATION
                  // ==================================
                  if (_submitError != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_submitError!,
                          style: TextStyle(color: Theme.of(context)
                              .colorScheme.error, height: 1.4)),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,

                    child: FilledButton.icon(
                      onPressed: _submitting ||
                          (_realApiMode && (_loadingPrevious || _loadError != null))
                          ? null : submitEvaluation,

                      style: FilledButton.styleFrom(
                        backgroundColor: yellow,
                        foregroundColor: navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),

                      icon: _submitting
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 20),

                      label: Text(
                        _submitting ? 'Saving to Laravel...'
                            : _realApiMode && _hasSubmittedBefore
                            ? 'Save Evaluation Changes'
                            : 'Submit Evaluation',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

