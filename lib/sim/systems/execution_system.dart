import '../ai/activity.dart';
import '../house_world.dart';
import '../model/cat.dart';
import '../model/grid.dart';
import '../model/interactable.dart';
import '../model/resident.dart';
import 'object_system.dart';

/// Führt aus, was das DecisionSystem beschlossen hat: laufen, dann tun.
///
/// Bewegung und Ausführung teilen sich ein System, weil sie zwei Phasen
/// derselben Aktivität sind – die Trennung würde nur Zustand hin- und
/// herreichen.
class ExecutionSystem {
  const ExecutionSystem();

  /// Tiles pro Sim-Sekunde auf ebenem Boden.
  static const double walkSpeed = 1.8;

  /// Treppensteigen ist langsamer – man sieht Leute im Schacht.
  static const double stairSpeed = 0.9;

  void update(HouseWorld world, double dtSim) {
    for (final resident in world.residents) {
      final activity = resident.activity;
      if (activity == null || activity.isDone) continue;

      final object = world.objectById[activity.objectId];
      if (object == null) {
        activity.phase = ActivityPhase.finished;
        continue;
      }

      // Während der Ausführung kaputtgegangen? Dann eben nicht.
      if (activity.isPerforming &&
          activity.affordance.requiresWorking &&
          object.broken) {
        _finish(world, resident, activity, object, completed: false);
        continue;
      }

      if (activity.isTraveling) {
        _travel(world, resident, activity, object, dtSim);
      } else if (activity.isPerforming) {
        _perform(world, resident, activity, object, dtSim);
      }
    }
  }

  // ---------------------------------------------------------------- Bewegung

  void _travel(
    HouseWorld world,
    Resident resident,
    Activity activity,
    InteractableObject object,
    double dtSim,
  ) {
    var budget = dtSim;

    while (budget > 0 && activity.path.isNotEmpty) {
      final next = activity.path.first;
      final dx = next.x - resident.x;
      final dy = next.y - resident.y;
      final distance = dx.abs() + dy.abs();

      if (distance < 1e-6) {
        activity.path.removeAt(0);
        continue;
      }

      final speed = _speedAt(next);
      final reachable = speed * budget;

      if (reachable >= distance) {
        resident.x = next.x.toDouble();
        resident.y = next.y.toDouble();
        budget -= distance / speed;
        if (dx.abs() > 1e-6) resident.facing = dx > 0 ? 1 : -1;
        activity.path.removeAt(0);
      } else {
        // Gitterschritte sind achsenparallel – genau eine Komponente bewegt sich.
        if (dx.abs() > 1e-6) {
          resident.x += reachable * (dx > 0 ? 1 : -1);
          resident.facing = dx > 0 ? 1 : -1;
        } else {
          resident.y += reachable * (dy > 0 ? 1 : -1);
        }
        budget = 0;
      }
    }

    if (activity.path.isEmpty) {
      _arrive(world, resident, activity, object);
    }
  }

  double _speedAt(GridPos cell) {
    final onFloorRow =
        HouseGeometry.floorRowOf(HouseGeometry.levelOfRow(cell.y)) == cell.y;
    if (!onFloorRow && HouseGeometry.isStairColumn(cell.x)) return stairSpeed;
    return walkSpeed;
  }

  void _arrive(
    HouseWorld world,
    Resident resident,
    Activity activity,
    InteractableObject object,
  ) {
    // In der Zwischenzeit belegt oder kaputt? Dann unverrichteter Dinge zurück
    // in die Entscheidungsschleife – kein Warteschlangen-Drama.
    final blocked = activity.affordance.requiresWorking && object.broken;
    final takenByOther =
        object.occupantId != null && object.occupantId != resident.id;
    if (blocked || (activity.affordance.exclusive && takenByOther)) {
      _finish(world, resident, activity, object, completed: false);
      return;
    }

    resident.x = object.useCell.x.toDouble();
    resident.y = object.useCell.y.toDouble();
    if (activity.affordance.exclusive) {
      object.occupantId = resident.id;
      activity.holdsOccupancy = true;
    }
    activity.phase = ActivityPhase.performing;
  }

  // -------------------------------------------------------------- Ausführung

  void _perform(
    HouseWorld world,
    Resident resident,
    Activity activity,
    InteractableObject object,
    double dtSim,
  ) {
    resident.needs.applyRates(activity.affordance.rates, dtSim / 3600.0);
    activity.remainingMinutes -= dtSim / 60.0;

    if (activity.remainingMinutes <= 0) {
      _finish(world, resident, activity, object, completed: true);
    }
  }

  void _finish(
    HouseWorld world,
    Resident resident,
    Activity activity,
    InteractableObject object, {
    required bool completed,
  }) {
    if (activity.holdsOccupancy && object.occupantId == resident.id) {
      object.occupantId = null;
    }
    activity.holdsOccupancy = false;
    activity.phase = ActivityPhase.finished;

    if (!completed) {
      // Kurze Pause, damit nicht sofort dasselbe wieder versucht wird.
      resident.nextDecisionAt = world.clock.simSeconds + 8.0;
      return;
    }

    ObjectSystem.applyWear(object, activity.affordance.wearPerUse);
    if (activity.affordance.cooldownMinutes > 0) {
      object.cooldownUntil =
          world.clock.simSeconds + activity.affordance.cooldownMinutes * 60.0;
    }
    resident.rememberAffordance(activity.affordance.id);
    _applyCompletionEffect(world, resident, activity, object);
    resident.nextDecisionAt = world.clock.simSeconds;
  }

  /// Nebenwirkungen abgeschlossener Handlungen – der einzige Ort, an dem eine
  /// Affordance mehr tut, als Bedürfnisse zu verschieben.
  void _applyCompletionEffect(
    HouseWorld world,
    Resident resident,
    Activity activity,
    InteractableObject object,
  ) {
    switch (activity.affordance.id) {
      case 'water_plant':
        object.moisture = 1.0;
        world.log('${resident.name} hat gegossen. Die Erde riecht dunkel.',
            residentId: resident.id);

      case 'tend_plant':
        object.moisture = (object.moisture + 0.1).clamp(0.0, 1.0);

      case 'repair':
        object.broken = false;
        object.condition = 0.82;
        world.log(
          '${resident.name} hat ${object.kind.label} wieder zum Laufen gebracht.',
          residentId: resident.id,
        );

      case 'feed_cat':
        world.cat.mood = CatMood.beg;
        world.cat.stateTimer = 120;
        world.log('${resident.name} füllt den Napf. Nebel taucht auf.',
            residentId: resident.id);

      case 'sleep':
        world.log('${resident.name} ist aufgewacht.', residentId: resident.id);

      case 'cook':
        world.log('Es riecht nach Essen im Treppenhaus.',
            residentId: resident.id);

      default:
        break;
    }
  }
}
