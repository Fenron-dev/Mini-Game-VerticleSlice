import '../core/sim_clock.dart';
import 'ai/action_scorer.dart';
import 'house_world.dart';
import 'model/grid.dart';
import 'model/interactable.dart';
import 'model/need.dart';
import 'model/note.dart';
import 'model/resident.dart';
import 'systems/atmosphere_system.dart';
import 'systems/cat_system.dart';
import 'systems/decision_system.dart';
import 'systems/execution_system.dart';
import 'systems/needs_system.dart';
import 'systems/object_system.dart';
import 'systems/social_system.dart';
import 'thought_writer.dart';

/// Was die Nachberechnung nach einer Pause getan hat.
class CatchUpReport {
  CatchUpReport({
    required this.requested,
    required this.applied,
    required this.steps,
    required this.capped,
  });

  final Duration requested;
  final Duration applied;
  final int steps;

  /// `true`, wenn die Pause länger war als [HouseSimulation.maxCatchUp].
  final bool capped;

  @override
  String toString() => 'CatchUp(${applied.inMinutes} min in $steps Schritten'
      '${capped ? ', gedeckelt' : ''})';
}

/// Der Tick-Loop.
///
/// Eine feste Schrittweite trennt Simulationsgeschwindigkeit von der Bildrate:
/// Bei 16× wird nicht ein großer, ungenauer Sprung gerechnet, sondern
/// entsprechend viele kleine. Genau dieselbe Schleife erledigt auch die
/// Nachberechnung nach dem Beenden der App – nur mit gröberer Schrittweite und
/// ohne Darstellung. Dadurch gibt es keine zweite, langsam auseinanderdriftende
/// "Offline-Formel".
///
/// (Der Name vermeidet die Kollision mit Flutters `physics.Simulation`.)
class HouseSimulation {
  HouseSimulation({
    required this.world,
    ActionScorer scorer = const ActionScorer(),
  }) : decisionSystem = DecisionSystem(scorer: scorer);

  final HouseWorld world;

  final NeedsSystem needsSystem = const NeedsSystem();
  final ObjectSystem objectSystem = const ObjectSystem();
  final DecisionSystem decisionSystem;
  final ExecutionSystem executionSystem = const ExecutionSystem();
  final SocialSystem socialSystem = const SocialSystem();
  final CatSystem catSystem = const CatSystem();
  final AtmosphereSystem atmosphereSystem = const AtmosphereSystem();

  /// Feste Schrittweite im laufenden Betrieb (Sim-Sekunden).
  ///
  /// Klein genug, dass Gehen wie Gehen aussieht: Bei einem Schritt von einer
  /// ganzen Sim-Sekunde springt jemand mit 1,8 Tiles pro Sekunde sichtbar über
  /// den Boden, statt ihn entlangzulaufen. Bei 16× sind das acht Schritte pro
  /// Bild – die Systeme sind billig genug dafür.
  static const double fixedStep = 1.0 / 30.0;

  /// Gröbere Schrittweite für die Nachberechnung. Eine Sim-Minute ist fein
  /// genug: Die kürzeste Handlung im Katalog dauert fünf.
  static const double catchUpStep = 60.0;

  /// Mehr als das wird nach einer Pause nicht nachgerechnet. Wer nach zwei
  /// Wochen zurückkommt, soll kein verhungertes Haus vorfinden.
  static const Duration maxCatchUp = Duration(hours: 48);

  /// Obergrenze pro Frame, damit ein Ruckler keine Kettenreaktion auslöst.
  /// Rund 30 Sim-Sekunden – das deckt auch bei 16× einen Aussetzer von zwei
  /// Sekunden ab, ohne dass ein einzelner Frame beliebig lange rechnet.
  static const int maxStepsPerFrame = 900;

  double _accumulator = 0.0;

  /// Ein Frame echter Zeit. [realDt] in Sekunden.
  void tickReal(double realDt) {
    if (realDt <= 0) return;
    final simDelta = realDt * world.clock.scale.factor;
    _advance(simDelta, step: fixedStep, maxSteps: maxStepsPerFrame);
  }

  /// Sim-Zeit direkt vorspulen – für Tests und die Nachberechnung.
  void advanceSim(double simSeconds, {double step = fixedStep, int? maxSteps}) {
    _advance(simSeconds, step: step, maxSteps: maxSteps);
  }

  void _advance(double simSeconds, {required double step, int? maxSteps}) {
    _accumulator += simSeconds;
    var steps = 0;
    // Kleine Toleranz gegen Rundungsfehler beim Aufsummieren kleiner Schritte.
    while (_accumulator >= step - 1e-9) {
      _step(step);
      _accumulator -= step;
      steps++;
      if (maxSteps != null && steps >= maxSteps) {
        // Rückstand verwerfen statt endlos aufholen.
        _accumulator = 0;
        break;
      }
    }
  }

