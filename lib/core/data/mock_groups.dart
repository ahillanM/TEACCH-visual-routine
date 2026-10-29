import '../models/participant_group.dart';
import 'mock_participants.dart';

/// MOCK: example groups staff have already prepared.
const mockGroups = [
  ParticipantGroup(
    id: 'group-st-josef',
    name: 'Residence St. Josef',
    memberIds: {MockParticipantIds.lena, MockParticipantIds.jonas},
  ),
  ParticipantGroup(
    id: 'group-don-bosco',
    name: 'Residence Don Bosco',
    memberIds: {MockParticipantIds.mia, MockParticipantIds.elias},
  ),
  ParticipantGroup(
    id: 'group-workshop',
    name: 'Workshop Trainees',
    memberIds: {
      MockParticipantIds.lena,
      MockParticipantIds.jonas,
      MockParticipantIds.elias,
    },
  ),
];
