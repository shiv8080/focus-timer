import 'package:flutter/material.dart';

import 'timer_controller.dart';

/// Bottom sheet that edits a copy of the settings and pops it on Save.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.initial});

  final TimerSettings initial;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late TimerSettings _s = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _NumberSlider(
              label: 'Focus',
              suffix: ' min',
              value: _s.focusMinutes,
              min: 5,
              max: 90,
              onChanged: (v) => setState(() => _s = _s.copyWith(focusMinutes: v)),
            ),
            _NumberSlider(
              label: 'Short break',
              suffix: ' min',
              value: _s.shortBreakMinutes,
              min: 1,
              max: 30,
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(shortBreakMinutes: v)),
            ),
            _NumberSlider(
              label: 'Long break',
              suffix: ' min',
              value: _s.longBreakMinutes,
              min: 5,
              max: 60,
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(longBreakMinutes: v)),
            ),
            _NumberSlider(
              label: 'Focus sessions before a long break',
              value: _s.sessionsBeforeLongBreak,
              min: 2,
              max: 8,
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(sessionsBeforeLongBreak: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-start the next timer'),
              value: _s.autoStartNext,
              onChanged: (v) => setState(() => _s = _s.copyWith(autoStartNext: v)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_s),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberSlider extends StatelessWidget {
  const _NumberSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '$value$suffix',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
