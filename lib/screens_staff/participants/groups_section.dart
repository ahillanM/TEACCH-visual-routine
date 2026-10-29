import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/participant_group.dart';
import '../../theme.dart';
import '../common/staff_widgets.dart';

/// Staff-made participant groups. Groups appear as one-tap shortcuts
/// wherever staff assign activities or routines.
class GroupsSection extends StatelessWidget {
  const GroupsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final palette = context.palette;
    return ListenableBuilder(
      listenable: Listenable.merge([services.groups, services.participants]),
      builder: (context, _) {
        final groups = services.groups.groups;
        return SectionCard(
          title: 'Groups',
          trailing: TextButton.icon(
            onPressed: () => showGroupEditor(context),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('New Group'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Use groups to assign activities, changes and routines to '
                'several people at once.',
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpace.sm),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  child: Text(
                    'No groups yet.',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                ),
              for (final g in groups)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: palette.brandSoft,
                    child: Icon(Icons.groups_2_outlined, color: palette.brand),
                  ),
                  title: Text(
                    g.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    g.memberIds.isEmpty
                        ? 'No members'
                        : ([
                            for (final id in g.memberIds)
                              services.participants.nameOf(id),
                          ]..sort()).join(', '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit Group',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => showGroupEditor(context, group: g),
                      ),
                      IconButton(
                        tooltip: 'Delete Group',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _confirmDelete(context, g),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ParticipantGroup group,
  ) async {
    final groups = AppScope.of(context).groups;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${group.name}"?'),
        content: const Text(
          'Only the group is deleted. Schedules and participants stay as they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
              foregroundColor: context.palette.onColor(context.palette.danger),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) groups.remove(group.id);
  }
}

/// Create a new group, or edit [group].
Future<void> showGroupEditor(BuildContext context, {ParticipantGroup? group}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _GroupEditorDialog(group: group),
  );
}

class _GroupEditorDialog extends StatefulWidget {
  final ParticipantGroup? group;
  const _GroupEditorDialog({this.group});

  @override
  State<_GroupEditorDialog> createState() => _GroupEditorDialogState();
}

class _GroupEditorDialogState extends State<_GroupEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.group?.name ?? '',
  );
  late Set<String> _members = {...?widget.group?.memberIds};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _members.isNotEmpty;

  void _save() {
    final groups = AppScope.of(context).groups;
    final name = _name.text.trim();
    groups.save(
      widget.group?.copyWith(name: name, memberIds: _members) ??
          ParticipantGroup(id: groups.newId(), name: name, memberIds: _members),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final participants = AppScope.of(context).participants.all;
    return AlertDialog(
      title: Text(widget.group == null ? 'New Group' : 'Edit Group'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. Woodwork Group',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpace.lg),
            const Text(
              'Members',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpace.sm),
            ParticipantSelector(
              participants: participants,
              selected: _members,
              showGroups: false,
              onChanged: (s) => setState(() => _members = s),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _save : null,
          child: const Text('Save Group'),
        ),
      ],
    );
  }
}
