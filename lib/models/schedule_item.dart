class SubStep {
  final String title;
  final int durationMin;
  bool isDone;

  SubStep({
    required this.title,
    required this.durationMin,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'durationMin': durationMin,
        'isDone': isDone,
      };
}

class ScheduleItem {
  final String id;
  final String title;
  final String category; // 'BBW_TRAINING', 'RESIDENTIAL', 'BREAK', 'PERSONAL'
  final int colorHex;    // Calming TEACCH color coding
  final String timeRange;
  String locationName;
  String staffName;
  final String pictogramUrl;
  final bool createdByStaff;
  bool isModifiedAlert;  // True when staff swaps a room or trainer
  bool isCompleted;
  final List<SubStep> subSteps;

  ScheduleItem({
    required this.id,
    required this.title,
    required this.category,
    required this.colorHex,
    required this.timeRange,
    required this.locationName,
    required this.staffName,
    required this.pictogramUrl,
    this.createdByStaff = true,
    this.isModifiedAlert = false,
    this.isCompleted = false,
    this.subSteps = const [],
  });
}

// Calming TEACCH Palette Constants
// Sky Slate (Training): 0xFF5B8FB9
// Warm Apricot (Break): 0xFFD98A56
// Soft Sage (Residential): 0xFF5E9A82
// Muted Lavender (Personal/AI): 0xFF8875B8

final List<ScheduleItem> mockSchedule = [
  ScheduleItem(
    id: '1',
    title: 'Metal Workshop: Milling',
    category: 'BBW_TRAINING',
    colorHex: 0xFF5B8FB9, // Calming Sky Blue
    timeRange: '08:00 - 10:00',
    locationName: 'Workshop Hall B',
    staffName: 'Mr. Weber',
    pictogramUrl: 'https://static.arasaac.org/pictograms/2443/2443_500.png',
    isModifiedAlert: false,
    subSteps: [
      SubStep(title: 'Put on safety glasses', durationMin: 2, isDone: true),
      SubStep(title: 'Clamp workpiece securely', durationMin: 15, isDone: false),
      SubStep(title: 'Sweep workstation', durationMin: 10, isDone: false),
    ],
  ),
  ScheduleItem(
    id: '2',
    title: 'Lunch Break',
    category: 'BREAK',
    colorHex: 0xFFD98A56, // Warm Apricot
    timeRange: '12:00 - 13:00',
    locationName: 'BBW Dining Hall',
    staffName: 'Independent',
    pictogramUrl: 'https://static.arasaac.org/pictograms/2349/2349_500.png',
    subSteps: [
      SubStep(title: 'Wash hands calmly', durationMin: 3, isDone: false),
      SubStep(title: 'Pick up tray & eat lunch', durationMin: 30, isDone: false),
    ],
  ),
  ScheduleItem(
    id: '3',
    title: 'Residential Group: Study & Dinner',
    category: 'RESIDENTIAL',
    colorHex: 0xFF5E9A82, // Soothing Sage Green
    timeRange: '17:00 - 19:00',
    locationName: 'Residential Group St. Josef',
    staffName: 'Ms. Schmidt (Substitute)',
    pictogramUrl: 'https://static.arasaac.org/pictograms/6964/6964_500.png',
    isModifiedAlert: true,
    subSteps: [
      SubStep(title: 'Unpack backpack in room', durationMin: 5, isDone: false),
      SubStep(title: 'Quiet study time', durationMin: 30, isDone: false),
      SubStep(title: 'Group dinner', durationMin: 45, isDone: false),
    ],
  ),
];

List<ScheduleItem> buildEveningResidentialModule() {
  return [
    ScheduleItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Evening Wind-Down Routine',
      category: 'RESIDENTIAL',
      colorHex: 0xFF5E9A82,
      timeRange: '19:30 - 21:00',
      locationName: 'Residential Group St. Josef',
      staffName: 'Mr. Klein',
      pictogramUrl: 'https://static.arasaac.org/pictograms/2262/2262_500.png',
      createdByStaff: true,
      subSteps: [
        SubStep(title: 'Help tidy up the kitchen', durationMin: 15),
        SubStep(title: 'Relax in the common room', durationMin: 45),
        SubStep(title: 'Brush teeth & get ready for sleep', durationMin: 15),
      ],
    ),
  ];
}