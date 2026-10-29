import 'package:flutter/foundation.dart';

import '../models/participant.dart';

/// Participants and their support profiles.
class ParticipantDirectory extends ChangeNotifier {
  final Map<String, Participant> _participants;

  ParticipantDirectory(Iterable<Participant> participants)
      : _participants = {for (final p in participants) p.id: p};

  Map<String, Participant> get byId => Map.unmodifiable(_participants);

  List<Participant> get all =>
      _participants.values.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

  Participant? operator [](String id) => _participants[id];

  String nameOf(String id) => _participants[id]?.displayName ?? 'Unknown';

  List<Participant> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((p) =>
            p.displayName.toLowerCase().contains(q) ||
            p.livingGroup.toLowerCase().contains(q))
        .toList();
  }

  void updateProfile(String participantId, ParticipantProfile profile) {
    final p = _participants[participantId];
    if (p == null) return;
    _participants[participantId] = p.copyWith(profile: profile);
    notifyListeners();
  }
}
