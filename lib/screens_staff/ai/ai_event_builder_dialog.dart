import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/ai/event_draft_generator.dart';
import '../../core/models/activity_category.dart';
import '../../core/models/scheduled_event.dart';
import '../../core/models/visual_ref.dart';
import '../../core/time/time_format.dart';
import '../../services/speech_input.dart';
import '../../theme.dart';
import '../common/staff_widgets.dart';

/// BUILD WITH AI (prototype): free text → proposed activities → staff review
/// → saved as DRAFTS. AI never publishes; staff preview and publish later.
Future<void> showAiEventBuilder(BuildContext context, {required DateTime day}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpace.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _AiBuilder(day: day),
      ),
    ),
  );
}

class _AiBuilder extends StatefulWidget {
  final DateTime day;
  const _AiBuilder({required this.day});

  @override
  State<_AiBuilder> createState() => _AiBuilderState();
}

class _AiBuilderState extends State<_AiBuilder> {
  static const _exampleText =
      'Tomorrow woodworking at 9, lunch at 12 and physiotherapy at 2';
  final _text = TextEditingController(text: _exampleText);
  /// Proposals keyed by a stable id so rows keep their state when edited.
  List<(int, EventProposal)>? _proposals;
  Set<String> _participants = {};
  bool _loading = false;

  // Voice input: fills [_text]; generation stays the same as for typing.
  late final SpeechInput _speech = AppScope.of(context).speech;
  bool _voiceStarting = false;
  bool _listening = false;
  late SpeechLanguage _language = SpeechLanguage.forLocale(
      WidgetsBinding.instance.platformDispatcher.locale);
  String _textBeforeVoice = '';

