import 'dart:async';

import 'package:flutter/material.dart';

import '../core/sim_clock.dart';
import '../game/vertical_slice_game.dart';
import '../sim/house_world.dart';
import '../sim/simulation.dart';

/// Die einzige Bildschirmoberfläche des Spiels.
///
/// Bewusst dünn: Uhrzeit, Wetter, Zeitraffer und ein Zettel. Es gibt nichts zu
/// verwalten, also gibt es auch keine Leisten voller Werte. Wer wissen will,
/// wie es jemandem geht, tippt die Person an.
class Hud extends StatefulWidget {
  const Hud({
    super.key,
    required this.simulation,
    required this.game,
    required this.onPostNote,
  });

  final HouseSimulation simulation;
  final VerticalSliceGame game;
  final VoidCallback onPostNote;

  @override
  State<Hud> createState() => _HudState();
}

class _HudState extends State<Hud> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Vier Aktualisierungen pro Sekunde reichen für eine Uhr – die Oberfläche
    // muss nicht mit der Bildrate mitlaufen.
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  HouseSimulation get sim => widget.simulation;

  @override
  Widget build(BuildContext context) {
    final clock = sim.world.clock;
    final focused = widget.game.focusedRoomId;
    final room = focused == null ? null : sim.world.roomById[focused];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Panel(child: _clockLine(clock)),
                const Spacer(),
                _Panel(child: _speedControl(clock)),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Chip(
                  label: 'Notiz anheften',
                  filled: true,
                  onTap: widget.onPostNote,
                ),
                const Spacer(),
                if (room != null)
                  _Chip(
                    label: '${room.name}  ✕',
                    onTap: widget.game.clearFocus,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _latestEvent(),
          ],
        ),
      ),
    );
  }

  Widget _clockLine(SimClock clock) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          clock.clockLabel,
          style: const TextStyle(
            color: Color(0xFFF3EADD),
            fontSize: 19,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Tag ${clock.day + 1} · ${_weatherLabel(sim.world.weather)}',
          style: const TextStyle(color: Color(0x99F3EADD), fontSize: 11.5),
        ),
      ],
    );
  }

  static String _weatherLabel(Weather weather) => switch (weather) {
        Weather.clear => 'klar',
        Weather.overcast => 'bedeckt',
        Weather.rain => 'Regen am Fenster',
      };

  Widget _speedControl(SimClock clock) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final scale in TimeScale.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _SpeedChip(
              label: scale.label,
              selected: clock.scale == scale,
              onTap: () => setState(() => sim.setTimeScale(scale)),
            ),
          ),
      ],
    );
  }

  /// Die jüngste leise Beobachtung – kein Protokoll, nur eine Zeile.
  Widget _latestEvent() {
    final events = sim.world.events;
    if (events.isEmpty) return const SizedBox(height: 16);

    final latest = events.last;
    final ageMinutes = (sim.world.clock.simSeconds - latest.atSim) / 60.0;
    // Nach zwei Sim-Stunden ist eine Beobachtung keine Neuigkeit mehr.
    if (ageMinutes > 120) return const SizedBox(height: 16);

    return Opacity(
      opacity: (1.0 - ageMinutes / 120).clamp(0.0, 1.0),
      child: Text(
        latest.text,
        style: const TextStyle(
          color: Color(0xAAF3EADD),
          fontSize: 11.5,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xCC1C1926),
          borderRadius: BorderRadius.circular(11),
        ),
        child: child,
      );
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0B87C) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0x44F3EADD),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1C1926) : const Color(0xCCF3EADD),
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? const Color(0xE6C7A46B) : const Color(0xCC1C1926),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? const Color(0xFF231E17) : const Color(0xFFF3EADD),
            fontSize: 12.5,
            fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
