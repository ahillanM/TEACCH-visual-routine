import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/auth/permissions.dart';
import '../../core/models/visual_ref.dart';
import '../../theme.dart';
import '../../widgets/activity_visual.dart';
import '../../widgets/common.dart';
import 'library_add_dialogs.dart';

/// Organisational library: activities, places, people, pictograms.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final canEdit =
        RolePermissions.can(services.auth.user, Permission.manageLibrary);
    final library = services.library;

    return DefaultTabController(
      length: 4,
      child: ListenableBuilder(
        listenable: library,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Library',
                subtitle: canEdit
                    ? 'Reusable activities, places and people'
                    : 'Reusable resources (editing requires the admin role)',
                actions: [
                  if (canEdit)
                    FilledButton.icon(
                      onPressed: () => showAddLibraryItemDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                    ),
                ],
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Activities'),
                  Tab(text: 'Places'),
                  Tab(text: 'People'),
                  Tab(text: 'Pictograms'),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: TabBarView(
                  children: [
                    _ItemGrid(items: [
                      for (final a in library.activities)
                        _Item(a.name, a.participantDescription.isEmpty
                            ? CategoryStyle.of(a.category, context.palette).label
                            : a.participantDescription,
                            a.visual, CategoryStyle.of(a.category, context.palette).color),
                    ]),
                    _ItemGrid(items: [
                      for (final p in library.places)
                        _Item(p.name, p.participantDescription, p.visual,
                            context.palette.brand),
                    ]),
                    _ItemGrid(items: [
                      for (final c in library.contacts)
                        _Item(c.name, c.roleLabel, c.visual,
                            context.palette.brand),
                    ]),
                    _ItemGrid(items: [
                      for (final v in {
                        for (final a in library.activities)
                          if (a.visual.pictogramUrl != null)
                            a.visual.pictogramUrl!: a.visual,
                      }.values)
                        _Item(v.symbol, 'ARASAAC pictogram', v,
                            context.palette.brand),
                    ]),
                  ],
                ),
              ),
              Text(
                'Pictograms: ARASAAC (CC BY-NC-SA), Government of Aragón.',
                style: TextStyle(
                    color: context.palette.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item {
  final String title;
  final String subtitle;
  final VisualRef visual;
  final Color accent;
  const _Item(this.title, this.subtitle, this.visual, this.accent);
}

class _ItemGrid extends StatelessWidget {
  final List<_Item> items;
  const _ItemGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here yet');
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 220,
        crossAxisSpacing: AppSpace.md,
        mainAxisSpacing: AppSpace.md,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ActivityVisual(
                  visual: item.visual,
                  accent: item.accent,
                  semanticLabel: item.title,
                  height: 110,
                  showPhoto: false,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.palette.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
