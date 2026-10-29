import '../models/activity_category.dart';
import '../models/routine_template.dart';
import '../models/scheduled_event.dart';
import '../models/visual_ref.dart';
import 'mock_library.dart';

// DEMO DATA ONLY. Predefined routine modules.

int _m(int hour, [int minute = 0]) => hour * 60 + minute;

const _breakfast = VisualRef.arasaac('breakfast', 4626);
const _meal = VisualRef.arasaac('meal', 4611);
const _bus = VisualRef.arasaac('bus', 2262);
const _carpentry = VisualRef.arasaac('carpentry', 39586);

final mockRoutines = <RoutineTemplate>[
  RoutineTemplate(
    id: 'routine-training-day',
    name: 'Standard Training Day',
    description: 'Breakfast, bus, workshop with lunch break, bus back.',
    steps: [
      RoutineStep(
          title: 'Breakfast',
          category: ActivityCategory.meal,
          startMinuteOfDay: _m(7, 30),
          durationMin: 45,
          visual: _breakfast,
          libraryActivityId: MockActivityIds.breakfast,
          placeId: MockPlaceIds.dining),
      RoutineStep(
          title: 'Bus to BBW',
          category: ActivityCategory.travel,
          kind: EventKind.travel,
          startMinuteOfDay: _m(8, 30),
          durationMin: 20,
          visual: _bus,
          libraryActivityId: MockActivityIds.busToBbw,
          placeId: MockPlaceIds.entrance),
      RoutineStep(
          title: 'Woodwork Workshop',
          category: ActivityCategory.work,
          startMinuteOfDay: _m(9),
          durationMin: 120,
          visual: _carpentry,
          libraryActivityId: MockActivityIds.woodwork,
          placeId: MockPlaceIds.workshopA,
          contactId: MockContactIds.anna),
      RoutineStep(
          title: 'Lunch',
          category: ActivityCategory.meal,
          startMinuteOfDay: _m(11, 30),
          durationMin: 45,
          visual: _meal,
          libraryActivityId: MockActivityIds.lunch,
          placeId: MockPlaceIds.dining),
      RoutineStep(
          title: 'Woodwork Workshop',
          category: ActivityCategory.work,
          startMinuteOfDay: _m(13),
          durationMin: 120,
          visual: _carpentry,
          libraryActivityId: MockActivityIds.woodwork,
          placeId: MockPlaceIds.workshopA,
          contactId: MockContactIds.anna),
      RoutineStep(
          title: 'Bus back to the residence',
          category: ActivityCategory.travel,
          kind: EventKind.travel,
          startMinuteOfDay: _m(15, 15),
          durationMin: 20,
          visual: _bus,
          libraryActivityId: MockActivityIds.busHome,
          placeId: MockPlaceIds.entrance),
    ],
  ),
  RoutineTemplate(
    id: 'routine-morning-residence',
    name: 'Morning Residence Routine',
    description: 'Wake up, shower, get dressed, breakfast.',
    steps: [
      RoutineStep(
          title: 'Wake up',
          category: ActivityCategory.residential,
          startMinuteOfDay: _m(6, 45),
          durationMin: 15,
          visual: VisualRef.arasaac('wake', 8989),
          placeId: MockPlaceIds.residenceRooms),
      RoutineStep(
          title: 'Shower',
          category: ActivityCategory.residential,
          startMinuteOfDay: _m(7),
          durationMin: 15,
          visual: VisualRef.arasaac('shower', 26803),
          placeId: MockPlaceIds.residenceRooms),
      RoutineStep(
          title: 'Get dressed',
          category: ActivityCategory.residential,
          startMinuteOfDay: _m(7, 15),
          durationMin: 15,
          visual: VisualRef.arasaac('dress', 6627),
          placeId: MockPlaceIds.residenceRooms),
      RoutineStep(
          title: 'Breakfast',
          category: ActivityCategory.meal,
          startMinuteOfDay: _m(7, 30),
          durationMin: 45,
          visual: _breakfast,
          libraryActivityId: MockActivityIds.breakfast,
          placeId: MockPlaceIds.dining),
    ],
  ),
  RoutineTemplate(
    id: 'routine-workshop-day',
    name: 'Workshop Day',
    description: 'Two workshop blocks with a lunch break.',
    steps: [
      RoutineStep(
          title: 'Woodwork Workshop',
          category: ActivityCategory.work,
          startMinuteOfDay: _m(9),
          durationMin: 120,
          visual: _carpentry,
          libraryActivityId: MockActivityIds.woodwork,
          placeId: MockPlaceIds.workshopA,
          contactId: MockContactIds.anna),
      RoutineStep(
          title: 'Lunch',
          category: ActivityCategory.meal,
          startMinuteOfDay: _m(11, 30),
          durationMin: 45,
          visual: _meal,
          libraryActivityId: MockActivityIds.lunch,
          placeId: MockPlaceIds.dining),
      RoutineStep(
          title: 'Woodwork Workshop',
          category: ActivityCategory.work,
          startMinuteOfDay: _m(13),
          durationMin: 120,
          visual: _carpentry,
          libraryActivityId: MockActivityIds.woodwork,
          placeId: MockPlaceIds.workshopA,
          contactId: MockContactIds.anna),
    ],
  ),
  RoutineTemplate(
    id: 'routine-evening',
    name: 'Evening Routine',
    description: 'Study time, group dinner, evening routine.',
    steps: [
      RoutineStep(
          title: 'Study Time',
          category: ActivityCategory.residential,
          startMinuteOfDay: _m(16, 45),
          durationMin: 45,
          visual: VisualRef.arasaac('study', 6495),
          libraryActivityId: MockActivityIds.study,
          placeId: MockPlaceIds.study,
          contactId: MockContactIds.schmidt),
      RoutineStep(
          title: 'Group Dinner',
          category: ActivityCategory.meal,
          startMinuteOfDay: _m(18),
          durationMin: 45,
          visual: _meal,
          libraryActivityId: MockActivityIds.dinner,
          placeId: MockPlaceIds.residenceKitchen,
          contactId: MockContactIds.klein),
      RoutineStep(
          title: 'Evening Routine',
          category: ActivityCategory.residential,
          startMinuteOfDay: _m(21),
          durationMin: 30,
          visual: VisualRef.arasaac('teeth', 2326),
          libraryActivityId: MockActivityIds.eveningRoutine,
          placeId: MockPlaceIds.residenceRooms),
    ],
  ),
];
