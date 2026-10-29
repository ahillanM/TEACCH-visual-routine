import 'package:flutter/foundation.dart';

/// Which activities a participant has marked as done.
///
/// Local in the prototype; the Supabase implementation persists through the
/// `complete_activity` RPC (the only way completion can change server-side).
class ProgressStore extends ChangeNotifier {
  final Set<String> _done = {};

  static String _key(String eventId, String participantId) =>
      '$participantId/$eventId';

  bool isDone(String eventId, String participantId) =>
      _done.contains(_key(eventId, participantId));

  Future<void> setDone(String eventId, String participantId, bool done) async {
    final changed = done
        ? _done.add(_key(eventId, participantId))
        : _done.remove(_key(eventId, participantId));
    if (changed) notifyListeners();
  }

  /// Replaces all completion state, e.g. with the server state.
  void replaceAll(Iterable<(String eventId, String participantId)> done) {
    _done
      ..clear()
      ..addAll([for (final (e, p) in done) _key(e, p)]);
    notifyListeners();
  }
}
