import 'activity_category.dart';
import 'visual_ref.dart';

/// A reusable place from the organisational library (e.g. "Workshop A").
class Place {
  final String id;
  final String name;
  final String participantDescription;
  final VisualRef visual;

  const Place({
    required this.id,
    required this.name,
    required this.participantDescription,
    required this.visual,
  });
}

/// A reusable contact card for a professional (fictional names only).
class Contact {
  final String id;
  final String name;
  final String roleLabel;
  final VisualRef visual;

  const Contact({
    required this.id,
    required this.name,
    required this.roleLabel,
    required this.visual,
  });
}

/// A reusable activity definition. Selecting one in the activity editor
/// pre-fills title, visuals, place, person and participant-facing text, so
/// staff never upload the same assets twice.
class LibraryActivity {
  final String id;
  final String name;
  final ActivityCategory category;
  final VisualRef visual;
  final String participantDescription;
  final String? defaultPlaceId;
  final String? defaultContactId;
  final List<String> whatToBring;
  final String? instructions;
  final int defaultDurationMin;

  const LibraryActivity({
    required this.id,
    required this.name,
    required this.category,
    required this.visual,
    this.participantDescription = '',
    this.defaultPlaceId,
    this.defaultContactId,
    this.whatToBring = const [],
    this.instructions,
    this.defaultDurationMin = 60,
  });
}
