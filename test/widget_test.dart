import 'package:bbw_visual_routine/app/app_services.dart';
import 'package:bbw_visual_routine/app/planner_app.dart';
import 'package:bbw_visual_routine/core/time/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts on the login screen', (WidgetTester tester) async {
    final services = AppServices.demo(
      clock: DemoClock(startHour: 9, startMinute: 40, ticking: false),
    );
    addTearDown(services.dispose);

    await tester.pumpWidget(PlannerApp(services: services));

    expect(find.text('BBW Visual Planner'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });
}
