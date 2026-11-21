import 'package:flutter_test/flutter_test.dart';
import 'package:focus_timer/timer_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 1, 1, 9));

  TimerController make({SharedPreferences? prefs}) {
    final c = TimerController(prefs: prefs, clock: clock);
    addTearDown(c.dispose);
    return c;
  }

  test('formatRemaining rounds partial seconds up', () {
    expect(formatRemaining(const Duration(minutes: 25)), '25:00');
    expect(formatRemaining(const Duration(milliseconds: 59001)), '01:00');
    expect(formatRemaining(Duration.zero), '00:00');
  });

  test('focus session completes into a short break and is counted', () {
    final c = make();
    Phase? finished;
    c.onPhaseComplete = (f, _) => finished = f;

    c.start();
    now = now.add(const Duration(minutes: 25));
    c.tick();

    expect(finished, Phase.focus);
    expect(c.phase, Phase.shortBreak);
    expect(c.isRunning, isFalse);
    expect(c.completedInCycle, 1);
    expect(c.todayCount, 1);
    expect(c.remaining, const Duration(minutes: 5));
  });

  test('pause keeps remaining time', () {
    final c = make();
    c.start();
    now = now.add(const Duration(minutes: 10));
    c.pause();
    now = now.add(const Duration(hours: 1));
    expect(c.remaining, const Duration(minutes: 15));
  });

  test('long break after N focus sessions, then the cycle resets', () {
    final c = make();
    for (var i = 0; i < 4; i++) {
      expect(c.phase, Phase.focus);
      c.start();
      now = now.add(c.phaseDuration);
      c.tick();
      if (i < 3) c.skip(); // skip the short break
    }
    expect(c.phase, Phase.longBreak);

    c.start();
    now = now.add(c.phaseDuration);
    c.tick();
    expect(c.phase, Phase.focus);
    expect(c.completedInCycle, 0);
    expect(c.todayCount, 4);
  });

  test('skipping focus does not count it', () {
    final c = make();
    c.skip();
    expect(c.phase, Phase.shortBreak);
    expect(c.completedInCycle, 0);
    expect(c.todayCount, 0);
  });

  test('auto-start begins the next phase', () {
    final c = make()
      ..updateSettings(const TimerSettings(autoStartNext: true));
    c.start();
    now = now.add(const Duration(minutes: 25));
    c.tick();
    expect(c.phase, Phase.shortBreak);
    expect(c.isRunning, isTrue);
  });

  test('restores a running timer, and finishes one that ran out while closed',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    make(prefs: prefs).start();
    now = now.add(const Duration(minutes: 5));
    final resumed = make(prefs: prefs)..restore();
    expect(resumed.isRunning, isTrue);
    expect(resumed.remaining, const Duration(minutes: 20));

    now = now.add(const Duration(hours: 2));
    final later = make(prefs: prefs)..restore();
    expect(later.phase, Phase.shortBreak);
    expect(later.isRunning, isFalse);
    expect(later.completedInCycle, 1);
  });
}
