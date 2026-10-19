// lib/helpers/event_eligibility.dart
// Local preview for demo mode. Laravel must always validate live registrations.
class EligibilityResult {
  final bool eligible;
  final List<String> reasons;
  const EligibilityResult(this.eligible, this.reasons);
}

class EventEligibility {
  static String normalizeCourse(Object? value) => (value ?? '')
      .toString()
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), '');

  // Accepts 3, "3", "3rd", "3rd Year" without changing the saved profile.
  static int? normalizeYear(Object? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^\s*([1-4])(?:st|nd|rd|th)?(?:\s+Year)?\s*$',
      caseSensitive: false,
    ).firstMatch(value.toString());
    return match == null ? null : int.parse(match.group(1)!);
  }

  // Accepts 3, "3", or "Block 3"; returns an integer for comparison.
  static int? normalizeBlock(Object? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^\s*(?:Block\s*)?(\d{1,2})\s*$',
      caseSensitive: false,
    ).firstMatch(value.toString());
    return match == null ? null : int.parse(match.group(1)!);
  }

  static EligibilityResult check({
    required Object? studentCourse,
    required Object? studentYear,
    required Object? studentBlock,
    required Iterable<Object?> allowedCourses,
    required Iterable<Object?> allowedYears,
    required Iterable<Object?> allowedBlocks,
    required bool registrationOpen,
    required int? capacity,
    required int currentParticipants,
    DateTime? deadline,
    DateTime? now,
  }) {
    final reasons = <String>[];
    final today = now ?? DateTime.now();

    if (!registrationOpen) reasons.add('Registration is closed.');
    if (deadline != null && today.isAfter(deadline)) {
      reasons.add('Registration deadline has passed.');
    }
    if (capacity != null && capacity > 0 && currentParticipants >= capacity) {
      reasons.add('The event is full.');
    }

    final courses = allowedCourses
        .map(normalizeCourse)
        .where((v) => v.isNotEmpty)
        .toSet();
    if (courses.isNotEmpty &&
        !courses.contains(normalizeCourse(studentCourse))) {
      reasons.add('Your course is not included in this event.');
    }

    final years = allowedYears.map(normalizeYear).whereType<int>().toSet();
    if (allowedYears.isNotEmpty && years.isEmpty) {
      reasons.add('Event year restrictions are invalid.');
    } else if (years.isNotEmpty &&
        !years.contains(normalizeYear(studentYear))) {
      reasons.add('Your year level is not eligible.');
    }

    final blocks = allowedBlocks.map(normalizeBlock).whereType<int>().toSet();
    if (allowedBlocks.isNotEmpty && blocks.isEmpty) {
      reasons.add('Event block restrictions are invalid.');
    } else if (blocks.isNotEmpty &&
        !blocks.contains(normalizeBlock(studentBlock))) {
      reasons.add('Your block is not eligible.');
    }

    return EligibilityResult(reasons.isEmpty, List.unmodifiable(reasons));
  }
}
