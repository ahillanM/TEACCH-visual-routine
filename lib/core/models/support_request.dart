/// Reasons a participant can choose on the Help page.
enum SupportReason {
  dontKnowWhereToGo("I don't know where to go"),
  dontUnderstand("I don't understand what's happening"),
  scheduleWrong('Something is wrong with my schedule'),
  needSupport('I need support');

  final String label;
  const SupportReason(this.label);
}

enum SupportStatus { open, acknowledged, resolved }

class SupportRequest {
  final String id;
  final String participantId;
  final SupportReason reason;
  final DateTime createdAt;

  /// Title of what the participant was doing when they asked, for context.
  final String? currentActivityTitle;
  final SupportStatus status;

  const SupportRequest({
    required this.id,
    required this.participantId,
    required this.reason,
    required this.createdAt,
    this.currentActivityTitle,
    this.status = SupportStatus.open,
  });

  SupportRequest copyWith({SupportStatus? status}) => SupportRequest(
        id: id,
        participantId: participantId,
        reason: reason,
        createdAt: createdAt,
        currentActivityTitle: currentActivityTitle,
        status: status ?? this.status,
      );
}
