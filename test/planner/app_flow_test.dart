import 'package:bbw_visual_routine/app/app_scope.dart';
import 'package:bbw_visual_routine/app/app_services.dart';
import 'package:bbw_visual_routine/app/planner_app.dart';
import 'package:bbw_visual_routine/app/role_guard.dart';
import 'package:bbw_visual_routine/core/auth/permissions.dart';
import 'package:bbw_visual_routine/core/time/clock.dart';
import 'package:bbw_visual_routine/screens_participant/participant_shell.dart';
import 'package:bbw_visual_routine/screens_staff/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppServices services;

  setUp(() {
    services = AppServices.demo(
      clock: DemoClock(startHour: 9, startMinute: 40, ticking: false),
    );
  });
  tearDown(() => services.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(PlannerApp(services: services));
  }

  Future<void> signIn(WidgetTester tester, String username) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username or email'), username);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'demo');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('participant login opens the participant interface',
      (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'lena');
    expect(find.byType(ParticipantShell), findsOneWidget);
    expect(find.byType(AdminShell), findsNothing);
    expect(find.text('Now'), findsWidgets);
  });

  testWidgets('staff login opens the professional interface', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'staff');
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.byType(ParticipantShell), findsNothing);
  });

  testWidgets('wrong password shows a clear error and stays on login',
      (tester) async {
    await pumpApp(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username or email'), 'lena');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'x');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('do not match'), findsOneWidget);
    expect(find.byType(ParticipantShell), findsNothing);
  });

  testWidgets('participants cannot open professional areas', (tester) async {
    await tester.runAsync(
        () => services.auth.signIn(username: 'lena', password: 'demo'));
    await tester.pumpWidget(AppScope(
      services: services,
      child: const MaterialApp(
        home: RoleGuard(
          permission: Permission.editSchedules,
          child: Text('ADMIN EDITOR'),
        ),
      ),
    ));
    expect(find.text('ADMIN EDITOR'), findsNothing);
    expect(find.text('This area is not available'), findsOneWidget);
    expect(RolePermissions.can(services.auth.user, Permission.publishChanges),
        isFalse);
  });
}
