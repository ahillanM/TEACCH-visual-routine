# Project Context & Master LLM Rules: BBW TEACCH Visual Routine Planner

> **INSTRUCTIONS FOR ANY AI ASSISTANT (Claude, ChatGPT, Gemini, Cursor, Copilot):**
> Read this entire file before generating or modifying any code. You are assisting one member of a multi-developer hackathon team. You MUST strictly obey the **Folder Ownership**, **Locked Data Models**, **Widget Signatures**, and **Feature Scope** defined below so that all teammates' branches merge into `main` with zero conflicts.

---

## 1. Hackathon Challenge & Core Goal
We are building an Android & Web prototype for **Caritas-Don Bosco GmbH (Vocational Training Center / BBW Würzburg)**.
* **Target Users:** Young people on the autism spectrum, with learning disabilities, and/or mental health conditions, alongside their rehabilitation and support teams (vocational trainers, social workers, psychologists, residential staff).
* **The Problem:** Transitions between activities, daily routines, and unexpected schedule changes cause high stress and overwhelm. Standard calendars are too cluttered and text-heavy.
* **Our Solution:** A two-interface, **TEACCH-based** visual daily/weekly planner inspired by **MyVisualRoutine**:
  1. **Participant Interface (`lib/screens_participant/`):** A distraction-free, high-contrast visual schedule board. It prevents accidental edits/deletions of staff schedules, lets users check off sub-steps, moves finished tasks into a visual **"Done Pouch"**, displays calm **"Schedule Update"** banners when staff change a room or trainer, and lets participants generate personal routines from plain text.
  2. **Staff/Admin Interface (`lib/screens_staff/`):** A management dashboard where staff create/manage schedules, assign **1-Click Predefined Routine Modules** (e.g., *Workshop Training Day*, *Evening Residential Routine*), and remotely update rooms or substitute staff.

---

## 2. Strict Non-Negotiable Rules for All LLMs

1. **100% English UI & Data:** All UI labels, mock schedules, buttons, alerts, and AI-generated steps MUST be in **English**.
2. **Strict AI Scope:** The **ONLY** AI feature in this app is converting plain-text user input (e.g., *"wake up, wash face, get dressed, eat breakfast"*) into a structured `ScheduleItem` with timed `SubStep`s and an ARASAAC pictogram. Do **NOT** invent chatbots, voice assistants, or unrelated AI features.
3. **Never Break Folder Boundaries:** Each teammate works in an isolated folder. Only generate or edit files in the folder assigned to the current user:
   * **Role 1 (Participant UI):** Only edit inside `lib/screens_participant/`
   * **Role 2 (Staff UI):** Only edit inside `lib/screens_staff/`
   * **Role 3 (AI & Backend Sync):** Only edit inside `lib/services/`
   * **Do NOT edit `lib/main.dart`** unless explicitly asked to do a final integration.
4. **Preserve Error-Proof Design (Participant Mode):** Participants must **NEVER** see a delete button or edit button on tasks where `createdByStaff == true`. They can only check off `SubStep`s and mark the activity as completed (`isCompleted = true`).
5. **GDPR & Security Compliance:**
   * All external traffic (Supabase, Gemini API, ARASAAC API) must strictly use `https://` (TLS 1.3).
   * **Data Minimization:** Never send participant names, IDs, or personal profiles to the Gemini API or ARASAAC API—send only the raw, anonymous task string.

---

## 3. Locked Data Model (`lib/models/schedule_item.dart`)

**CRITICAL:** Do **NOT** rename, remove, or change the types of any existing fields in `SubStep` or `ScheduleItem`. If you need a new field for a feature, you must make it optional with a default value so you do not break other teammates' code.

```dart
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
  final int colorHex;    // TEACCH color coding (see Section 5)
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
```

---

## 4. Locked Entry-Point Signatures

`lib/main.dart` switches between `ParticipantHome` and `StaffDashboard`. You **MUST** keep these exact constructor signatures so `main.dart` always compiles:

### Participant Screen Signature (`lib/screens_participant/participant_home.dart`)
```dart
class ParticipantHome extends StatefulWidget {
  final List<ScheduleItem> schedule;
  final VoidCallback onScheduleChanged;

  const ParticipantHome({
    super.key,
    required this.schedule,
    required this.onScheduleChanged,
  });
```

