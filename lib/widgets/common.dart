import 'package:flutter/material.dart';

import '../theme.dart';

/// Small shared layout primitives used by both UIs.

/// Icon + text row for "where / who / what to bring" information.
class InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? semanticPrefix;
  final TextStyle? style;

  const InfoLine({
    super.key,
    required this.icon,
    required this.text,
    this.semanticPrefix,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textStyle = style ??
        Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: palette.textSecondary, fontWeight: FontWeight.w600);
    return Semantics(
      label: semanticPrefix == null ? null : '$semanticPrefix: $text',
      excludeSemantics: semanticPrefix != null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.xxs),
            child: Icon(icon, size: 20, color: palette.textSecondary),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(text, style: textStyle)),
        ],
      ),
    );
  }
}

/// Uppercase section heading.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Page title + optional subtitle and actions (staff pages).
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Wrap(
        spacing: AppSpace.lg,
        runSpacing: AppSpace.md,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.headlineSmall),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(subtitle!,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: context.palette.textSecondary)),
              ],
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: actions),
        ],
      ),
    );
  }
}

/// Intentional empty / error state – never a blank screen.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: palette.textSecondary),
            const SizedBox(height: AppSpace.md),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary)),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Calm notice banner (schedule updates, information). Never alarm-styled.
class NoticeBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final VoidCallback? onTap;

  const NoticeBanner({
    super.key,
    required this.title,
    this.icon = Icons.info_outline_rounded,
    this.message,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.changeSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.changeBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              Icon(icon, color: palette.changeText, size: 28),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: palette.changeText,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                    if (message != null) ...[
                      const SizedBox(height: AppSpace.xxs),
                      Text(message!,
                          style: TextStyle(
                              color: palette.changeText, fontSize: 15)),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpace.sm),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centers content with a maximum width.
class MaxWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const MaxWidth({super.key, required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
