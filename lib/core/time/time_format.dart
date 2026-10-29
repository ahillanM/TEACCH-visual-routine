/// Plain-language time formatting shared by both UIs.
///
/// Kept dependency-free (no `intl`) and English-only per CLAUDE.md.
abstract final class TimeFormat {
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// "09:05"
  static String hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// "09:00 – 11:00"
  static String range(DateTime start, DateTime? end) =>
      end == null ? hm(start) : '${hm(start)} – ${hm(end)}';

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  static String shortWeekday(DateTime d) => weekday(d).substring(0, 3);

  /// "Thursday, 29 October"
  static String longDate(DateTime d) =>
      '${weekday(d)}, ${d.day} ${_months[d.month - 1]}';

  /// Calm, rounded description of time left. Never counts seconds.
  ///
  /// "About 20 min left", "About 1 hour left", "Finishing soon".
  static String calmRemaining(Duration left) {
    final minutes = left.inMinutes;
    if (minutes < 5) return 'Finishing soon';
    if (minutes < 55) {
      final rounded = (minutes / 5).round() * 5;
      return 'About $rounded min left';
    }
    final hours = (minutes / 60).round();
    return hours == 1 ? 'About 1 hour left' : 'About $hours hours left';
  }

  /// "1 h 30 min", "45 min"
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Monday of the week containing [d].
  static DateTime startOfWeek(DateTime d) =>
      dateOnly(d).subtract(Duration(days: d.weekday - 1));

  static DateTime atMinuteOfDay(DateTime day, int minuteOfDay) =>
      DateTime(day.year, day.month, day.day, minuteOfDay ~/ 60, minuteOfDay % 60);
}