### Staff Screen Signature (`lib/screens_staff/staff_dashboard.dart`)
```dart
class StaffDashboard extends StatelessWidget { // (Can be converted to StatefulWidget if constructor stays identical)
  final List<ScheduleItem> schedule;
  final VoidCallback onScheduleChanged;

  const StaffDashboard({
    super.key,
    required this.schedule,
    required this.onScheduleChanged,
  });
```

### AI Service Signature (`lib/services/ai_routine_service.dart`)
```dart
class AiRoutineService {
  static Future<ScheduleItem> generateRoutineFromText(String plainTextInput) async { ... }
}
```

---

## 5. TEACCH Visual & Color System

Every card in the app must follow the **TEACCH methodology**, visually answering 4 questions with minimal text clutter:
1. **What** am I doing? (Pictogram + clear title + sub-steps)
2. **When and how long?** (`timeRange` badge + step durations / visual timer)
3. **Where and with whom?** (`locationName` + `staffName` / photos)
4. **What happens next?** (Clear sequence from top to bottom, or a "Now / Next" focus view, with finished items collapsing into the green **Done Pouch**).

### Mandatory TEACCH Category Colors (`colorHex`)
Always use these exact hex integers when creating or displaying categories:
* **`BBW_TRAINING` (Vocational Training / Workshop):** `0xFF2B6CB0` (Strong Blue)
* **`BREAK` (Lunch / Rest Breaks):** `0xFFDD6B20` (Warm Orange)
* **`RESIDENTIAL` (Residential Group / Study / Evening):** `0xFF2F855A` (Calm Green)
* **`PERSONAL` (Participant's Own Routines / Leisure):** `0xFF805AD5` (Distinct Purple)

---

## 6. Feature Roadmap by Role (What Each Teammate's LLM Should Build)

### Role 1: Participant UI (`lib/screens_participant/`)
* **"Now / Next" (First / Then) Focus Mode Toggle:** Allow the participant to toggle between **Full Day View** (vertical strip), **Weekly View** (7-day visual overview), and **Focus Mode** (shows ONLY the current active card in large high-contrast view with a visual countdown timer bar, plus a small preview box at the bottom showing *"Next: [Next Task Title]"*).
* **Error-Proof Interaction:** Require a deliberate action (e.g., Hold button or confirmation slide) to move a task to the **Done Pouch**, and allow tapping the **Done Pouch** to view completed tasks without accidentally deleting anything.
* **Visual Timer & Reminders:** Add a live countdown timer or progress bar for the current task/sub-steps and trigger a gentle transition reminder banner (*"10 minutes left in current activity"*).

### Role 2: Staff/Admin UI (`lib/screens_staff/`)
* **Predefined Routine Modules (Templates):** Add 1-click template cards that staff can assign to a participant's schedule:
  * *BBW Standard Training Day* (Morning Workshop + Break + Afternoon Workshop)
  * *Evening Residential Routine* (Study Time + Group Dinner + Leisure/Bedtime)
  * *Morning Preparation Routine*
* **Create Custom Appointment Dialog:** A clean form for staff to add a single appointment with Title, Category (auto-sets TEACCH color), Time Range, Room/Location, Staff Member name, Pictogram/Photo selector, and optional Sub-steps.
* **Calm Schedule Change ("Swap Staff / Room"):** Allow staff to edit the room or substitute trainer on any existing card, which sets `isModifiedAlert = true` so the participant sees a calm, structured update banner.

### Role 3: AI & Backend Services (`lib/services/`)
* **Plain-Text AI Routine Generator (`ai_routine_service.dart`):** Refine Gemini API JSON structured output + ARASAAC API pictogram lookup (`https://api.arasaac.org/v1/pictograms/en/search/{keyword}`), while keeping the offline comma-split fallback so the demo never crashes if Wi-Fi drops.
* **Real-Time Cloud Sync (`supabase_service.dart`):** Sync `ScheduleItem` list with Supabase over TLS/HTTPS so changes made in Staff Mode update Participant Mode in real time across devices.