import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_timer/main.dart';
import 'package:focus_timer/timer_controller.dart';

void main() {
  testWidgets('shows the timer and toggles start/pause', (tester) async {
    final controller = TimerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(FocusTimerApp(controller: controller));

    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
  });
}
