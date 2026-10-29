import '../logic/free_time.dart';

/// A plan could not be saved. [message] is safe to show to the participant;
/// [problems] maps draft index → reason when the server named them.
class PlanSaveException implements Exception {
  final String message;
  final Map<int, String> problems;
  const PlanSaveException(this.message, [this.problems = const {}]);
  @override
  String toString() => message;
}

/// Boundary for "Plan my free time". The UI only talks to this interface;
/// the Supabase + AI implementation lives in `lib/services/`.
abstract class FreeTimePlanner {
  /// Current availability for the signed-in participant on [date].
  Future<PlanningDay> loadDay(DateTime date);

  /// Turns typed or dictated text into DRAFT activities for [day]. Nothing
  /// is saved. Missing times stay missing.
  Future<List<DraftActivity>> suggest(String text, PlanningDay day);

  /// Saves all drafts or none. The server re-checks availability.
  Future<void> save(PlanningDay day, List<DraftActivity> drafts);
}
