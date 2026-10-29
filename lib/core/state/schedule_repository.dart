import '../models/schedule_snapshot.dart';

/// Persistence boundary for published schedules.
///
/// The participant feed only depends on `ScheduleStore`, so an offline cache
/// or a Supabase-backed repository can be added here later without touching
/// any participant widget.
abstract class ScheduleRepository {
  Future<ScheduleSnapshot?> loadPublished();
  Future<void> savePublished(ScheduleSnapshot snapshot);
}

/// MOCK: keeps the last published snapshot in memory only.
class InMemoryScheduleRepository implements ScheduleRepository {
  ScheduleSnapshot? _last;

  @override
  Future<ScheduleSnapshot?> loadPublished() async => _last;

  @override
  Future<void> savePublished(ScheduleSnapshot snapshot) async {
    _last = snapshot;
  }
}
