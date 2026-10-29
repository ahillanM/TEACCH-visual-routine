import 'package:bbw_visual_routine/core/ai/event_draft_generator.dart';
import 'package:bbw_visual_routine/core/data/mock_library.dart';
import 'package:bbw_visual_routine/core/logic/free_time_planner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixtures.dart';

void main() {
  group('FreeTimePlanner', () {
    test('splits plain text into capitalised ideas', () {
      expect(
        FreeTimePlanner.splitIdeas(
          'listen to music, then read a book and rest',
        ),
        ['Listen to music', 'Read a book', 'Rest'],
      );
    });

    test('without AI results, ideas are laid out inside the window', () {
      final plan = FreeTimePlanner.fromText(
        text: 'listen to music, read a book',
        aiProposals: const [],
        from: at(11),
        until: at(11, 30),
        library: mockLibraryActivities,
      );
      expect(plan.map((p) => p.title), ['Listen to music', 'Read a book']);
      expect(plan.first.start, at(11));
      expect(plan.last.end.isAfter(at(11, 30)), isFalse);
    });

    test('AI proposals are kept in order but never leave the window', () {
      final plan = FreeTimePlanner.fromText(
        text: 'ignored',
        aiProposals: [
          EventProposal(title: 'walk', start: at(15), end: at(16)),
          EventProposal(title: 'snack', start: at(16), end: at(16, 30)),
        ],
        from: at(12, 15),
        until: at(13),
        library: mockLibraryActivities,
      );
      expect(plan.map((p) => p.title), ['Walk', 'Snack']);
      expect(plan.first.start, at(12, 15));
      expect(plan.last.end.isAfter(at(13)), isFalse);
    });

    test('too little time gives an empty plan', () {
      final plan = FreeTimePlanner.fromText(
        text: 'rest',
        aiProposals: const [],
        from: at(11),
        until: at(11, 5),
        library: mockLibraryActivities,
      );
      expect(plan, isEmpty);
    });

    test('start is never in the past and is rounded to 5 minutes', () {
      expect(FreeTimePlanner.earliestStart(at(11), at(10)), at(11));
      expect(FreeTimePlanner.earliestStart(at(11), at(11, 12)), at(11, 15));
    });
  });

  group('participant adds to free time', () {
    test('appears in their schedule without a "plan changed" notice', () {
      final store = freshStore();
      final proposal = FreeTimePlanner.fromText(
        text: 'rest',
        aiProposals: const [],
        from: at(12, 15),
        until: at(13),
        library: mockLibraryActivities,
      ).single;

      store.addParticipantEvents(
        participantId: lena,
        participantName: 'Lena',
        events: [
          FreeTimePlanner.toEvent(proposal, id: 'own-1', participantId: lena),
        ],
      );

      final added = store.published['own-1']!;
      expect(added.assignedParticipantIds, {lena});
      expect(added.isParticipantOwned, isTrue);
      expect(store.pendingChangesFor(lena), isEmpty);
      expect(store.pendingChangesFor(jonas), isEmpty);
    });
  });
}
