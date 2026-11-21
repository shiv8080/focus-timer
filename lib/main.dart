import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_sheet.dart';
import 'timer_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final controller = TimerController(prefs: prefs)..restore();
  runApp(FocusTimerApp(controller: controller));
}

class FocusTimerApp extends StatelessWidget {
  const FocusTimerApp({super.key, required this.controller});

  final TimerController controller;

  static ThemeData _theme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD9534F),
          brightness: brightness,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Timer',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: TimerScreen(controller: controller),
    );
  }
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, required this.controller});

  final TimerController controller;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  TimerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.onPhaseComplete = _onPhaseComplete;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.onPhaseComplete = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.refresh();
  }

  void _onPhaseComplete(Phase finished, Phase next) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    if (!mounted) return;
    final message = finished == Phase.focus
        ? 'Nice work! Time for a ${next.label.toLowerCase()}.'
        : 'Break over. Ready to focus?';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSettings() async {
    final result = await showModalBottomSheet<TimerSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SettingsSheet(initial: c.settings),
    );
    if (result != null) c.updateSettings(result);
  }

  static (Color, Color) _phaseColors(ColorScheme s, Phase p) => switch (p) {
        Phase.focus => (s.primary, s.onPrimary),
        Phase.shortBreak => (s.tertiary, s.onTertiary),
        Phase.longBreak => (s.secondary, s.onSecondary),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final (color, onColor) = _phaseColors(scheme, c.phase);
        final status = c.isRunning
            ? c.phase.label
            : (c.remaining == c.phaseDuration ? 'Ready' : 'Paused');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Focus Timer'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.tune),
                onPressed: _openSettings,
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<Phase>(
                      showSelectedIcon: false,
                      segments: [
                        for (final p in Phase.values)
                          ButtonSegment(value: p, label: Text(p.label)),
                      ],
                      selected: {c.phase},
                      onSelectionChanged:
                          c.isRunning ? null : (s) => c.selectPhase(s.first),
                    ),
                    const SizedBox(height: 40),
                    SizedBox.square(
                      dimension: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: c.progress,
                              strokeWidth: 14,
                              strokeCap: StrokeCap.round,
                              color: color,
                              backgroundColor: color.withValues(alpha: 0.15),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatRemaining(c.remaining),
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              Text(
                                status,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Reset',
                          onPressed: c.reset,
                          icon: const Icon(Icons.replay),
                        ),
                        const SizedBox(width: 24),
                        SizedBox.square(
                          dimension: 88,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                              backgroundColor: color,
                              foregroundColor: onColor,
                            ),
                            onPressed: c.toggle,
                            child: Icon(
                              c.isRunning ? Icons.pause : Icons.play_arrow,
                              size: 44,
                              semanticLabel: c.isRunning ? 'Pause' : 'Start',
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton.filledTonal(
                          tooltip: 'Skip',
                          onPressed: c.skip,
                          icon: const Icon(Icons.skip_next),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _SessionDots(
                      done: c.completedInCycle,
                      total: c.settings.sessionsBeforeLongBreak,
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${c.todayCount} focus session'
                      '${c.todayCount == 1 ? '' : 's'} today',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionDots extends StatelessWidget {
  const _SessionDots({
    required this.done,
    required this.total,
    required this.color,
  });

  final int done;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$done of $total focus sessions before a long break',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done ? color : color.withValues(alpha: 0.2),
              ),
            ),
        ],
      ),
    );
  }
}