  /// Ein Simulationsschritt. Die Reihenfolge ist Absicht:
  /// Zustand altern → Bedürfnisse → entscheiden → handeln → Umfeld.
  void _step(double dt) {
    world.clock.advanceSim(dt);
    objectSystem.update(world, dt);
    needsSystem.update(world, dt);
    decisionSystem.update(world, dt);
    executionSystem.update(world, dt);
    socialSystem.update(world, dt);
    catSystem.update(world, dt);
    atmosphereSystem.update(world, dt);
  }

  /// Nachberechnung nach einer Pause.
  ///
  /// Offline vergeht Zeit immer 1× – der Zeitraffer ist ein Werkzeug zum
  /// Zuschauen, kein Beschleuniger im Hintergrund.
  CatchUpReport catchUp(Duration offline) {
    final capped = offline > maxCatchUp;
    final applied = capped ? maxCatchUp : offline;
    final seconds = applied.inMilliseconds / 1000.0;
    if (seconds <= 0) {
      return CatchUpReport(
        requested: offline,
        applied: Duration.zero,
        steps: 0,
        capped: false,
      );
    }

    // Rest aus dem laufenden Betrieb nicht in die Nachberechnung schleppen.
    _accumulator = 0;
    final before = world.clock.simSeconds;
    _advance(seconds, step: catchUpStep);
    _accumulator = 0;

    final advanced = world.clock.simSeconds - before;
    return CatchUpReport(
      requested: offline,
      applied: Duration(milliseconds: (advanced * 1000).round()),
      steps: (advanced / catchUpStep).round(),
      capped: capped,
    );
  }

  // ------------------------------------------------------- Sanfte Eingriffe
  //
  // Der Hausgeist kann Dinge *anbieten*, nie befehlen. Jeder Eingriff
  // verändert die Welt, keiner verändert einen Bewohner direkt.

  void setTimeScale(TimeScale scale) => world.clock.scale = scale;

  /// Pflanze gießen (Tap). Gibt `false` zurück, wenn das Objekt keine Pflanze
  /// ist – nicht, wenn sie ohnehin feucht war.
  bool waterPlant(String objectId) {
    final object = world.objectById[objectId];
    if (object == null || !object.isPlant) return false;
    final wasThirsty = object.isThirsty;
    object.moisture = 1.0;
    if (wasThirsty) {
      world.log('Jemand hat gegossen. Die Blätter richten sich auf.');
      for (final r in world.residentsNear(object.cell, radius: 6)) {
        r.needs[NeedType.contentment] = r.needs[NeedType.contentment] + 0.04;
      }
    }
    return true;
  }

  /// Objekt reparieren (Tap). Nur was kaputt ist, lässt sich reparieren.
  bool repairObject(String objectId) {
    final object = world.objectById[objectId];
    if (object == null || !object.broken) return false;
    object.broken = false;
    object.condition = 0.95;
    world.log('${object.kind.label} läuft wieder, ohne dass jemand '
        'gesehen hätte, wer es war.');
    return true;
  }

  /// Möbel umstellen (Drag). Verändert Wege und damit Gewohnheiten.
  bool moveObject(String objectId, GridPos target) =>
      world.tryMoveObject(objectId, target);

  /// Eine Nachbarschaftsnotiz anheften.
  ///
  /// Sie erzwingt kein Treffen: Sie erhöht nur den Nutzen, im Flur stehen zu
  /// bleiben. Wer erschöpft ist, geht trotzdem erst schlafen.
  NeighborhoodNote? postNote({
    required String residentA,
    required String residentB,
    required String text,
    Duration validFor = const Duration(hours: 14),
  }) {
    if (residentA == residentB) return null;
    if (!world.residentById.containsKey(residentA)) return null;
    if (!world.residentById.containsKey(residentB)) return null;

    // Nur eine offene Notiz pro Paar.
    world.notes.removeWhere(
      (n) => !n.fulfilled && n.involves(residentA) && n.involves(residentB),
    );

    final now = world.clock.simSeconds;
    final note = NeighborhoodNote(
      id: 'note_${now.toStringAsFixed(0)}_${residentA}_$residentB',
      text: text,
      residentA: residentA,
      residentB: residentB,
      postedAtSim: now,
      expiresAtSim: now + validFor.inSeconds,
    );
    world.notes.add(note);
    world.log('Ein Zettel hängt am Brett.');
    return note;
  }

  /// Gedankenblase beim Antippen eines Bewohners.
  String thoughtFor(String residentId) {
    final resident = world.residentById[residentId];
    if (resident == null) return '';
    final line = ThoughtWriter.forResident(resident, world);
    resident.lastThought = line;
    resident.lastThoughtAtSim = world.clock.simSeconds;
    return line;
  }

  /// Objekt unter einer Gitterzelle – für Tap-Ziele in der Darstellung.
  InteractableObject? objectAt(GridPos cell) {
    for (final o in world.objects) {
      if (o.footprint.contains(cell)) return o;
    }
    return null;
  }

  Resident? residentAt(GridPos cell, {double radius = 1.2}) {
    Resident? best;
    var bestDistance = radius;
    for (final r in world.residents) {
      final d = (r.x - cell.x).abs() + (r.y - cell.y).abs();
      if (d <= bestDistance) {
        bestDistance = d;
        best = r;
      }
    }
    return best;
  }
}
