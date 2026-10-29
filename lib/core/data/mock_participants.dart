import '../models/app_user.dart';
import '../models/participant.dart';
import 'mock_library.dart';

// DEMO DATA ONLY. Fictional participants, first names only.

abstract final class MockParticipantIds {
  static const lena = 'p-lena';
  static const jonas = 'p-jonas';
  static const mia = 'p-mia';
  static const elias = 'p-elias';
  static const all = {lena, jonas, mia, elias};
}

const _commonPlaces = {
  MockPlaceIds.dining,
  MockPlaceIds.entrance,
  MockPlaceIds.study,
  MockPlaceIds.residenceKitchen,
  MockPlaceIds.residenceRooms,
  MockPlaceIds.common,
};

const mockParticipants = <Participant>[
  // Minimal information, symbols only.
  Participant(
    id: MockParticipantIds.lena,
    displayName: 'Lena',
    livingGroup: 'Residence St. Josef',
    profile: ParticipantProfile(
      informationDensity: InformationDensity.minimal,
      visualPreference: VisualPreference.symbols,
      transitionWarning: TransitionWarning.fiveMinutes,
      timeDisplay: TimeDisplay.progress,
      motion: MotionPreference.reduced,
    ),
    familiarPlaceIds: {..._commonPlaces, MockPlaceIds.workshopA},
  ),
  // Detailed information: what to bring, when to leave, instructions.
  Participant(
    id: MockParticipantIds.jonas,
    displayName: 'Jonas',
    livingGroup: 'Residence St. Josef',
    profile: ParticipantProfile(
      informationDensity: InformationDensity.detailed,
      visualPreference: VisualPreference.both,
      transitionWarning: TransitionWarning.fiveTwoOne,
      timeDisplay: TimeDisplay.both,
    ),
    familiarPlaceIds: {
      ..._commonPlaces,
      MockPlaceIds.workshopA,
      MockPlaceIds.office,
      MockPlaceIds.sports,
    },
  ),
  Participant(
    id: MockParticipantIds.mia,
    displayName: 'Mia',
    livingGroup: 'Residence Don Bosco',
    profile: ParticipantProfile(
      informationDensity: InformationDensity.standard,
      visualPreference: VisualPreference.photos,
    ),
    familiarPlaceIds: {..._commonPlaces, MockPlaceIds.workshopA},
  ),
  // High contrast + large text.
  Participant(
    id: MockParticipantIds.elias,
    displayName: 'Elias',
    livingGroup: 'Residence Don Bosco',
    profile: ParticipantProfile(
      informationDensity: InformationDensity.standard,
      visualPreference: VisualPreference.both,
      transitionWarning: TransitionWarning.fiveTwoOne,
      highContrast: true,
      textSize: TextSizePreference.large,
    ),
    familiarPlaceIds: {
      ..._commonPlaces,
      MockPlaceIds.workshopB,
      MockPlaceIds.therapy,
    },
  ),
];

/// MOCK accounts. Password for every demo account: "demo".
const mockPassword = 'demo';

const mockUsers = <AppUser>[
  AppUser(
    id: 'u-staff',
    username: 'staff',
    displayName: 'Sam (Trainer)',
    role: Role.staff,
  ),
  AppUser(
    id: 'u-admin',
    username: 'admin',
    displayName: 'Alex (Admin)',
    role: Role.admin,
  ),
  AppUser(
    id: 'u-lena',
    username: 'lena',
    displayName: 'Lena',
    role: Role.participant,
    participantId: MockParticipantIds.lena,
  ),
  AppUser(
    id: 'u-jonas',
    username: 'jonas',
    displayName: 'Jonas',
    role: Role.participant,
    participantId: MockParticipantIds.jonas,
  ),
  AppUser(
    id: 'u-mia',
    username: 'mia',
    displayName: 'Mia',
    role: Role.participant,
    participantId: MockParticipantIds.mia,
  ),
  AppUser(
    id: 'u-elias',
    username: 'elias',
    displayName: 'Elias',
    role: Role.participant,
    participantId: MockParticipantIds.elias,
  ),
];
