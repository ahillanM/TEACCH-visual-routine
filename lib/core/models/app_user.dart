enum Role { participant, staff, admin }

/// A signed-in account. Participants link to their [Participant] record via
/// [participantId]; professionals have no participant link.
class AppUser {
  final String id;
  final String username;
  final String displayName;
  final Role role;
  final String? participantId;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.participantId,
  });
}
