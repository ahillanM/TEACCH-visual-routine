import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/free_time.dart';
import '../../core/models/activity_category.dart';
import '../../core/models/visual_ref.dart';
import '../../core/planning/free_time_planner.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../../widgets/common.dart';
import '../../widgets/dictation_button.dart';

/// Opens "Plan my free time" for [date]. [slotStart]/[slotEnd] preselect a
/// free period the participant tapped. Returns true when a plan was saved.
Future<bool> openFreeTimePlanner(
  BuildContext context, {
  required DateTime date,
  DateTime? slotStart,
  DateTime? slotEnd,
}) async {
  final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
    builder: (_) => PlanFreeTimePage(
      date: TimeFormat.dateOnly(date),
      slotStart: slotStart == null ? null : slotStart.hour * 60 + slotStart.minute,
      slotEnd: slotEnd == null ? null : slotEnd.hour * 60 + slotEnd.minute,
    ),
  ));
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your plan is saved. You can see it in your day.')));
  }
  return saved == true;
}

/// PLAN MY FREE TIME: speak or type → AI draft → check → confirm → save.
///
/// Official activities are only shown (read-only). All rules come from
/// [FreeTimeRules]; the server checks everything again when saving.
class PlanFreeTimePage extends StatefulWidget {
  final DateTime date;
  final DayMinute? slotStart;
  final DayMinute? slotEnd;

  const PlanFreeTimePage({super.key, required this.date, this.slotStart, this.slotEnd});

  @override
  State<PlanFreeTimePage> createState() => _PlanFreeTimePageState();
}

class _PlanFreeTimePageState extends State<PlanFreeTimePage> {
  final _text = TextEditingController();
  PlanningDay? _day;
  String? _loadError;
  List<DraftActivity> _drafts = [];
  Map<int, String> _serverProblems = {};
  FreeSlot? _slot;
  bool _thinking = false;
  bool _saving = false;
  bool _listening = false;

