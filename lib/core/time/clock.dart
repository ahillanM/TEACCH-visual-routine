import 'dart:async';

import 'package:flutter/foundation.dart';

/// Source of "now" for all schedule logic. Never call `DateTime.now()`
/// directly in schedule code – inject a [Clock] so behaviour is testable.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock that always returns the same instant (for tests).
class FixedClock implements Clock {
  final DateTime instant;
  const FixedClock(this.instant);

  @override
  DateTime now() => instant;
}

/// DEMO ONLY: a real-time clock that can be shifted to any time of today so
/// the prototype can be demonstrated at any hour (e.g. jump to "during the
/// workshop"). Notifies listeners periodically so progress indicators move.
///
/// In production this is replaced by [SystemClock] plus a ticker.
class DemoClock extends ChangeNotifier implements Clock {
  static const Duration tickInterval = Duration(seconds: 20);

  Duration _offset = Duration.zero;
  Timer? _timer;

  /// [ticking] can be disabled in tests so no periodic timer is left running.
  DemoClock({int? startHour, int startMinute = 0, bool ticking = true}) {
    if (startHour != null) setTimeOfDay(startHour, startMinute);
    if (ticking) {
      _timer = Timer.periodic(tickInterval, (_) => notifyListeners());
    }
  }

  @override
  DateTime now() => DateTime.now().add(_offset);

  bool get isShifted => _offset != Duration.zero;

  /// Moves "now" to [hour]:[minute] today; time keeps running from there.
  void setTimeOfDay(int hour, int minute) {
    final real = DateTime.now();
    final target = DateTime(real.year, real.month, real.day, hour, minute);
    _offset = target.difference(real);
    notifyListeners();
  }

  void shift(Duration by) {
    _offset += by;
    notifyListeners();
  }

  void useRealTime() {
    _offset = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
