import 'package:flutter/material.dart';

import '../theme.dart';

/// A small pill with icon + text. Status is never conveyed by colour alone.
class StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  /// Filled (strong) vs. tinted (quiet) appearance.
  final bool filled;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? context.palette.onColor(color) : color;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm + AppSpace.xxs, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 3, color: fg),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
