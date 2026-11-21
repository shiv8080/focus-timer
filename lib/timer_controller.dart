import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Phase {
  focus('Focus'),
  shortBreak('Short break'),
  longBreak('Long break');

  const Phase(this.label);
  final String label;
}

@immutable
class TimerSettings {
  const TimerSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoStartNext = false,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  final bool autoStartNext;

  Duration durationFor(Phase phase) => Duration(
        minutes: switch (phase) {
          Phase.focus => focusMinutes,
          Phase.shortBreak => shortBreakMinutes,
          Phase.longBreak => longBreakMinutes,
        },
      );

  TimerSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? sessionsBeforeLongBreak,
    bool? autoStartNext,
  }) =>
      TimerSettings(
        focusMinutes: focusMinutes ?? this.focusMinutes,
        shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
        longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
        sessionsBeforeLongBreak:
            sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
        autoStartNext: autoStartNext ?? this.autoStartNext,
      );
}

/// Formats a duration as mm:ss, rounding partial seconds up so the display
/// never shows 00:00 while time is still left.
String formatRemaining(Duration d) {
  final total = (d.inMilliseconds / 1000).ceil();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

typedef PhaseCompleteCallback = void Function(Phase finished, Phase next);

/// Timer state. A running timer stores its wall-clock end time instead of
/// counting ticks, so it stays accurate if the app is backgrounded or killed.
class TimerController extends ChangeNotifier {
  TimerController({this.prefs, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SharedPreferences? prefs;
  final DateTime Function() _clock;

  /// Called when a phase runs out (not when it is skipped).
  PhaseCompleteCallback? onPhaseComplete;

  TimerSettings _settings = const TimerSettings();
  Phase _phase = Phase.focus;
  int _completedInCycle = 0;
  int _todayCount = 0;
  String _todayKey = '';
  DateTime? _endsAt;
  Duration _remaining = const TimerSettings().durationFor(Phase.focus);
  Timer? _ticker;

  TimerSettings get settings => _settings;
  Phase get phase => _phase;
  int get completedInCycle => _completedInCycle;
  bool get isRunning => _endsAt != null;
  Duration get phaseDuration => _settings.durationFor(_phase);

  Duration get remaining {
    final end = _endsAt;
    if (end == null) return _remaining;
    final left = end.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  double get progress {
    final total = phaseDuration.inMilliseconds;
    if (total == 0) return 0;
    return (1 - remaining.inMilliseconds / total).clamp(0.0, 1.0);
  }

  int get todayCount => _dayKey(_clock()) == _todayKey ? _todayCount : 0;

  void start() {
    if (isRunning) return;
    if (_remaining <= Duration.zero) _remaining = phaseDuration;
    _endsAt = _clock().add(_remaining);
    _startTicker();
    _save();
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _remaining = remaining;
    _endsAt = null;
    _stopTicker();
    _save();
    notifyListeners();
  }

  void toggle() => isRunning ? pause() : start();

  void reset() {
    _endsAt = null;
    _stopTicker();
    _remaining = phaseDuration;
    _save();
    notifyListeners();
  }

  void skip() => _advance(completed: false, alert: false, allowAutoStart: false);

  void selectPhase(Phase phase) {
    if (isRunning) return;
    _phase = phase;
    _remaining = phaseDuration;
    _save();
    notifyListeners();
  }

  void updateSettings(TimerSettings settings) {
    final durationChanged =
        settings.durationFor(_phase) != _settings.durationFor(_phase);
    _settings = settings;
    if (!isRunning && durationChanged) _remaining = phaseDuration;
    _save();
    notifyListeners();
  }

  /// Re-reads the clock. Called by the ticker and when the app resumes.
  void refresh() {
    if (isRunning && remaining == Duration.zero) {
      _advance(completed: true, alert: true, allowAutoStart: true);
    } else {
      notifyListeners();
    }
  }

  @visibleForTesting
  void tick() => refresh();

  void _advance({
    required bool completed,
    required bool alert,
    required bool allowAutoStart,
  }) {
    final finished = _phase;
    _stopTicker();
    _endsAt = null;

    if (finished == Phase.focus) {
      if (completed) {
        _completedInCycle++;
        _bumpToday();
      }
      _phase = _completedInCycle >= _settings.sessionsBeforeLongBreak
          ? Phase.longBreak
          : Phase.shortBreak;
    } else {
      if (finished == Phase.longBreak) _completedInCycle = 0;
      _phase = Phase.focus;
    }
    _remaining = phaseDuration;

    if (alert) onPhaseComplete?.call(finished, _phase);
    if (completed && allowAutoStart && _settings.autoStartNext) {
      start(); // saves and notifies
      return;
    }
    _save();
    notifyListeners();
  }

  void _bumpToday() {
    final key = _dayKey(_clock());
    if (key != _todayKey) {
      _todayKey = key;
      _todayCount = 0;
    }
    _todayCount++;
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => refresh());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ---- persistence -------------------------------------------------------

  static const _kFocus = 'focusMinutes';
  static const _kShort = 'shortBreakMinutes';
  static const _kLong = 'longBreakMinutes';
  static const _kSessions = 'sessionsBeforeLongBreak';
  static const _kAuto = 'autoStartNext';
  static const _kPhase = 'phase';
  static const _kCycle = 'completedInCycle';
  static const _kTodayKey = 'todayKey';
  static const _kTodayCount = 'todayCount';
  static const _kEndsAt = 'endsAtMs';
  static const _kRemaining = 'remainingMs';

  /// Loads saved settings and timer state. If a phase ran out while the app
  /// was closed, it is counted but the next phase is not auto-started.
  void restore() {
    final p = prefs;
    if (p == null) return;
    int clampInt(String key, int fallback, int min, int max) =>
        (p.getInt(key) ?? fallback).clamp(min, max);

    _settings = TimerSettings(
      focusMinutes: clampInt(_kFocus, 25, 5, 90),
      shortBreakMinutes: clampInt(_kShort, 5, 1, 30),
      longBreakMinutes: clampInt(_kLong, 15, 5, 60),
      sessionsBeforeLongBreak: clampInt(_kSessions, 4, 2, 8),
      autoStartNext: p.getBool(_kAuto) ?? false,
    );
    _phase = Phase.values[clampInt(_kPhase, 0, 0, Phase.values.length - 1)];
    _completedInCycle = p.getInt(_kCycle) ?? 0;
    _todayKey = p.getString(_kTodayKey) ?? '';
    _todayCount = p.getInt(_kTodayCount) ?? 0;

    final remainingMs = p.getInt(_kRemaining);
    _remaining =
        remainingMs == null ? phaseDuration : Duration(milliseconds: remainingMs);
    final endsAtMs = p.getInt(_kEndsAt);
    _endsAt =
        endsAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endsAtMs);

    if (isRunning) {
      if (remaining == Duration.zero) {
        _advance(completed: true, alert: false, allowAutoStart: false);
        return;
      }
      _startTicker();
    }
    notifyListeners();
  }

  void _save() {
    final p = prefs;
    if (p == null) return;
    p.setInt(_kFocus, _settings.focusMinutes);
    p.setInt(_kShort, _settings.shortBreakMinutes);
    p.setInt(_kLong, _settings.longBreakMinutes);
    p.setInt(_kSessions, _settings.sessionsBeforeLongBreak);
    p.setBool(_kAuto, _settings.autoStartNext);
    p.setInt(_kPhase, _phase.index);
    p.setInt(_kCycle, _completedInCycle);
    p.setString(_kTodayKey, _todayKey);
    p.setInt(_kTodayCount, _todayCount);
    p.setInt(_kRemaining, _remaining.inMilliseconds);
    final end = _endsAt;
    if (end == null) {
      p.remove(_kEndsAt);
    } else {
      p.setInt(_kEndsAt, end.millisecondsSinceEpoch);
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