  @override
  void dispose() {
    if (_listening) _speech.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop(); // final text arrives, then onDone
      return;
    }
    if (_voiceStarting || _loading || _speech.isListening) return;
    setState(() => _voiceStarting = true);
    final problem = await _speech.initialize();
    if (!mounted) return;
    if (problem != null) {
      setState(() => _voiceStarting = false);
      showStaffMessage(
          context,
          problem == SpeechUnavailable.permissionDenied
              ? 'Microphone access was denied. Allow it in the phone settings to dictate, or type instead.'
              : 'Voice input is not available on this device. Please type instead.');
      return;
    }
    final current = _text.text.trim();
    _textBeforeVoice = current == _exampleText ? '' : current;
    setState(() {
      _voiceStarting = false;
      _listening = true;
    });
    await _speech.start(
      _language,
      SpeechCallbacks(
        onResult: (words, _) {
          if (!mounted) return;
          _text.text = [_textBeforeVoice, words.trim()]
              .where((s) => s.isNotEmpty)
              .join(' ');
          _text.selection = TextSelection.collapsed(offset: _text.text.length);
        },
        onError: (message) {
          if (mounted) showStaffMessage(context, message);
        },
        onDone: () {
          if (mounted) setState(() => _listening = false);
        },
      ),
    );
  }

  Future<void> _suggest() async {
    final services = AppScope.of(context);
    setState(() => _loading = true);
    final List<EventProposal> result;
    try {
      result = await services.aiDrafts.propose(
        _text.text,
        today: widget.day,
        library: services.library.activities,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showStaffMessage(context,
          e is EventDraftException ? e.message : 'Suggestions failed. Please try again.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _proposals = [for (var i = 0; i < result.length; i++) (i, result[i])];
      _loading = false;
    });
  }

  void _createDrafts() {
    final services = AppScope.of(context);
    final store = services.schedule;
    final drafts = [
      for (final (_, p) in _proposals!)
        ScheduledEvent(
          id: store.newId('evt'),
          title: p.title,
          category:
              p.libraryMatch?.category ?? p.category ?? ActivityCategory.personal,
          start: p.start,
          end: p.end,
          visual: p.libraryMatch?.visual ??
              p.visual ??
              const VisualRef(symbol: 'event'),
          placeId: p.libraryMatch?.defaultPlaceId,
          contactId: p.libraryMatch?.defaultContactId,
          whatToBring: p.libraryMatch?.whatToBring ?? const [],
          instructions: p.libraryMatch?.instructions,
          libraryActivityId: p.libraryMatch?.id,
          assignedParticipantIds: _participants,
        ),
    ];
    store.saveDrafts(drafts);
    Navigator.pop(context);
    showStaffMessage(context,
        '${drafts.length} draft activities created. Review, preview and publish them in Schedule.');
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final palette = context.palette;
    final proposals = _proposals;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: palette.brand),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text('Build with AI',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            'Your text is sent to the AI service, which suggests activities. '
            'Do not enter names or health details. Nothing is published until you review and publish it.',
            style: TextStyle(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLines: 3,
                  readOnly: _listening,
                  decoration: const InputDecoration(
                    labelText: 'Describe the activities',
                    hintText: 'e.g. Tomorrow woodworking at 9, lunch at 12 …',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Column(
                children: [
                  IconButton.filledTonal(
                    key: const Key('voice-input'),
                    tooltip: _listening ? 'Stop dictation' : 'Dictate',
                    iconSize: 28,
                    onPressed: _voiceStarting || _loading ? null : _toggleVoice,
                    isSelected: _listening,
                    icon: const Icon(Icons.mic_none_rounded),
                    selectedIcon: const Icon(Icons.stop_rounded),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  _LanguageToggle(
                    value: _language,
                    onChanged: _listening
                        ? null
                        : (l) => setState(() => _language = l),
                  ),
                ],
              ),
            ],
          ),
          if (_listening) ...[
            const SizedBox(height: AppSpace.sm),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, color: palette.brand),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Listening (${_language.label}) … tap ■ to stop',
                      style: TextStyle(
                          color: palette.brand, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: AppSpace.xs),
          Text(
            'Voice is turned into text by this device\'s speech service; '
            'no audio is sent to our servers. Check the text before suggesting.',
            style: TextStyle(color: palette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppSpace.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _loading || _listening || _voiceStarting ? null : _suggest,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined),
              label: const Text('Suggest activities'),
            ),
          ),
          if (proposals != null) ...[
            const SizedBox(height: AppSpace.lg),
            Text('Review suggestions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.sm),
            if (proposals.isEmpty)
              Text('No activities with a time were found. Try "lunch at 12".',
                  style: TextStyle(color: palette.textSecondary)),
            for (var i = 0; i < proposals.length; i++)
              _ProposalRow(
                key: ValueKey(proposals[i].$1),
                proposal: proposals[i].$2,
                onChanged: (p) =>
                    setState(() => _proposals![i] = (proposals[i].$1, p)),
                onRemove: () => setState(() => _proposals!.removeAt(i)),
              ),
            const SizedBox(height: AppSpace.lg),
            Text('Assign to', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.sm),
            ParticipantSelector(
              participants: services.participants.all,
              selected: _participants,
              onChanged: (s) => setState(() => _participants = s),
            ),
            const SizedBox(height: AppSpace.xl),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: proposals.isEmpty || _participants.isEmpty
                    ? null
                    : _createDrafts,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Create drafts'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// DE / EN choice for dictation.
class _LanguageToggle extends StatelessWidget {
  final SpeechLanguage value;
  final ValueChanged<SpeechLanguage>? onChanged;

  const _LanguageToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SpeechLanguage>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        for (final l in SpeechLanguage.values)
          ButtonSegment(
            value: l,
            label: Text(l.label),
            tooltip: l == SpeechLanguage.german ? 'German' : 'English',
          ),
      ],
      selected: {value},
      onSelectionChanged:
          onChanged == null ? null : (s) => onChanged!(s.first),
    );
  }
}

class _ProposalRow extends StatefulWidget {
  final EventProposal proposal;
  final ValueChanged<EventProposal> onChanged;
  final VoidCallback onRemove;

  const _ProposalRow({
    super.key,
    required this.proposal,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_ProposalRow> createState() => _ProposalRowState();
}

class _ProposalRowState extends State<_ProposalRow> {
  late final _title = TextEditingController(text: widget.proposal.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Wrap(
          spacing: AppSpace.md,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (t) => widget.onChanged(p.copyWith(title: t)),
              ),
            ),
            Text(TimeFormat.shortWeekday(p.start)),
            TimeField(
              label: 'Start',
              value: p.start,
              onChanged: (t) =>
                  widget.onChanged(p.copyWith(start: t, end: t.add(p.end.difference(p.start)))),
            ),
            TimeField(
              label: 'End',
              value: p.end,
              onChanged: (t) => widget.onChanged(p.copyWith(end: t)),
            ),
            if (p.libraryMatch != null)
              Chip(
                avatar: const Icon(Icons.collections_bookmark_outlined, size: 16),
                label: Text('Library: ${p.libraryMatch!.name}'),
              ),
            IconButton(
              tooltip: 'Remove suggestion',
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
