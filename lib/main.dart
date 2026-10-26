import 'package:flutter/material.dart';
import 'models/schedule_item.dart';
import 'screens_participant/participant_home.dart';
import 'screens_staff/staff_dashboard.dart';

void main() {
  runApp(const TeacchPlannerApp());
}

class TeacchPlannerApp extends StatelessWidget {
  const TeacchPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BBW TEACCH Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B6CB0)),
        useMaterial3: true,
      ),
      home: const DemoRoleSwitcher(),
    );
  }
}

class DemoRoleSwitcher extends StatefulWidget {
  const DemoRoleSwitcher({super.key});

  @override
  State<DemoRoleSwitcher> createState() => _DemoRoleSwitcherState();
}

class _DemoRoleSwitcherState extends State<DemoRoleSwitcher> {
  bool isStaffMode = false;

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            isStaffMode ? Colors.blueGrey.shade900 : const Color(0xFF2B6CB0),
        foregroundColor: Colors.white,
        title: Text(
          isStaffMode
              ? 'BBW Würzburg • Staff Dashboard'
              : 'My Daily Plan (Lukas)',
        ),
        actions: [
          const Tooltip(
            message: 'TLS 1.3 Encrypted • EU-Central (Frankfurt) GDPR Compliant',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.verified_user, color: Colors.greenAccent, size: 20),
            ),
          ),
          Row(
            children: [
              const Text('Participant', style: TextStyle(fontSize: 12)),
              Switch(
                value: isStaffMode,
                activeThumbColor: Colors.amber,
                onChanged: (val) => setState(() => isStaffMode = val),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: Text('Staff', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
      body: isStaffMode
          ? StaffDashboard(
              schedule: mockSchedule,
              onScheduleChanged: _refresh,
            )
          : ParticipantHome(
              schedule: mockSchedule,
              onScheduleChanged: _refresh,
            ),
    );
  }
}