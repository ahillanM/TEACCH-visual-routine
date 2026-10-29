import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/free_time.dart';
import '../../core/planning/free_time_planner.dart';
import '../../core/ai/event_draft_generator.dart';
import '../../core/logic/free_time_planner.dart';
import '../../core/models/activity_category.dart';
import '../../core/models/visual_ref.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../../widgets/common.dart';
import '../../widgets/symbol_icons.dart';

/// Opens the choice "Use AI" / "Do it myself" for one free-time window.
///
/// Participants can only add to their own free time; staff activities are
/// never changed.
Future<void> showAddToFreeTime(
  BuildContext context, {
  required String participantId,
  required DateTime from,
  required DateTime until,
}) {
  final now = AppScope.of(context).clock.now();
  final start = FreeTimePlanner.earliestStart(from, now);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      void open(Widget page) {
        Navigator.pop(sheetContext);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            0,
            AppSpace.lg,
            AppSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Add to My Free Time',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Free time: ${TimeFormat.range(start, until)}',
                style: TextStyle(
                  fontSize: 16,
                  color: sheetContext.palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              _ChoiceTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Use AI',
                subtitle: 'Write what you want to do. AI makes a plan.',
                onTap: () => open(
                  AiFreeTimePage(
                    participantId: participantId,
                    from: start,
                    until: until,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              _ChoiceTile(
                icon: Icons.edit_outlined,
                title: 'Do It Myself',
                subtitle: 'Choose an activity and how long.',
                onTap: () => open(
                  ManualFreeTimePage(
                    participantId: participantId,
                    from: start,
                    until: until,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: palette.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 32, color: palette.brand),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saves the activities and returns to the day.
///
/// With Supabase the plan goes through `save_personal_free_time_plan`, which
/// re-checks availability on the server (all or nothing); offline it is kept
/// in the local store.
Future<void> _addToDay(
  BuildContext context,
  String participantId,
  List<EventProposal> proposals,
) async {
  final services = AppScope.of(context);
  final store = services.schedule;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final events = [
    for (final p in proposals)
      FreeTimePlanner.toEvent(
        p,
        id: store.newId('own'),
        participantId: participantId,
      ),
  ];
  final backend = services.freeTime;
  if (backend != null && events.isNotEmpty) {
    final symbolOk = RegExp(r'^[a-z_]{1,40}$');
    final pictoOk = RegExp(
        r'^https://static\.arasaac\.org/pictograms/[0-9]{1,7}/[0-9]{1,7}_[0-9]{3}\.png$');
    try {
      final day = await backend.loadDay(events.first.start);
      await backend.save(day, [
        for (final e in events)
          DraftActivity(
            title: e.title,
            start: e.start.hour * 60 + e.start.minute,
            end: e.end.hour * 60 + e.end.minute,
            iconKey: symbolOk.hasMatch(e.visual.symbol) ? e.visual.symbol : 'event',
            pictogramUrl: pictoOk.hasMatch(e.visual.pictogramUrl ?? '')
                ? e.visual.pictogramUrl
                : null,
          ),
      ]);
    } on PlanSaveException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
  } else {
    store.addParticipantEvents(
      participantId: participantId,
      participantName: services.participants.nameOf(participantId),
      events: events,
    );
  }
  navigator.pop();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        proposals.length == 1
            ? '"${proposals.single.title}" was added to your day.'
            : '${proposals.length} activities were added to your day.',
      ),
    ),
  );
}

// ---------------------------------------------------------------- with AI

class AiFreeTimePage extends StatefulWidget {
  final String participantId;
  final DateTime from;
  final DateTime until;

  const AiFreeTimePage({
    super.key,
    required this.participantId,
    required this.from,
    required this.until,
  });

  @override
  State<AiFreeTimePage> createState() => _AiFreeTimePageState();
}

class _AiFreeTimePageState extends State<AiFreeTimePage> {
  final _text = TextEditingController();
  bool _loading = false;
  bool _usedFallback = false;
  List<EventProposal>? _plan;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _makePlan() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final services = AppScope.of(context);
    setState(() => _loading = true);
    var ai = <EventProposal>[];
    var fallback = false;
    try {
      // Only the typed text is sent – never names or profile data.
      ai = await services.aiDrafts.propose(
        text,
        today: widget.from,
        library: services.library.activities,
      );
    } catch (_) {
      fallback = true;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _usedFallback = fallback;
      _plan = FreeTimePlanner.fromText(
        text: text,
        aiProposals: ai,
        from: widget.from,
        until: widget.until,
        library: services.library.activities,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan with AI')),
      body: MaxWidth(
        maxWidth: AppBreakpoints.participantMaxWidth,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Text(
              'Free time: ${TimeFormat.range(widget.from, widget.until)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _text,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'What do you want to do?',
                hintText: 'e.g. listen to music, then read a book',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: kLargeTouchTarget,
              child: FilledButton.icon(
                onPressed: _loading || _text.text.trim().isEmpty
                    ? null
                    : _makePlan,
                icon: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: palette.onBrand,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(plan == null ? 'Make My Plan' : 'Make a New Plan'),
              ),
            ),
            if (plan != null) ...[
              const SizedBox(height: AppSpace.xl),
              if (_usedFallback)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: InfoLine(
                    icon: Icons.cloud_off_outlined,
                    text:
                        'AI is not available right now. '
                        'The plan was made from your words.',
                  ),
                ),
              if (plan.isEmpty)
                const EmptyState(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'This does not fit into your free time.',
                  message: 'Try fewer or shorter activities.',
                )
              else ...[
                const SectionLabel('Your Plan'),
                for (var i = 0; i < plan.length; i++)
                  _ProposalCard(
                    proposal: plan[i],
                    onRemove: () =>
                        setState(() => _plan = [...plan]..removeAt(i)),
                  ),
                const SizedBox(height: AppSpace.md),
                SizedBox(
                  height: kLargeTouchTarget,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _addToDay(context, widget.participantId, plan),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Add to My Day'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final EventProposal proposal;
  final VoidCallback? onRemove;

  const _ProposalCard({required this.proposal, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = CategoryStyle.of(proposal.category!, palette);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: ActivityVisual(
                  visual: proposal.visual ?? const VisualRef(symbol: 'free'),
                  accent: style.color,
                  semanticLabel: proposal.title,
                  height: 64,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      TimeFormat.range(proposal.start, proposal.end),
                      style: TextStyle(
                        fontSize: 16,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove ${proposal.title}',
                  iconSize: 28,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- manual

class ManualFreeTimePage extends StatefulWidget {
  final String participantId;
  final DateTime from;
  final DateTime until;

  const ManualFreeTimePage({
    super.key,
    required this.participantId,
    required this.from,
    required this.until,
  });

  @override
  State<ManualFreeTimePage> createState() => _ManualFreeTimePageState();
}

class _ManualFreeTimePageState extends State<ManualFreeTimePage> {
  static const _durations = [15, 30, 45, 60];

  final _title = TextEditingController();
  VisualRef? _visual;
  late DateTime _start = widget.from;
  int? _minutes;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  int get _available => widget.until.difference(_start).inMinutes;

  /// Possible start times: every 15 minutes inside the window.
  List<DateTime> get _starts => [
    for (
      var t = widget.from;
      widget.until.difference(t).inMinutes >= FreeTimePlanner.minMinutes;
      t = t.add(const Duration(minutes: 15))
    )
      t,
  ];

  int get _length {
    final m = _minutes ?? FreeTimePlanner.defaultMinutes;
    return m > _available ? _available : m;
  }

  EventProposal? get _proposal {
    final title = _title.text.trim();
    if (title.isEmpty || _available < FreeTimePlanner.minMinutes) return null;
    final library = AppScope.of(context).library.activities;
    return EventProposal(
      title: FreeTimePlanner.capitalize(title),
      start: _start,
      end: _start.add(Duration(minutes: _length)),
      category: ActivityCategory.personal,
      visual: _visual ?? FreeTimePlanner.visualFor(title, library),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final proposal = _proposal;
    return Scaffold(
      appBar: AppBar(title: const Text('Do It Myself')),
      body: MaxWidth(
        maxWidth: AppBreakpoints.participantMaxWidth,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: [
            Text(
              'Free time: ${TimeFormat.range(widget.from, widget.until)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.lg),
            const SectionLabel('1. What do you want to do?'),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final idea in FreeTimePlanner.ideas)
                  ChoiceChip(
                    padding: const EdgeInsets.all(AppSpace.sm),
                    labelStyle: const TextStyle(fontSize: 16),
                    avatar: Icon(_iconFor(idea.visual)),
                    label: Text(idea.title),
                    selected: _title.text == idea.title,
                    onSelected: (_) => setState(() {
                      _title.text = idea.title;
                      _visual = idea.visual;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _title,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(labelText: 'Or Write Your Own'),
              onChanged: (_) => setState(() => _visual = null),
            ),
            const SizedBox(height: AppSpace.xl),
            const SectionLabel('2. When do you start?'),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final t in _starts)
                  ChoiceChip(
                    padding: const EdgeInsets.all(AppSpace.sm),
                    labelStyle: const TextStyle(fontSize: 16),
                    label: Text(TimeFormat.hm(t)),
                    selected: t == _start,
                    onSelected: (_) => setState(() => _start = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            const SectionLabel('3. How long?'),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final m in _durations)
                  if (m <= _available)
                    ChoiceChip(
                      padding: const EdgeInsets.all(AppSpace.sm),
                      labelStyle: const TextStyle(fontSize: 16),
                      label: Text('$m Minutes'),
                      selected: _length == m,
                      onSelected: (_) => setState(() => _minutes = m),
                    ),
                ChoiceChip(
                  padding: const EdgeInsets.all(AppSpace.sm),
                  labelStyle: const TextStyle(fontSize: 16),
                  label: Text('Until ${TimeFormat.hm(widget.until)}'),
                  selected:
                      _length == _available && !_durations.contains(_available),
                  onSelected: (_) => setState(() => _minutes = _available),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            if (proposal != null) ...[
              const SectionLabel('Your Plan'),
              _ProposalCard(proposal: proposal),
              const SizedBox(height: AppSpace.md),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(
                  'Choose or write an activity first.',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ),
            SizedBox(
              height: kLargeTouchTarget,
              child: FilledButton.icon(
                onPressed: proposal == null
                    ? null
                    : () =>
                          _addToDay(context, widget.participantId, [proposal]),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Add to My Day'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(VisualRef v) => SymbolIcons.of(v.symbol);
}
