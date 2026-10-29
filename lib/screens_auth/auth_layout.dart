import 'package:flutter/material.dart';

import '../theme.dart';

/// Calm centred layout for authentication screens.
class AuthLayout extends StatelessWidget {
  final Widget child;

  const AuthLayout({super.key, required this.child});

  static const double _maxWidth = 440;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _ProductMark(),
                  const SizedBox(height: AppSpace.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.xl),
                      child: child,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 16, color: palette.textSecondary),
                      const SizedBox(width: AppSpace.xs),
                      Flexible(
                        child: Text(
                          'Prototype – demo accounts only',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo placeholder + product name.
class _ProductMark extends StatelessWidget {
  const _ProductMark();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      header: true,
      label: 'BBW Visual Planner, Caritas-Don Bosco Würzburg',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.brand,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(Icons.view_day_rounded, color: palette.onBrand, size: 40),
          ),
          const SizedBox(height: AppSpace.md),
          Text('BBW Visual Planner',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpace.xs),
          Text('Caritas-Don Bosco · Würzburg',
              style: TextStyle(color: palette.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}
