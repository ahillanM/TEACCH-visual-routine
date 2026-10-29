import '../core/ai/event_draft_generator.dart';
import '../core/auth/auth_controller.dart';
import '../core/auth/auth_service.dart';
import '../core/data/mock_library.dart';
import '../core/data/mock_participants.dart';
import '../core/data/mock_routines.dart';
import '../core/data/mock_schedules.dart';
import '../core/logic/change_planner.dart';
import '../core/models/schedule_snapshot.dart';
import '../core/models/support_request.dart';
import '../core/state/library_store.dart';
import '../core/state/participant_directory.dart';
import '../core/state/routine_store.dart';
import '../core/state/schedule_repository.dart';
import '../core/state/schedule_store.dart';
import '../core/state/support_request_store.dart';
import '../core/time/clock.dart';
import '../core/time/time_format.dart';

/// Everything the UI depends on, wired in one place.
///
/// To move from the prototype to real services, replace the mock
/// implementations in [AppServices.demo] (auth, repository, AI generator);
/// no screen needs to change.
class AppServices {
  final DemoClock clock;
  final AuthController auth;
  final ScheduleStore schedule;
  final ParticipantDirectory participants;
  final SupportRequestStore support;
  final LibraryStore library;
  final RoutineStore routines;
  final EventDraftGenerator aiDrafts;

  AppServices({
    required this.clock,
    required this.auth,
    required this.schedule,
    required this.participants,
    required this.support,
    required this.library,
    required this.routines,
    required this.aiDrafts,
  });

  /// Demo start time: during the morning workshop, so the core scenario
  /// (cancel workshop → free time) can be shown immediately.
  static const int demoStartHour = 9;
  static const int demoStartMinute = 40;

  /// MOCK wiring with fictional demo data.
  factory AppServices.demo({DemoClock? clock}) {
    final demoClock =
        clock ?? DemoClock(startHour: demoStartHour, startMinute: demoStartMinute);
    final today = TimeFormat.dateOnly(demoClock.now());

    final weekEvents = buildMockWeek(today);
    final initial = ScheduleSnapshot(
      version: 1,
      publishedAt: today,
      events: {for (final e in weekEvents) e.id: e},
    );
    final schedule = ScheduleStore(
      repository: InMemoryScheduleRepository(),
      initial: initial,
    );

    // Seeded, not-yet-acknowledged changes (location change + replacement).
    schedule.publish(
      upserts: seedLocationChange(initial.events, today),
      publishedBy: 'Tom (Social work)',
    );
    final sportsPlan = ChangePlanner.planCancellation(
      base: schedule.published,
      eventId: mockEventId(MockEventKeys.sports, today),
      option: ReplacementInstead(seedSportsReplacement(today)),
      newId: () => schedule.newId('evt'),
    );
    schedule.publish(
      upserts: sportsPlan.upserts,
      publishedBy: 'Mr. Klein (Residential staff)',
      outcome: sportsPlan.outcome,
      cancelledEventId: sportsPlan.cancelled.id,
    );

    final support = SupportRequestStore([
      SupportRequest(
        id: 'support-seed-1',
        participantId: MockParticipantIds.mia,
        reason: SupportReason.dontKnowWhereToGo,
        createdAt: DateTime(today.year, today.month, today.day, 8, 52),
        currentActivityTitle: 'Bus to BBW',
      ),
    ]);

    return AppServices(
      clock: demoClock,
      auth: AuthController(MockAuthService(accounts: {
        for (final u in mockUsers)
          u.username: (password: mockPassword, user: u),
      })),
      schedule: schedule,
      participants: ParticipantDirectory(mockParticipants),
      support: support,
      library: LibraryStore(
        activities: mockLibraryActivities,
        places: mockPlaces,
        contacts: mockContacts,
      ),
      routines: RoutineStore(mockRoutines),
      aiDrafts: const MockEventDraftGenerator(),
    );
  }

  void dispose() {
    clock.dispose();
    auth.dispose();
    schedule.dispose();
    participants.dispose();
    support.dispose();
    library.dispose();
    routines.dispose();
  }
}
