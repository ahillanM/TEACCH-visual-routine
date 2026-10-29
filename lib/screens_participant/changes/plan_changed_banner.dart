import 'package:flutter/material.dart';

import '../../widgets/common.dart';

/// "Your plan has changed." – calm, persistent until acknowledged.
class PlanChangedBanner extends StatelessWidget {
  final VoidCallback? onOpen;

  const PlanChangedBanner({super.key, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      button: true,
      child: NoticeBanner(
        icon: Icons.published_with_changes_rounded,
        title: 'Your plan has changed.',
        message: 'Tap to see what is different.',
        onTap: onOpen,
        action: const Icon(Icons.chevron_right_rounded, size: 32),
      ),
    );
  }
}
