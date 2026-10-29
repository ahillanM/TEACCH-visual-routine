import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/logic/change_factory.dart';
import '../../core/logic/impact_checker.dart';
import '../../core/models/activity_category.dart';
import '../../core/models/library_items.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/models/visual_ref.dart';
import '../../core/time/time_format.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../changes/change_impact_panel.dart';
import '../common/staff_widgets.dart';
import '../preview/participant_preview_dialog.dart';

/// Create or edit one activity: SAVE DRAFT · PREVIEW · PUBLISH.
///
/// Edits are drafts until published; participants never see drafts.
class ActivityEditorPage extends StatefulWidget {
  /// Existing event to edit, or null to create a new one.
  final ScheduledEvent? initial;

  /// Default day for new events.
  final DateTime day;

  const ActivityEditorPage({super.key, this.initial, required this.day});

  @override
  State<ActivityEditorPage> createState() => _ActivityEditorPageState();
}

class _ActivityEditorPageState extends State<ActivityEditorPage> {
  static const _defaultStartHour = 9;
  static const _defaultDurationMin = 60;
  static const _reminderOptions = [5, 10, 15, 30];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _bring;
  late final TextEditingController _instructions;

  late String _id;
  late ActivityCategory _category;
  late EventKind _kind;
  late DateTime _start;
  late DateTime _end;
  String? _placeId;
  String? _contactId;
  late VisualRef _visual;
  String? _libraryActivityId;
  String? _planBId;
  int? _reminder;
  late Set<String> _participants;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    final day = widget.day;
    _id = e?.id ?? 'evt-new-${DateTime.now().microsecondsSinceEpoch}';
    _title = TextEditingController(text: e?.title ?? '');
    _bring = TextEditingController(text: e?.whatToBring.join(', ') ?? '');
    _instructions = TextEditingController(text: e?.instructions ?? '');
    _category = e?.category ?? ActivityCategory.work;
    _kind = e?.kind ?? EventKind.activity;
    _start = e?.start ??
        DateTime(day.year, day.month, day.day, _defaultStartHour);
    _end = e?.end ?? _start.add(const Duration(minutes: _defaultDurationMin));
    _placeId = e?.placeId;
    _contactId = e?.contactId;
    _visual = e?.visual ?? const VisualRef(symbol: 'event');
    _libraryActivityId = e?.libraryActivityId;
    _planBId = e?.planBActivityId;
    _reminder = e?.reminderMinutesBefore;
    _participants = {...?e?.assignedParticipantIds};
  }

  @override
  void dispose() {
    _title.dispose();
    _bring.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _applyLibrary(LibraryActivity? a) {
    if (a == null) return;
    setState(() {
      _libraryActivityId = a.id;
      _title.text = a.name;
      _category = a.category;
      _visual = a.visual;
      _placeId = a.defaultPlaceId ?? _placeId;
      _contactId = a.defaultContactId ?? _contactId;
      _bring.text = a.whatToBring.join(', ');
      _instructions.text = a.instructions ?? '';
      _end = _start.add(Duration(minutes: a.defaultDurationMin));
    });
  }

  ScheduledEvent _build() {
    final base = widget.initial;
    final bring = _bring.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return ScheduledEvent(
      id: _id,
      title: _title.text.trim().isEmpty ? 'Untitled activity' : _title.text.trim(),
      category: _category,
      kind: _kind,
      start: _start,
      end: _end,
      placeId: _placeId,
      contactId: _contactId,
      visual: _visual,
      whatToBring: bring,
      instructions:
          _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
      assignedParticipantIds: _participants,
      status: base?.status ?? EventStatus.active,
      libraryActivityId: _libraryActivityId,
      planBActivityId: _planBId,
      reminderMinutesBefore: _reminder,
      replacesEventId: base?.replacesEventId,
    );
  }

  bool _validate() {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (!_end.isAfter(_start)) {
      showStaffMessage(context, 'The end time must be after the start time.');
      return false;
    }
    return true;
  }

  void _saveDraft() {
    if (!_validate()) return;
    AppScope.of(context).schedule.saveDraft(_build());
    Navigator.of(context).pop();
    showStaffMessage(
        context, 'Draft saved. Participants will not see it until you publish.');
  }

  void _preview() {
    if (!_validate()) return;
    if (_participants.isEmpty) {
      showStaffMessage(context, 'Assign at least one participant to preview.');
      return;
    }
    final services = AppScope.of(context);
    final store = services.schedule;
    final event = _build();
    final change = ChangeFactory.create(
      id: 'preview',
      base: store.published,
      upserts: [event],
      version: store.version + 1,
      publishedAt: services.clock.now(),
      publishedBy: services.auth.user?.displayName ?? 'Staff',
    );
    showParticipantPreview(
      context,
      participantIds: _participants.toList()..sort(),
      latest: store.published.applying([event]),
      pendingChanges: [change],
    );
  }

  void _publish() {
    if (!_validate()) return;
    if (_participants.isEmpty) {
      showStaffMessage(context, 'Assign at least one participant before publishing.');
      return;
    }
    final services = AppScope.of(context);
    services.schedule.publish(
      upserts: [_build()],
      publishedBy: services.auth.user?.displayName ?? 'Staff',
    );
    Navigator.of(context).pop();
    showStaffMessage(context, 'Published to ${_participants.length} participant(s).');
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final library = services.library;
    final event = _build();
    final report = ImpactChecker.evaluate(
      base: services.schedule.published,
      upserts: [event],
      participants: services.participants.byId,
      placeName: library.placeName,
      contactName: library.contactName,
    );
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'What',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _libraryActivityId,
                  decoration: const InputDecoration(
                    labelText: 'Start from library activity (optional)',
                    prefixIcon: Icon(Icons.collections_bookmark_outlined),
                  ),
                  items: [
                    for (final a in library.activities)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (id) => _applyLibrary(library.activity(id)),
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Activity title'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a title.'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.md,
                  runSpacing: AppSpace.md,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<ActivityCategory>(
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [
                          for (final c in ActivityCategory.values)
                            DropdownMenuItem(
                              value: c,
                              child: Row(children: [
                                Icon(CategoryStyle.of(c).icon,
                                    color: CategoryStyle.of(c).color, size: 18),
                                const SizedBox(width: AppSpace.sm),
                                Text(CategoryStyle.of(c).label),
                              ]),
                            ),
                        ],
                        onChanged: (c) => setState(() => _category = c ?? _category),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<EventKind>(
                        initialValue: _kind,
                        decoration: const InputDecoration(labelText: 'Card type'),
                        items: const [
                          DropdownMenuItem(
                              value: EventKind.activity, child: Text('Activity')),
                          DropdownMenuItem(
                              value: EventKind.travel, child: Text('Travel')),
                          DropdownMenuItem(
                              value: EventKind.preparing, child: Text('Preparing')),
                          DropdownMenuItem(
                              value: EventKind.waiting, child: Text('Waiting')),
                        ],
                        onChanged: (k) => setState(() => _kind = k ?? _kind),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                _VisualPicker(
                  value: _visual,
                  accent: CategoryStyle.of(_category).color,
                  options: [
                    for (final a in library.activities) a.visual,
                    for (final p in library.places) p.visual,
                  ],
                  onChanged: (v) => setState(() => _visual = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SectionCard(
            title: 'When',
            child: Wrap(
              spacing: AppSpace.md,
              runSpacing: AppSpace.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(TimeFormat.longDate(_start)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _start,
                      firstDate: _start.subtract(const Duration(days: 365)),
                      lastDate: _start.add(const Duration(days: 365)),
                    );
                    if (picked == null) return;
                    final duration = _end.difference(_start);
                    setState(() {
                      _start = DateTime(picked.year, picked.month, picked.day,
                          _start.hour, _start.minute);
                      _end = _start.add(duration);
                    });
                  },
                ),
                TimeField(
                  label: 'Start',
                  value: _start,
                  onChanged: (t) => setState(() {
                    final duration = _end.difference(_start);
                    _start = t;
                    _end = t.add(duration);
                  }),
                ),
                TimeField(
                  label: 'End',
                  value: _end,
                  onChanged: (t) => setState(() => _end = t),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _reminder,
                    decoration:
                        const InputDecoration(labelText: 'Reminder / transition'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Participant default')),
                      for (final m in _reminderOptions)
                        DropdownMenuItem(
                            value: m, child: Text('$m min before start')),
                    ],
                    onChanged: (m) => setState(() => _reminder = m),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SectionCard(
            title: 'Where and with whom',
            child: Wrap(
              spacing: AppSpace.md,
              runSpacing: AppSpace.md,
              children: [
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _placeId,
                    decoration: const InputDecoration(
                        labelText: 'Location',
                        prefixIcon: Icon(Icons.place_outlined)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      for (final p in library.places)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (id) => setState(() => _placeId = id),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _contactId,
                    decoration: const InputDecoration(
                        labelText: 'Person / contact',
                        prefixIcon: Icon(Icons.person_outline_rounded)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      for (final c in library.contacts)
                        DropdownMenuItem(
                            value: c.id, child: Text('${c.name} · ${c.roleLabel}')),
                    ],
                    onChanged: (id) => setState(() => _contactId = id),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SectionCard(
            title: 'Participant information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _bring,
                  decoration: const InputDecoration(
                    labelText: 'What to bring (comma separated)',
                    prefixIcon: Icon(Icons.backpack_outlined),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _instructions,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Short instructions (simple, concrete language)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<String?>(
                  initialValue: _planBId,
                  decoration: const InputDecoration(
                    labelText: 'Plan B (optional, used if cancelled)',
                    prefixIcon: Icon(Icons.alt_route_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final a in library.activities)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (id) => setState(() => _planBId = id),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SectionCard(
            title: 'Assign to',
            child: ListenableBuilder(
              listenable: services.participants,
              builder: (context, _) => ParticipantSelector(
                participants: services.participants.all,
                selected: _participants,
                onChanged: (s) => setState(() => _participants = s),
              ),
            ),
          ),
        ],
      ),
    );

    final impact = SectionCard(
      title: 'Impact check',
      child: ChangeImpactPanel(report: report),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New activity' : 'Edit activity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: form),
                  const SizedBox(width: AppSpace.xl),
                  Expanded(flex: 2, child: impact),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [form, const SizedBox(height: AppSpace.lg), impact],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpace.md,
            runSpacing: AppSpace.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _saveDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save draft'),
              ),
              OutlinedButton.icon(
                onPressed: _preview,
                icon: const Icon(Icons.phone_android_rounded),
                label: const Text('Preview'),
              ),
              FilledButton.icon(
                onPressed: _publish,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Publish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pick a visual from those already in the library (no re-uploading).
class _VisualPicker extends StatelessWidget {
  final VisualRef value;
  final Color accent;
  final List<VisualRef> options;
  final ValueChanged<VisualRef> onChanged;

  const _VisualPicker({
    required this.value,
    required this.accent,
    required this.options,
    required this.onChanged,
  });

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unique = <String, VisualRef>{
      for (final v in options) v.pictogramUrl ?? v.symbol: v,
    }.values.toList();
    final selectedKey = value.pictogramUrl ?? value.symbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Visual / pictogram',
            style: TextStyle(color: palette.textSecondary)),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          height: _size + AppSpace.sm,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: unique.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (context, i) {
              final v = unique[i];
              final selected = (v.pictogramUrl ?? v.symbol) == selectedKey;
              return Semantics(
                selected: selected,
                button: true,
                label: 'Visual ${v.symbol}',
                child: InkWell(
                  onTap: () => onChanged(v),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    width: _size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: selected ? palette.focus : palette.border,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: ActivityVisual(
                      visual: v,
                      accent: accent,
                      semanticLabel: v.symbol,
                      height: _size,
                      showPhoto: false,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