  FreeTimePlanner get _planner => AppScope.of(context).freeTime!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_day == null && _loadError == null) _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final day = await _planner.loadDay(widget.date);
      if (!mounted) return;
      setState(() {
        _day = day;
        _loadError = null;
        final s = widget.slotStart;
        _slot = s == null
            ? null
            : day.freeSlots.where((f) => s >= f.start && s < f.end).firstOrNull;
      });
    } on PlanSaveException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _suggest() async {
    final day = _day!;
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _thinking = true);
    try {
      final drafts = await _planner.suggest(text, day);
      if (!mounted) return;
      setState(() {
        _drafts = [..._drafts, ...drafts];
        _serverProblems = {};
      });
    } on PlanSaveException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  void _addManually() {
    setState(() {
      _drafts = [..._drafts, DraftActivity(title: '', start: _slot?.start)];
      _serverProblems = {};
    });
  }

  void _update(int i, DraftActivity d) => setState(() {
        _drafts = [..._drafts]..[i] = d;
        _serverProblems = {};
      });

  void _remove(int i) => setState(() {
        _drafts = [..._drafts]..removeAt(i);
        _serverProblems = {};
      });

  Future<void> _save() async {
    final day = _day!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save my plan?'),
        content: Text(
          '${_drafts.length} ${_drafts.length == 1 ? 'activity' : 'activities'} on '
          '${TimeFormat.longDate(day.date)}.\n\n'
          'After saving you can mark them as done. To change them later, ask staff.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _planner.save(day, _drafts);
      if (mounted) Navigator.of(context).pop(true);
    } on PlanSaveException catch (e) {
      if (!mounted) return;
      _say(e.message);
      setState(() => _serverProblems = e.problems);
      await _load(); // something changed: show the current free time
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan my free time')),
      body: MaxWidth(
        maxWidth: AppBreakpoints.participantMaxWidth,
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final palette = context.palette;
    final day = _day;
    if (_loadError != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: _loadError!,
        action: FilledButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    if (day == null) return const Center(child: CircularProgressIndicator());

    final checks = FreeTimeRules.validate(day, _drafts);
    final canSave = FreeTimeRules.canSave(day, _drafts) && _serverProblems.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Semantics(
          header: true,
          child: Text(TimeFormat.longDate(day.date),
              style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpace.md),
        if (day.blocked)
          _Notice(
            icon: Icons.lock_clock_rounded,
            title: 'This day cannot be planned yet.',
            text: day.blockedReason ?? 'Please ask staff.',
          )
        else ...[
          _FreeTimeSection(
            day: day,
            selected: _slot,
            onSelect: (s) => setState(() => _slot = s),
          ),
          if (day.hasFreeTime) ...[
            const SizedBox(height: AppSpace.lg),
            Text('What do you want to do?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 2,
                    maxLines: 4,
                    readOnly: _listening,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: _slot == null
                          ? 'e.g. Football at 2 pm for one hour, then a movie at 8 pm'
                          : 'e.g. Football from ${formatHm(_slot!.start)} for one hour',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                DictationButton(
                  controller: _text,
                  onListeningChanged: (v) => setState(() => _listening = v),
                  onMessage: _say,
                ),
              ],
            ),
            if (_listening) ...[
              const SizedBox(height: AppSpace.sm),
              Semantics(
                liveRegion: true,
                child: Row(children: [
                  Icon(Icons.graphic_eq_rounded, color: palette.brand),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text('Listening … tap ■ when you are done',
                        style: TextStyle(color: palette.brand, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              const SizedBox(height: AppSpace.xs),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _thinking ? null : _addManually,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add one myself'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _thinking || _listening || _text.text.trim().isEmpty ? null : _suggest,
                  icon: _thinking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Make a plan'),
                ),
              ],
            ),
          ],
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xl),
            Text('Check your plan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.sm),
            for (var i = 0; i < _drafts.length; i++)
              _DraftCard(
                key: ObjectKey(_drafts[i]),
                day: day,
                draft: _drafts[i],
                check: checks[i],
                serverProblem: _serverProblems[i],
                onChanged: (d) => _update(i, d),
                onRemove: () => _remove(i),
              ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: kLargeTouchTarget,
              child: FilledButton.icon(
                key: const Key('save-plan'),
                onPressed: canSave && !_saving ? _save : null,
                icon: const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Saving …' : 'Save my plan'),
              ),
            ),
            if (!canSave)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Text('Fix the orange notes first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textSecondary)),
              ),
          ],
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Notice({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          children: [
            Icon(icon, size: 48, color: context.palette.textSecondary),
            const SizedBox(height: AppSpace.sm),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.xs),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Free slots (tappable) and what is already planned (read-only).
class _FreeTimeSection extends StatelessWidget {
  final PlanningDay day;
  final FreeSlot? selected;
  final ValueChanged<FreeSlot?> onSelect;

  const _FreeTimeSection({required this.day, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final slots = day.freeSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your free time', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpace.sm),
        if (slots.isEmpty)
          const _Notice(
            icon: Icons.event_busy_rounded,
            title: 'No free time left on this day.',
            text: 'Everything is already planned.',
          )
        else
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final s in slots)
                ChoiceChip(
                  avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                  label: Text(s.toString(), style: const TextStyle(fontSize: 16)),
                  selected: selected == s ||
                      (selected != null && selected!.start == s.start && selected!.end == s.end),
                  onSelected: (on) => onSelect(on ? s : null),
                ),
            ],
          ),
        if (day.busy.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          Text('Already planned', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
          for (final b in day.busy)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                  b.kind == BusyKind.personal ? Icons.person_outline_rounded : Icons.lock_outline_rounded,
                  color: palette.textSecondary),
              title: Text(b.title),
              subtitle: Text('${formatHm(b.start)}–${formatHm(b.end)}'
                  '${b.timeUnknown ? ' (end time not set)' : ''}'),
            ),
        ],
      ],
    );
  }
}

class _DraftCard extends StatefulWidget {
  final PlanningDay day;
  final DraftActivity draft;
  final DraftCheck check;
  final String? serverProblem;
  final ValueChanged<DraftActivity> onChanged;
  final VoidCallback onRemove;

  const _DraftCard({
    super.key,
    required this.day,
    required this.draft,
    required this.check,
    required this.serverProblem,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<_DraftCard> {
  late final _title = TextEditingController(text: widget.draft.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = widget.draft;
    final initial = d.start ?? widget.day.earliestStart;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      helpText: 'When does it start?',
    );
    if (t == null) return;
    final start = t.hour * 60 + t.minute;
    final length = (d.start != null && d.end != null) ? d.end! - d.start! : null;
    widget.onChanged(d.copyWith(
      start: start,
      end: length == null ? null : start + length,
      clearEnd: length == null && d.end != null && d.end! <= start,
      clearOtherDay: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final d = widget.draft;
    final style = CategoryStyle.of(ActivityCategory.personal);
    final problem = widget.serverProblem ??
        (widget.check.ok ? null : FreeTimeRules.explain(widget.check, widget.day));
    final length = d.start != null && d.end != null ? d.end! - d.start! : null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: ActivityVisual(
                    visual: VisualRef(symbol: d.iconKey, pictogramUrl: d.pictogramUrl),
                    accent: style.color,
                    semanticLabel: d.title,
                    height: 64,
                    showPhoto: false,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: TextField(
                    controller: _title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(labelText: 'Activity'),
                    onChanged: (t) => widget.onChanged(d.copyWith(title: t)),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove from my plan',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickStart,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(d.start == null ? 'Choose start' : 'Starts ${formatHm(d.start!)}'),
                ),
                for (final m in FreeTimeRules.durationChoices)
                  ChoiceChip(
                    label: Text(m < 60 ? '$m min' : m % 60 == 0 ? '${m ~/ 60} h' : '${m / 60} h'),
                    selected: length == m,
                    onSelected: d.start == null
                        ? null
                        : (_) => widget.onChanged(d.copyWith(end: d.start! + m)),
                  ),
                if (d.end != null && d.start != null)
                  Text('until ${formatHm(d.end!)}', style: TextStyle(color: palette.textSecondary)),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Icon(problem == null ? Icons.check_circle_rounded : Icons.info_rounded,
                    color: problem == null ? palette.success : palette.changeText),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    problem ?? FreeTimeRules.explain(widget.check, widget.day),
                    style: TextStyle(
                        color: problem == null ? palette.success : palette.changeText,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
