import 'package:flutter/material.dart';

/// Maps `VisualRef.symbol` keys to icons. Used as the fallback whenever a
/// pictogram or photo cannot be shown (offline, missing asset).
abstract final class SymbolIcons {
  static const _icons = <String, IconData>{
    'carpentry': Icons.carpenter_outlined,
    'metal': Icons.precision_manufacturing_outlined,
    'dining': Icons.restaurant_outlined,
    'breakfast': Icons.free_breakfast_outlined,
    'meal': Icons.restaurant_outlined,
    'study': Icons.menu_book_outlined,
    'therapy': Icons.accessibility_new_outlined,
    'room': Icons.meeting_room_outlined,
    'bus': Icons.directions_bus_outlined,
    'kitchen': Icons.kitchen_outlined,
    'sleep': Icons.bed_outlined,
    'office': Icons.work_outline,
    'games': Icons.extension_outlined,
    'sport': Icons.sports_soccer_outlined,
    'coaching': Icons.forum_outlined,
    'relax': Icons.spa_outlined,
    'teeth': Icons.clean_hands_outlined,
    'meeting': Icons.groups_outlined,
    'wake': Icons.alarm_outlined,
    'shower': Icons.shower_outlined,
    'dress': Icons.checkroom_outlined,
    'person': Icons.person_outline,
    'free': Icons.spa_outlined,
    'waiting': Icons.hourglass_empty_rounded,
    'done': Icons.nights_stay_outlined,
    'music': Icons.headphones_outlined,
    'walk': Icons.directions_walk_outlined,
    'phone': Icons.call_outlined,
    'read': Icons.auto_stories_outlined,
    'art': Icons.palette_outlined,
  };

  static IconData of(String symbol) => _icons[symbol] ?? Icons.event_outlined;

  static List<String> get keys => _icons.keys.toList();
}
