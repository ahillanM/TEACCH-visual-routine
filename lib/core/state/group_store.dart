import 'package:flutter/foundation.dart';

import '../models/participant_group.dart';

/// Participant groups made by staff. Kept locally (not yet synced).
class GroupStore extends ChangeNotifier {
  final List<ParticipantGroup> _groups;
  int _counter = 0;

  GroupStore([Iterable<ParticipantGroup> initial = const []])
      : _groups = [...initial];

  List<ParticipantGroup> get groups => List.unmodifiable(_groups);

  String newId() =>
      'group-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  void save(ParticipantGroup group) {
    final i = _groups.indexWhere((g) => g.id == group.id);
    if (i < 0) {
      _groups.add(group);
    } else {
      _groups[i] = group;
    }
    notifyListeners();
  }

  void remove(String id) {
    _groups.removeWhere((g) => g.id == id);
    notifyListeners();
  }
}
