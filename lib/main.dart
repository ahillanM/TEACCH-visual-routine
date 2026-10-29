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
      title: 'BBW Visual Routine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E9A82)),
        scaffoldBackgroundColor: const Color(0xFFF5F3EF),
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
        elevation: 0,
        backgroundColor: isStaffMode
            ? const Color(0xFF2D3748)
            : const Color(0xFF4A7C66), // Calming Deep Sage
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              isStaffMode ? Icons.dashboard_customize_rounded : Icons.wb_twilight_rounded,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isStaffMode
                  ? 'BBW Würzburg • Staff Dashboard'
                  : 'Lukas\'s Visual Routine',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        actions: [
          const Tooltip(
            message: 'TLS 1.3 Encrypted • EU-Central (Frankfurt) GDPR Compliant',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.verified_user_rounded, color: Color(0xFFA7F3D0), size: 20),
            ),
          ),
          Row(
            children: [
              const Text('Participant', style: TextStyle(fontSize: 12)),
              Switch(
                value: isStaffMode,
                activeThumbColor: const Color(0xFFF6AD55),
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