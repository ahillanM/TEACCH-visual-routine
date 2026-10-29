import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/participant_day.dart';
import '../../core/models/feed_entry.dart';
import '../../core/models/support_request.dart';
import '../changes/change_history_sheet.dart';
import '../changes/change_notice_page.dart';
import '../details/task_details_page.dart';
import '../plan/plan_free_time_page.dart';
import 'participant_feed.dart';
import 'participant_today_view.dart';

/// TODAY tab: connects the schedule store and clock to [ParticipantTodayView]
/// and handles navigation (details, change notice, history).
class TodayPage extends StatefulWidget {
  final String participantId;
  final void Function(SupportReason reason) onNeedHelp;

  const TodayPage({
    super.key,
    required this.participantId,
    required this.onNeedHelp,
  });

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _feedKey = GlobalKey<ParticipantFeedState>();

  Future<void> _openChanges(ParticipantDay day) async {
    final result = await Navigator.of(context).push<ChangeNoticeResult>(
      MaterialPageRoute(
        builder: (_) => ChangeNoticePage(
          notice: day.notice,
          changes: day.pendingChanges,
        ),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case ChangeNoticeResult.understood:
        // Only now is the updated plan applied to the feed.
        AppScope.of(context).schedule.acknowledge(widget.participantId);
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _feedKey.currentState?.scrollToNow());
      case ChangeNoticeResult.needHelp:
        widget.onNeedHelp(SupportReason.dontUnderstand);
      case null:
        break;
    }
  }

  void _openDetails(FeedEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailsPage(entry: entry)),
    );
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeHistorySheet(participantId: widget.participantId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([services.schedule, services.clock]),
      builder: (context, _) {
        final day = ParticipantDay.resolve(
          store: services.schedule,
          participantId: widget.participantId,
          now: services.clock.now(),
        );
        return ParticipantTodayView(
          day: day,
          feedKey: _feedKey,
          onOpenChanges: () => _openChanges(day),
          onOpenDetails: _openDetails,
          onShowChanges: _showHistory,
          onPlanFreeTime: services.freeTime == null
              ? null
              : (entry) {
                  final now = services.clock.now();
                  openFreeTimePlanner(
                    context,
                    date: now,
                    slotStart: entry.start.isAfter(now) ? entry.start : now,
                    slotEnd: entry.end,
                  );
                },
        );
      },
    );
  }
}
