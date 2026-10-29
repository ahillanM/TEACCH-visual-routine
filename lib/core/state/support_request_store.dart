import 'package:flutter/foundation.dart';

import '../models/support_request.dart';

/// MOCK: local support requests. Kept separate from schedule state; a real
/// implementation would push these to staff devices via the backend.
class SupportRequestStore extends ChangeNotifier {
  final List<SupportRequest> _requests;
  int _counter = 0;

  SupportRequestStore([Iterable<SupportRequest> initial = const []])
      : _requests = [...initial];

  List<SupportRequest> get all =>
      [..._requests]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<SupportRequest> get unresolved =>
      all.where((r) => r.status != SupportStatus.resolved).toList();

  int get openCount =>
      _requests.where((r) => r.status == SupportStatus.open).length;

  SupportRequest create({
    required String participantId,
    required SupportReason reason,
    required DateTime at,
    String? currentActivityTitle,
  }) {
    final request = SupportRequest(
      id: 'support-${at.microsecondsSinceEpoch}-${_counter++}',
      participantId: participantId,
      reason: reason,
      createdAt: at,
      currentActivityTitle: currentActivityTitle,
    );
    _requests.add(request);
    notifyListeners();
    return request;
  }

  void setStatus(String id, SupportStatus status) {
    final i = _requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    _requests[i] = _requests[i].copyWith(status: status);
    notifyListeners();
  }
}
