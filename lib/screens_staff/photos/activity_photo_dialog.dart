import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_scope.dart';
import '../../core/models/participant.dart';
import '../../core/models/scheduled_event.dart';
import '../../services/task_image_service.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';

/// Guided flow to add, replace or remove the custom photo of [event] for
/// [participant]: choose a source → preview → confirm → saving.
///
/// Nothing is changed until the staff member confirms. If saving fails the
/// preview stays, the activity is untouched and the upload can be retried.
Future<void> showActivityPhotoDialog(
  BuildContext context, {
  required ScheduledEvent event,
  required Participant participant,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ActivityPhotoDialog(event: event, participant: participant),
  );
}

enum _Stage { choose, preview, saving, removing }

class ActivityPhotoDialog extends StatefulWidget {
  final ScheduledEvent event;
  final Participant participant;

  /// Replaceable in tests so no real camera or gallery is needed.
  final Future<Uint8List?> Function(ImageSource source)? pickImage;

  const ActivityPhotoDialog({
    super.key,
    required this.event,
    required this.participant,
    this.pickImage,
  });

  @override
  State<ActivityPhotoDialog> createState() => _ActivityPhotoDialogState();
}

class _ActivityPhotoDialogState extends State<ActivityPhotoDialog> {
  static const double _pickerMaxEdge = 2048;

  final _picker = ImagePicker();
  _Stage _stage = _Stage.choose;
  Uint8List? _picked;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recoverLostPick();
  }

  /// Android may destroy the app while the camera is open; the photo taken
  /// is then delivered when the app restarts.
  Future<void> _recoverLostPick() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (widget.pickImage != null) return;
    try {
      final lost = await _picker.retrieveLostData();
      final file = lost.file;
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _picked = bytes;
          _stage = _Stage.preview;
        });
      }
    } catch (_) {
      // Nothing to recover.
    }
  }

  bool get _hasPhoto =>
      AppScope.of(context).photos!
          .hasPhoto(widget.event.id, widget.participant.id);

  Future<Uint8List?> _pick(ImageSource source) async {
    final custom = widget.pickImage;
    if (custom != null) return custom(source);
    final file = await _picker.pickImage(
      source: source,
      maxWidth: _pickerMaxEdge,
      maxHeight: _pickerMaxEdge,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }

  Future<void> _choose(ImageSource source) async {
    setState(() => _error = null);
    try {
      final bytes = await _pick(source);
      if (bytes == null || !mounted) return; // cancelled
      setState(() {
        _picked = bytes;
        _stage = _Stage.preview;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = source == ImageSource.camera
            ? 'The camera could not be opened. Check the camera permission '
                  'or choose a photo from the gallery.'
            : 'The gallery could not be opened. Check the photo permission '
                  'and try again.',
      );
    }
  }

  Future<void> _confirm() async {
    final photos = AppScope.of(context).photos!;
    final bytes = _picked;
    if (bytes == null) return;
    setState(() {
      _stage = _Stage.saving;
      _error = null;
    });
    try {
      await photos.setActivityPhoto(
        eventId: widget.event.id,
        participantId: widget.participant.id,
        original: bytes,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Photo saved for ${widget.participant.displayName}.'),
        ),
      );
    } on TaskImageException catch (e) {
      _fail(e.message, _Stage.preview);
    } catch (_) {
      _fail('The photo could not be saved. Please try again.', _Stage.preview);
    }
  }

  Future<void> _remove() async {
    final photos = AppScope.of(context).photos!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo?'),
        content: const Text(
          'The activity will show its pictogram again. You can add a new photo later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Photo'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
              foregroundColor: context.palette.onColor(context.palette.danger),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Photo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _stage = _Stage.removing;
      _error = null;
    });
    try {
      await photos.removeActivityPhoto(
        eventId: widget.event.id,
        participantId: widget.participant.id,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Photo removed.')));
    } on TaskImageException catch (e) {
      _fail(e.message, _Stage.choose);
    } catch (_) {
      _fail('The photo could not be removed. Please try again.', _Stage.choose);
    }
  }

  void _fail(String message, _Stage back) {
    if (!mounted) return;
    setState(() {
      _stage = back;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final busy = _stage == _Stage.saving || _stage == _Stage.removing;
    final event = widget.event;
    final name = widget.participant.displayName;

    return AlertDialog(
      title: Text(
        _stage == _Stage.preview || _stage == _Stage.saving
            ? 'Use This Photo?'
            : _hasPhoto
            ? 'Change Photo'
            : 'Add Photo',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${event.title} · $name',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpace.md),
              _preview(palette),
              if (busy) ...[
                const SizedBox(height: AppSpace.md),
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpace.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _stage == _Stage.saving
                        ? 'Preparing and uploading the photo…'
                        : 'Removing the photo…',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpace.md),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: palette.dangerSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: palette.danger),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: palette.danger,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: palette.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_stage == _Stage.preview)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.xs),
                    child: Text(
                      'The activity was not changed.',
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  ),
              ],
              if (_stage == _Stage.choose) ..._sources(),
            ],
          ),
        ),
      ),
      actions: _actions(busy),
    );
  }

  Widget _preview(PlannerPalette palette) {
    final picked = _picked;
    if (picked != null &&
        (_stage == _Stage.preview || _stage == _Stage.saving)) {
      return Semantics(
        image: true,
        label: 'Preview of the new photo for ${widget.event.title}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 220,
            child: Image.memory(picked, fit: BoxFit.cover),
          ),
        ),
      );
    }
    return ActivityVisual(
      visual: widget.event.visual,
      accent: CategoryStyle.of(widget.event.category, palette).color,
      semanticLabel: widget.event.title,
      height: 180,
    );
  }

  List<Widget> _sources() => [
    const SizedBox(height: AppSpace.lg),
    _SourceButton(
      icon: Icons.photo_camera_outlined,
      label: 'Take Photo',
      onTap: () => _choose(ImageSource.camera),
    ),
    const SizedBox(height: AppSpace.sm),
    _SourceButton(
      icon: Icons.photo_library_outlined,
      label: 'Choose from Gallery',
      onTap: () => _choose(ImageSource.gallery),
    ),
    if (_hasPhoto) ...[
      const SizedBox(height: AppSpace.sm),
      _SourceButton(
        icon: Icons.interests_outlined,
        label: 'Use Pictogram Instead',
        onTap: _remove,
      ),
    ],
    const SizedBox(height: AppSpace.md),
    Text(
      'To pick a different pictogram, edit the activity.',
      style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
    ),
  ];

  List<Widget> _actions(bool busy) => switch (_stage) {
    _Stage.choose => [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
    _Stage.preview || _Stage.saving => [
      TextButton(
        onPressed: busy
            ? null
            : () => setState(() {
                _stage = _Stage.choose;
                _picked = null;
                _error = null;
              }),
        child: const Text('Choose Another'),
      ),
      FilledButton.icon(
        onPressed: busy ? null : _confirm,
        icon: const Icon(Icons.check_rounded),
        label: Text(_error == null ? 'Use This Photo' : 'Try Again'),
      ),
    ],
    _Stage.removing => const [],
  };
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}
