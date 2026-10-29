import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/activity_category.dart';
import '../../core/models/library_items.dart';
import '../../core/models/visual_ref.dart';
import '../../theme.dart';
import '../../widgets/symbol_icons.dart';

enum _ItemType { activity, place, person }

/// Adds an activity, place or person to the library.
Future<void> showAddLibraryItemDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _AddDialog());
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  _ItemType _type = _ItemType.activity;
  final _name = TextEditingController();
  final _description = TextEditingController();
  ActivityCategory _category = ActivityCategory.work;
  String _symbol = 'carpentry';
  String? _placeId;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final library = AppScope.of(context).library;
    final id = '${_type.name}-${DateTime.now().microsecondsSinceEpoch}';
    final visual = VisualRef(symbol: _symbol);
    switch (_type) {
      case _ItemType.activity:
        library.addActivity(LibraryActivity(
          id: id,
          name: name,
          category: _category,
          visual: visual,
          participantDescription: _description.text.trim(),
          defaultPlaceId: _placeId,
        ));
      case _ItemType.place:
        library.addPlace(Place(
          id: id,
          name: name,
          participantDescription: _description.text.trim(),
          visual: visual,
        ));
      case _ItemType.person:
        library.addContact(Contact(
          id: id,
          name: name,
          roleLabel: _description.text.trim(),
          visual: const VisualRef(symbol: 'person'),
        ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return AlertDialog(
      title: const Text('Add to library'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_ItemType>(
                segments: const [
                  ButtonSegment(value: _ItemType.activity, label: Text('Activity')),
                  ButtonSegment(value: _ItemType.place, label: Text('Place')),
                  ButtonSegment(value: _ItemType.person, label: Text('Person')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: _type == _ItemType.person
                      ? 'Role (e.g. Trainer)'
                      : 'Short participant-facing description',
                ),
              ),
              if (_type == _ItemType.activity) ...[
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<ActivityCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in ActivityCategory.values)
                      DropdownMenuItem(
                          value: c, child: Text(CategoryStyle.of(c).label)),
                  ],
                  onChanged: (c) => setState(() => _category = c ?? _category),
                ),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<String?>(
                  initialValue: _placeId,
                  decoration: const InputDecoration(labelText: 'Default place'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final p in library.places)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (id) => setState(() => _placeId = id),
                ),
              ],
              if (_type != _ItemType.person) ...[
                const SizedBox(height: AppSpace.md),
                const Text('Symbol'),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: [
                    for (final key in SymbolIcons.keys)
                      ChoiceChip(
                        label: Icon(SymbolIcons.of(key), size: 20),
                        tooltip: key,
                        selected: key == _symbol,
                        onSelected: (_) => setState(() => _symbol = key),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Photo upload is a future feature (needs approved storage).',
                  style: TextStyle(
                      color: context.palette.textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}
