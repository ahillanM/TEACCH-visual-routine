import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../services/speech_input.dart';

/// Microphone + DE/EN switch that dictates into [controller].
///
/// Uses the shared [SpeechInput] (device speech recognition). It only fills
/// the text field; it never submits anything. The text stays editable.
class DictationButton extends StatefulWidget {
  final TextEditingController controller;

  /// Called when listening starts or stops (e.g. to show an indicator and
  /// block "Make a plan" while listening).
  final ValueChanged<bool>? onListeningChanged;

  final ValueChanged<String>? onMessage;

  const DictationButton({
    super.key,
    required this.controller,
    this.onListeningChanged,
    this.onMessage,
  });

  @override
  State<DictationButton> createState() => DictationButtonState();
}

class DictationButtonState extends State<DictationButton> {
  late final SpeechInput _speech = AppScope.of(context).speech;
  late SpeechLanguage language = SpeechLanguage.forLocale(
      WidgetsBinding.instance.platformDispatcher.locale);
  bool _starting = false;
  bool listening = false;
  String _before = '';

  @override
  void dispose() {
    if (listening) _speech.cancel();
    super.dispose();
  }

  void _message(String text) {
    if (widget.onMessage != null) {
      widget.onMessage!(text);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _setListening(bool value) {
    if (!mounted) return;
    setState(() => listening = value);
    widget.onListeningChanged?.call(value);
  }

  Future<void> toggle() async {
    if (listening) {
      await _speech.stop();
      return;
    }
    if (_starting || _speech.isListening) return;
    setState(() => _starting = true);
    final problem = await _speech.initialize();
    if (!mounted) return;
    setState(() => _starting = false);
    if (problem != null) {
      _message(problem == SpeechUnavailable.permissionDenied
          ? 'The microphone is not allowed. You can type instead.'
          : 'Speaking is not available on this phone. You can type instead.');
      return;
    }
    _before = widget.controller.text.trim();
    _setListening(true);
    await _speech.start(
      language,
      SpeechCallbacks(
        onResult: (words, _) {
          if (!mounted) return;
          final c = widget.controller;
          c.text = [_before, words.trim()].where((s) => s.isNotEmpty).join(' ');
          c.selection = TextSelection.collapsed(offset: c.text.length);
        },
        onError: (m) {
          if (mounted) _message(m);
        },
        onDone: () => _setListening(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: const Key('dictation'),
          tooltip: listening ? 'Stop speaking' : 'Speak',
          iconSize: 32,
          onPressed: _starting ? null : toggle,
          isSelected: listening,
          icon: const Icon(Icons.mic_none_rounded),
          selectedIcon: const Icon(Icons.stop_rounded),
        ),
        const SizedBox(height: 4),
        SegmentedButton<SpeechLanguage>(
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
          selected: {language},
          onSelectionChanged:
              listening ? null : (s) => setState(() => language = s.first),
        ),
      ],
    );
  }
}
