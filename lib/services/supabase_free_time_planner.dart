import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ai/event_draft_generator.dart';
import '../core/logic/free_time.dart';
import '../core/planning/free_time_planner.dart';
import 'backend_event_draft_generator.dart';

/// [FreeTimeBackend] backed by Supabase (availability + saving) and the
/// existing FastAPI AI endpoint (drafts only).
///
/// * `get_planning_day` returns the window and busy periods computed on the
///   server (official activities incl. staff drafts, personal activities,
///   staff restrictions).
/// * The AI receives those busy periods as `existingItems` so it can flag
///   conflicts, but it never decides availability: [FreeTimeRules] checks
///   the drafts here and `save_personal_free_time_plan` checks them again
///   atomically on the server.
class SupabaseFreeTimeBackend implements FreeTimeBackend {
  final SupabaseClient db;
  final BackendEventDraftGenerator ai;

  /// Called after a successful save (e.g. reload the schedule).
  final Future<void> Function() onSaved;

  SupabaseFreeTimeBackend({
    required this.db,
    required this.ai,
    required this.onSaved,
  });

  @override
  Future<PlanningDay> loadDay(DateTime date) async {
    try {
      final json = await db.rpc('get_planning_day', params: {'p_date': _date(date)});
      return PlanningDay.fromJson(date, (json as Map).cast<String, dynamic>());
    } on PostgrestException catch (e) {
      throw PlanSaveException(e.message == 'date_out_of_range'
          ? 'You can plan from today up to 30 days ahead.'
          : 'Your free time could not be loaded. Please try again.');
    } catch (_) {
      throw const PlanSaveException('No connection. Please try again.');
    }
  }

  @override
  Future<List<DraftActivity>> suggest(String text, PlanningDay day) async {
    final Map<String, dynamic> body;
    try {
      body = await ai.generateRoutine(
        instruction: text,
        referenceDate: DateTime.now(), // so "Saturday" / "tomorrow" resolve
        requesterRole: 'participant',
        existingItems: [
          for (final b in day.busy)
            {
              'title': b.title,
              'date': _date(day.date),
              'startTime': formatHm(b.start),
              'endTime': formatHm(b.end),
            },
        ],
      );
    } on EventDraftException catch (e) {
      throw PlanSaveException(e.message);
    }

    final items = (body['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final drafts = await Future.wait([
      for (final m in items) _toDraft(m, day),
    ]);
    if (drafts.isEmpty) {
      final refused = [
        for (final i in (body['issues'] as List? ?? const []))
          if ((i as Map)['code'] == 'unsupported_request') i['message'] as String,
      ];
      throw PlanSaveException(refused.isNotEmpty
          ? 'I can only add new activities in your free time.'
          : 'I could not find activities in that. Try: "football at 2 pm for one hour".');
    }
    return drafts;
  }

  Future<DraftActivity> _toDraft(Map<String, dynamic> m, PlanningDay day) async {
    final date = DateTime.tryParse((m['date'] as String?) ?? '');
    final sameDay = date == null ||
        (date.year == day.date.year && date.month == day.date.month && date.day == day.date.day);
    final visual = await ai.visualFor(m['pictogramKeyword'] as String?);
    final start = m['startTime'] as String?;
    final end = m['endTime'] as String?;
    return DraftActivity(
      title: (m['title'] as String).trim(),
      start: start == null ? null : parseHm(start),
      end: end == null ? null : parseHm(end), // never invented
      iconKey: visual.symbol,
      pictogramUrl: visual.pictogramUrl,
      otherDay: sameDay ? null : date,
    );
  }

  @override
  Future<void> save(PlanningDay day, List<DraftActivity> drafts) async {
    if (!FreeTimeRules.canSave(day, drafts)) {
      throw const PlanSaveException('Please fix the marked activities first.');
    }
    try {
      await db.rpc('save_personal_free_time_plan', params: {
        'p_date': _date(day.date),
        'p_activities': [
          for (final d in drafts)
            {
              'title': d.title.trim(),
              'startTime': formatHm(d.start!),
              'endTime': formatHm(d.end!),
              'iconKey': d.iconKey,
              if (d.pictogramUrl != null) 'pictogramUrl': d.pictogramUrl,
            },
        ],
      });
    } on PostgrestException catch (e) {
      throw _describe(e);
    } catch (_) {
      throw const PlanSaveException('No connection. Your plan was not saved.');
    }
    await onSaved();
  }

  static PlanSaveException _describe(PostgrestException e) {
    switch (e.message) {
      case 'plan_conflict':
        final problems = <int, String>{};
        try {
          for (final c in jsonDecode(e.details?.toString() ?? '[]') as List) {
            final m = c as Map;
            problems[m['index'] as int] = m['with'] != null
                ? 'Now taken by "${m['with']}". Choose another time.'
                : 'This time is not possible any more.';
          }
        } catch (_) {}
        return PlanSaveException(
            'Something changed in the meantime. Nothing was saved; please check the marked times.',
            problems);
      case 'day_not_plannable':
        return PlanSaveException(e.details?.toString() ?? 'This day cannot be planned yet. Please ask staff.');
      case 'date_out_of_range':
        return const PlanSaveException('You can plan from today up to 30 days ahead.');
      case 'not_allowed':
        return const PlanSaveException('Only participants can plan their own free time.');
    }
    return const PlanSaveException('Your plan could not be saved. Please try again.');
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
