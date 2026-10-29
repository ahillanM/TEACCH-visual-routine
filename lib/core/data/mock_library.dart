import '../models/activity_category.dart';
import '../models/library_items.dart';
import '../models/visual_ref.dart';

// DEMO DATA ONLY. All names are fictional. Pictograms: ARASAAC (CC BY-NC-SA),
// Government of Aragón, https://arasaac.org.

abstract final class MockPlaceIds {
  static const workshopA = 'place-workshop-a';
  static const workshopB = 'place-workshop-b';
  static const dining = 'place-dining';
  static const study = 'place-study';
  static const therapy = 'place-therapy';
  static const room104 = 'place-room-104';
  static const entrance = 'place-entrance';
  static const residenceKitchen = 'place-residence-kitchen';
  static const residenceRooms = 'place-residence-rooms';
  static const office = 'place-office';
  static const common = 'place-common';
  static const sports = 'place-sports';
}

abstract final class MockContactIds {
  static const anna = 'contact-anna';
  static const weber = 'contact-weber';
  static const schmidt = 'contact-schmidt';
  static const tom = 'contact-tom';
  static const okafor = 'contact-okafor';
  static const klein = 'contact-klein';
}

abstract final class MockActivityIds {
  static const woodwork = 'act-woodwork';
  static const metalwork = 'act-metalwork';
  static const breakfast = 'act-breakfast';
  static const lunch = 'act-lunch';
  static const dinner = 'act-dinner';
  static const busToBbw = 'act-bus-to-bbw';
  static const busHome = 'act-bus-home';
  static const study = 'act-study';
  static const physio = 'act-physio';
  static const coaching = 'act-coaching';
  static const sports = 'act-sports';
  static const boardGames = 'act-board-games';
  static const quietTime = 'act-quiet-time';
  static const eveningRoutine = 'act-evening-routine';
  static const groupMeeting = 'act-group-meeting';
}

const mockPlaces = <Place>[
  Place(
    id: MockPlaceIds.workshopA,
    name: 'Workshop A',
    participantDescription: 'Woodwork workshop, ground floor, building 2.',
    visual: VisualRef.arasaac('carpentry', 39586),
  ),
  Place(
    id: MockPlaceIds.workshopB,
    name: 'Workshop B',
    participantDescription: 'Metal workshop, ground floor, building 3.',
    visual: VisualRef.arasaac('metal', 37698),
  ),
  Place(
    id: MockPlaceIds.dining,
    name: 'Dining Hall',
    participantDescription: 'Main building, next to the entrance.',
    visual: VisualRef.arasaac('dining', 5970),
  ),
  Place(
    id: MockPlaceIds.study,
    name: 'Study Room 2',
    participantDescription: 'Residence, first floor, quiet room.',
    visual: VisualRef.arasaac('study', 6495),
  ),
  Place(
    id: MockPlaceIds.therapy,
    name: 'Therapy Room 1',
    participantDescription: 'Health centre, room 1.',
    visual: VisualRef.arasaac('therapy', 29562),
  ),
  Place(
    id: MockPlaceIds.room104,
    name: 'Room 104',
    participantDescription: 'Main building, first floor, room 104.',
    visual: VisualRef(symbol: 'room'),
  ),
  Place(
    id: MockPlaceIds.entrance,
    name: 'Bus stop – Main Entrance',
    participantDescription: 'The bus stop in front of the main entrance.',
    visual: VisualRef.arasaac('bus', 2262),
  ),
  Place(
    id: MockPlaceIds.residenceKitchen,
    name: 'Residence Kitchen',
    participantDescription: 'Residence St. Josef, ground floor.',
    visual: VisualRef.arasaac('kitchen', 10752),
  ),
  Place(
    id: MockPlaceIds.residenceRooms,
    name: 'My Room',
    participantDescription: 'Your own room in the residence.',
    visual: VisualRef.arasaac('sleep', 6479),
  ),
  Place(
    id: MockPlaceIds.office,
    name: 'Social Work Office',
    participantDescription: 'Main building, room 012.',
    visual: VisualRef.arasaac('office', 5103),
  ),
  Place(
    id: MockPlaceIds.common,
    name: 'Common Room',
    participantDescription: 'Residence St. Josef, ground floor.',
    visual: VisualRef.arasaac('games', 9810),
  ),
  Place(
    id: MockPlaceIds.sports,
    name: 'Sports Hall',
    participantDescription: 'Behind building 3.',
    visual: VisualRef.arasaac('sport', 7010),
  ),
];

