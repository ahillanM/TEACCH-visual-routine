/// A named set of participants that staff prepare once (e.g. "Woodwork
/// group") and then use to assign activities, changes and routines to
/// everyone at once.
class ParticipantGroup {
  final String id;
  final String name;
  final Set<String> memberIds;

  const ParticipantGroup({
    required this.id,
    required this.name,
    this.memberIds = const {},
  });

  ParticipantGroup copyWith({String? name, Set<String>? memberIds}) =>
      ParticipantGroup(
        id: id,
        name: name ?? this.name,
        memberIds: memberIds ?? this.memberIds,
      );
}
