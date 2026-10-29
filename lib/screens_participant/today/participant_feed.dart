import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/models/feed_entry.dart';
import '../../theme.dart';
import '../cards/feed_entry_card.dart';

/// The finite vertical feed of the participant's day.
///
/// PAST ↑ · NOW · ↓ NEXT. On open it positions itself on NOW. It never
/// jumps while the participant is scrolling; when NOW moves on by itself it
/// only re-centres if the participant has not touched the feed recently.
class ParticipantFeed extends StatefulWidget {
  final List<FeedEntry> entries;
  final DateTime now;
  final void Function(FeedEntry entry)? onOpenDetails;
  final VoidCallback? onShowChanges;
  final void Function(FeedEntry entry)? onAddToFreeTime;

  const ParticipantFeed({
    super.key,
    required this.entries,
    required this.now,
    this.onOpenDetails,
    this.onShowChanges,
    this.onAddToFreeTime,
  });

  @override
  State<ParticipantFeed> createState() => ParticipantFeedState();
}

class ParticipantFeedState extends State<ParticipantFeed> {
  /// After the participant scrolls, the feed will not move by itself for
  /// this long.
  static const Duration userScrollQuietPeriod = Duration(minutes: 1);

  /// Where NOW sits in the viewport (0 = top, 1 = bottom).
  static const double nowAlignment = 0.05;

  final _controller = ScrollController();
  final _keys = <String, GlobalKey>{};
  DateTime? _lastUserScroll;
  String? _lastNowKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scrollToNow(animate: false),
    );
  }

  @override
  void didUpdateWidget(ParticipantFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nowKey = _nowEntry?.key;
    if (nowKey != null && nowKey != _lastNowKey && !_userRecentlyScrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToNow());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  FeedEntry? get _nowEntry => widget.entries.where((e) => e.isNow).firstOrNull;

  bool get _userRecentlyScrolled {
    final last = _lastUserScroll;
    return last != null &&
        DateTime.now().difference(last) < userScrollQuietPeriod;
  }

  /// Brings the NOW card into view. Public so "Back to now" can call it.
  void scrollToNow({bool animate = true}) {
    final now = _nowEntry;
    if (now == null || !mounted) return;
    _lastNowKey = now.key;
    final ctx = _keys[now.key]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: nowAlignment,
      duration: animate
          ? AppMotion.of(context, AppMotion.scrollToNow)
          : Duration.zero,
      curve: Curves.easeInOutCubic,
    );
  }

  bool _onScroll(UserScrollNotification n) {
    if (n.direction != ScrollDirection.idle) _lastUserScroll = DateTime.now();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final nowIndex = entries.indexWhere((e) => e.isNow);
    final liveKeys = entries.map((e) => e.key).toSet();
    _keys.removeWhere((k, _) => !liveKeys.contains(k));

    return NotificationListener<UserScrollNotification>(
      onNotification: _onScroll,
      child: SingleChildScrollView(
        controller: _controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.xxxl * 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < entries.length; i++)
              Padding(
                key: _keys.putIfAbsent(entries[i].key, GlobalKey.new),
                padding: const EdgeInsets.only(bottom: AppSpace.lg),
                child: FeedEntryCard(
                  entry: entries[i],
                  now: widget.now,
                  isImmediateNext: nowIndex >= 0 && i == nowIndex + 1,
                  onOpenDetails: widget.onOpenDetails,
                  onShowChanges: widget.onShowChanges,
                  onAddToFreeTime: widget.onAddToFreeTime,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