const mockContacts = <Contact>[
  Contact(
    id: MockContactIds.anna,
    name: 'Anna',
    roleLabel: 'Woodwork trainer',
    visual: VisualRef(symbol: 'person'),
  ),
  Contact(
    id: MockContactIds.weber,
    name: 'Mr. Weber',
    roleLabel: 'Metalwork trainer',
    visual: VisualRef(symbol: 'person'),
  ),
  Contact(
    id: MockContactIds.schmidt,
    name: 'Ms. Schmidt',
    roleLabel: 'Residential staff',
    visual: VisualRef(symbol: 'person'),
  ),
  Contact(
    id: MockContactIds.tom,
    name: 'Tom',
    roleLabel: 'Social worker',
    visual: VisualRef(symbol: 'person'),
  ),
  Contact(
    id: MockContactIds.okafor,
    name: 'Ms. Okafor',
    roleLabel: 'Physiotherapist',
    visual: VisualRef(symbol: 'person'),
  ),
  Contact(
    id: MockContactIds.klein,
    name: 'Mr. Klein',
    roleLabel: 'Residential staff',
    visual: VisualRef(symbol: 'person'),
  ),
];

const mockLibraryActivities = <LibraryActivity>[
  LibraryActivity(
    id: MockActivityIds.woodwork,
    name: 'Woodwork Workshop',
    category: ActivityCategory.work,
    visual: VisualRef.arasaac('carpentry', 39586),
    participantDescription: 'Practical training in the woodwork workshop.',
    defaultPlaceId: MockPlaceIds.workshopA,
    defaultContactId: MockContactIds.anna,
    whatToBring: ['Safety shoes', 'Work jacket'],
    instructions: 'Put on your safety shoes before you go in. '
        'Anna explains today\'s task at the start.',
    defaultDurationMin: 120,
  ),
  LibraryActivity(
    id: MockActivityIds.metalwork,
    name: 'Metal Workshop',
    category: ActivityCategory.work,
    visual: VisualRef.arasaac('metal', 37698),
    participantDescription: 'Practical training in the metal workshop.',
    defaultPlaceId: MockPlaceIds.workshopB,
    defaultContactId: MockContactIds.weber,
    whatToBring: ['Safety glasses', 'Safety shoes'],
    instructions: 'Put on safety glasses at your workstation.',
    defaultDurationMin: 120,
  ),
  LibraryActivity(
    id: MockActivityIds.breakfast,
    name: 'Breakfast',
    category: ActivityCategory.meal,
    visual: VisualRef.arasaac('breakfast', 4626),
    defaultPlaceId: MockPlaceIds.dining,
    defaultDurationMin: 45,
  ),
  LibraryActivity(
    id: MockActivityIds.lunch,
    name: 'Lunch',
    category: ActivityCategory.meal,
    visual: VisualRef.arasaac('meal', 4611),
    defaultPlaceId: MockPlaceIds.dining,
    instructions: 'Wash your hands first. Take a tray at the counter.',
    defaultDurationMin: 45,
  ),
  LibraryActivity(
    id: MockActivityIds.dinner,
    name: 'Group Dinner',
    category: ActivityCategory.meal,
    visual: VisualRef.arasaac('meal', 4611),
    defaultPlaceId: MockPlaceIds.residenceKitchen,
    defaultContactId: MockContactIds.klein,
    defaultDurationMin: 45,
  ),
  LibraryActivity(
    id: MockActivityIds.busToBbw,
    name: 'Bus to BBW',
    category: ActivityCategory.travel,
    visual: VisualRef.arasaac('bus', 2262),
    defaultPlaceId: MockPlaceIds.entrance,
    whatToBring: ['Bus pass'],
    defaultDurationMin: 20,
  ),
  LibraryActivity(
    id: MockActivityIds.busHome,
    name: 'Bus back to the residence',
    category: ActivityCategory.travel,
    visual: VisualRef.arasaac('bus', 2262),
    defaultPlaceId: MockPlaceIds.entrance,
    whatToBring: ['Bus pass'],
    defaultDurationMin: 20,
  ),
  LibraryActivity(
    id: MockActivityIds.study,
    name: 'Study Time',
    category: ActivityCategory.residential,
    visual: VisualRef.arasaac('study', 6495),
    participantDescription: 'Quiet time for homework and reading.',
    defaultPlaceId: MockPlaceIds.study,
    defaultContactId: MockContactIds.schmidt,
    whatToBring: ['School folder'],
    defaultDurationMin: 45,
  ),
  LibraryActivity(
    id: MockActivityIds.physio,
    name: 'Physiotherapy',
    category: ActivityCategory.support,
    visual: VisualRef.arasaac('therapy', 29562),
    defaultPlaceId: MockPlaceIds.therapy,
    defaultContactId: MockContactIds.okafor,
    whatToBring: ['Comfortable clothes'],
    defaultDurationMin: 30,
  ),
  LibraryActivity(
    id: MockActivityIds.coaching,
    name: 'Job Coaching',
    category: ActivityCategory.support,
    visual: VisualRef.arasaac('coaching', 24613),
    participantDescription: 'Talk with Tom about your training goals.',
    defaultPlaceId: MockPlaceIds.office,
    defaultContactId: MockContactIds.tom,
    defaultDurationMin: 60,
  ),
  LibraryActivity(
    id: MockActivityIds.sports,
    name: 'Sports',
    category: ActivityCategory.personal,
    visual: VisualRef.arasaac('sport', 7010),
    defaultPlaceId: MockPlaceIds.sports,
    defaultContactId: MockContactIds.klein,
    whatToBring: ['Sports shoes', 'Water bottle'],
    defaultDurationMin: 60,
  ),
  LibraryActivity(
    id: MockActivityIds.boardGames,
    name: 'Board Games',
    category: ActivityCategory.personal,
    visual: VisualRef.arasaac('games', 9810),
    defaultPlaceId: MockPlaceIds.common,
    defaultContactId: MockContactIds.klein,
    defaultDurationMin: 60,
  ),
  LibraryActivity(
    id: MockActivityIds.quietTime,
    name: 'Quiet Time',
    category: ActivityCategory.freeTime,
    visual: VisualRef.arasaac('relax', 37858),
    participantDescription: 'Rest in a calm room. Nothing is required.',
    defaultPlaceId: MockPlaceIds.common,
    defaultDurationMin: 60,
  ),
  LibraryActivity(
    id: MockActivityIds.eveningRoutine,
    name: 'Evening Routine',
    category: ActivityCategory.residential,
    visual: VisualRef.arasaac('teeth', 2326),
    participantDescription: 'Brush teeth and get ready for bed.',
    defaultPlaceId: MockPlaceIds.residenceRooms,
    defaultDurationMin: 30,
  ),
  LibraryActivity(
    id: MockActivityIds.groupMeeting,
    name: 'Group Meeting',
    category: ActivityCategory.residential,
    visual: VisualRef.arasaac('meeting', 8207),
    defaultPlaceId: MockPlaceIds.common,
    defaultContactId: MockContactIds.schmidt,
    defaultDurationMin: 45,
  ),
];
