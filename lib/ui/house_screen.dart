import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/ambience_controller.dart';
import '../game/vertical_slice_game.dart';
import '../persistence/save_service.dart';
import '../sim/simulation.dart';
import 'hud.dart';
import 'note_composer.dart';

/// Der Bildschirm, der alles zusammenhält: Spielstand laden, Simulation
/// starten, Lebenszyklus der App auf die Uhr der Simulation abbilden.
class HouseScreen extends StatefulWidget {
  const HouseScreen({
    super.key,
    this.saveService,
    this.enableAudio = true,
  });

  /// Einspeisbar, damit Tests ohne Dateisystem auskommen.
  final SaveService? saveService;

  /// In Tests aus: Audio braucht Plattformkanäle, die es dort nicht gibt.
  final bool enableAudio;

  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen> with WidgetsBindingObserver {
  static const String hudOverlay = 'hud';
  static const String noteOverlay = 'note';

  /// Wie oft im laufenden Betrieb gesichert wird.
  static const Duration autosaveInterval = Duration(seconds: 45);

  late final SaveService _saves = widget.saveService ?? SaveService();
  late final AmbienceController _ambience =
      AmbienceController(enabled: widget.enableAudio);

  HouseSimulation? _sim;
  VerticalSliceGame? _game;
  Timer? _autosave;
  Timer? _weatherSync;
  Timer? _noticeTimer;

  /// Wanduhrzeit, zu der die App in den Hintergrund ging.
  DateTime? _pausedAt;

  String? _returnNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    final result = await _saves.loadOrCreate();
    if (!mounted) return;

    final sim = result.simulation;
    setState(() {
      _sim = sim;
      _game = VerticalSliceGame(sim: sim, onOpenNoteComposer: _openNote);
    });
    _showNotice(result.catchUp);

    _autosave = Timer.periodic(autosaveInterval, (_) => _save());
    if (widget.enableAudio) {
      unawaited(_ambience.start());
      _weatherSync = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_ambience.syncWeather(sim.world.weather)),
      );
    }
  }

  void _showNotice(CatchUpReport? report) {
    final text = _noticeFor(report);
    if (text == null) return;
    setState(() => _returnNotice = text);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _returnNotice = null);
    });
  }

  static String? _noticeFor(CatchUpReport? report) {
    if (report == null || report.applied.inMinutes < 20) return null;
    if (report.capped) {
      return 'Das Haus hat lange ohne dich weitergelebt. '
          'Die letzten zwei Tage davon sind nachgerechnet.';
    }
    final hours = report.applied.inHours;
    if (hours < 1) {
      return 'In der Zwischenzeit sind ${report.applied.inMinutes} Minuten '
          'vergangen.';
    }
    return 'Während du weg warst, sind $hours Stunden vergangen.';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sim = _sim;
    if (sim == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // Der Spielstand ist die Voraussetzung dafür, dass die Zeit
        // weiterläuft: Ohne Zeitstempel gibt es später nichts nachzurechnen.
        _pausedAt ??= DateTime.now();
        unawaited(_save());
        unawaited(_ambience.pause());

      case AppLifecycleState.resumed:
        final since = _pausedAt;
        _pausedAt = null;
        unawaited(_ambience.resume());
        if (since == null) return;
        final gap = DateTime.now().difference(since);
        if (gap < const Duration(minutes: 1)) return;
        _showNotice(sim.catchUp(gap));

      case AppLifecycleState.detached:
        unawaited(_save());
    }
  }

  Future<void> _save() async {
    final sim = _sim;
    if (sim != null) await _saves.save(sim);
  }

  void _openNote() => _game?.overlays.add(noteOverlay);
  void _closeNote() => _game?.overlays.remove(noteOverlay);

  @override
  void dispose() {
    _autosave?.cancel();
    _weatherSync?.cancel();
    _noticeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_ambience.dispose());
    unawaited(_save());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final sim = _sim;

    if (game == null || sim == null) {
      return const ColoredBox(
        color: Color(0xFF1B2033),
        child: Center(
          child: Text(
            'Das Haus wacht auf …',
            style: TextStyle(color: Color(0x99F3EADD), fontSize: 13),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GameWidget<VerticalSliceGame>(
          game: game,
          initialActiveOverlays: const [hudOverlay],
          overlayBuilderMap: {
            hudOverlay: (context, g) =>
                Hud(simulation: sim, game: g, onPostNote: _openNote),
            noteOverlay: (context, g) =>
                NoteComposer(simulation: sim, onClose: _closeNote),
          },
        ),
        if (_returnNotice != null)
          IgnorePointer(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 58),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1C1926),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _returnNotice!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xDDF3EADD),
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
