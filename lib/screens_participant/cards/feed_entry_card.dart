import 'package:flutter/material.dart';

import '../../core/models/feed_entry.dart';
import 'day_finished_card.dart';
import 'free_time_card.dart';
import 'task_card.dart';
import 'travel_card.dart';
import 'waiting_card.dart';

/// Picks the right card for a feed entry.
///
/// To add a new card type: add a [FeedEntryKind], produce it in
/// `FeedBuilder`, create a card built on `CardFrame`, and map it here.
class FeedEntryCard extends StatelessWidget {
  final FeedEntry entry;
  final DateTime now;
  final bool isImmediateNext;
  final void Function(FeedEntry entry)? onOpenDetails;
  final VoidCallback? onShowChanges;

  /// "Plan my free time" from a free-time or end-of-day card (participant
  /// only; null in staff preview).
  final void Function(FeedEntry entry)? onPlanFreeTime;

  const FeedEntryCard({
    super.key,
    required this.entry,
    required this.now,
    this.isImmediateNext = false,
    this.onOpenDetails,
    this.onShowChanges,
    this.onPlanFreeTime,
  });

  @override
  Widget build(BuildContext context) {
    final open = onOpenDetails == null || entry.event == null
        ? null
        : () => onOpenDetails!(entry);
    final plan = onPlanFreeTime == null || entry.isDone
        ? null
        : () => onPlanFreeTime!(entry);

    return switch (entry.kind) {
      FeedEntryKind.activity => TaskCard(
          entry: entry, now: now, isImmediateNext: isImmediateNext, onTap: open),
      FeedEntryKind.travelling => TravelCard(
          entry: entry, now: now, isImmediateNext: isImmediateNext, onTap: open),
      FeedEntryKind.freeTime => FreeTimeCard(
          entry: entry, now: now, isImmediateNext: isImmediateNext, onPlan: plan),
      FeedEntryKind.waiting || FeedEntryKind.preparing => WaitingCard(
          entry: entry, isImmediateNext: isImmediateNext, onTap: open),
      FeedEntryKind.dayFinished =>
        DayFinishedCard(entry: entry, onShowChanges: onShowChanges, onPlan: plan),
    };
  }
}
