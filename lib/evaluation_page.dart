part of 'main.dart';

// ======================================================
// TMC EVENTEASE - EVENT EVALUATION
// LIGHT AND DARK MODE SUPPORTED
// ======================================================

class EvaluationPage extends StatefulWidget {
  final Event event;

  const EvaluationPage({super.key, required this.event});

  @override
  State<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  int rating = 0;

  final TextEditingController commentController = TextEditingController();

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

  // ====================================================
  // LOAD PREVIOUS EVALUATION
  // ====================================================

  @override
  void initState() {
    super.initState();

    final key = eventKey(widget.event);

    rating = eventRatings[key] ?? 0;
    commentController.text = eventComments[key] ?? '';
  }

  // ====================================================
  // SUBMIT / UPDATE EVALUATION
  // ORIGINAL SAVE LOGIC PRESERVED
  // ====================================================

  void submitEvaluation() {
    if (rating == 0) {
      showMessage(context, 'Please select a rating.');
      return;
    }

    final key = eventKey(widget.event);

    eventRatings[key] = rating;
    eventComments[key] = commentController.text.trim();

    Navigator.pop(context);
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
                  widget.event.title,
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
                  '${widget.event.date} • '
                  '${widget.event.venue}',
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 0,
            children: List.generate(5, (index) {
              final star = index + 1;
              final selected = star <= rating;

              return Tooltip(
                message: '$star out of 5 stars',
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      rating = star;
                    });
                  },
                  child: AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 170),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        selected
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 42,
                        color: selected ? yellow : _secondaryText,
                      ),
                    ),
                  ),
                ),
              );
            }),
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
                rating == 0 ? 'No rating selected' : '$rating out of 5',
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
  // MAIN EVALUATION PAGE
  // ====================================================

  @override
  Widget build(BuildContext context) {
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
              constraints: const BoxConstraints(maxWidth: 650),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _eventInformation(),

                  const SizedBox(height: 23),

                  _ratingCard(),

                  const SizedBox(height: 25),

                  _commentSection(),

                  const SizedBox(height: 25),

                  // ==================================
                  // SUBMIT EVALUATION
                  // ==================================
                  SizedBox(
                    width: double.infinity,
                    height: 56,

                    child: FilledButton.icon(
                      onPressed: submitEvaluation,

                      style: FilledButton.styleFrom(
                        backgroundColor: yellow,
                        foregroundColor: navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),

                      icon: const Icon(Icons.send_rounded, size: 20),

                      label: const Text(
                        'Submit Evaluation',
                        style: TextStyle(
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
