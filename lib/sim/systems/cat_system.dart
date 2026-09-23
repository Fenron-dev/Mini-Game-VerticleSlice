import '../house_world.dart';
import '../model/cat.dart';
import '../model/grid.dart';
import '../model/room.dart';

/// Nebel, die Hauskatze.
///
/// Sie hat keine Bedürfnisse und kein Ziel – sie ist Bewegung im Bild. Genau
/// deshalb bekommt sie ein eigenes, sehr kleines System statt einer
/// Sonderbehandlung im Bewohner-Code.
class CatSystem {
  const CatSystem();

  static const double walkSpeed = 1.1;
  static const double stairSpeed = 0.7;

  void update(HouseWorld world, double dtSim) {
    final cat = world.cat;
    cat.stateTimer -= dtSim;

    if (cat.path.isNotEmpty) {
      _move(cat, dtSim);
      return;
    }

    if (cat.stateTimer > 0) return;

    // Neuer Einfall. Katzen sind mehrheitlich müde.
    final roll = world.rng.nextDouble();
    if (roll < 0.45) {
      cat.mood = CatMood.doze;
      cat.stateTimer = 90 + world.rng.nextDouble() * 420;
    } else if (roll < 0.6) {
      cat.mood = CatMood.watch;
      cat.stateTimer = 40 + world.rng.nextDouble() * 120;
    } else {
      cat.mood = CatMood.wander;
      cat.stateTimer = 30 + world.rng.nextDouble() * 90;
      _chooseDestination(world, cat);
    }
  }

  void _chooseDestination(HouseWorld world, Cat cat) {
    final candidates = world.rooms
        .where((r) => r.kind != RoomKind.bath)
        .toList(growable: false);
    if (candidates.isEmpty) return;

    final room = candidates[world.rng.nextInt(candidates.length)];
    final span = room.bounds.right - room.bounds.left;
    final x = room.bounds.left + world.rng.nextInt(span + 1);
    final target = GridPos(x, room.floorRow);

    final path = world.pathfinder.findPath(cat.cell, target);
    if (path != null) cat.path = List.of(path);
  }

  void _move(Cat cat, double dtSim) {
    var budget = dtSim;
    while (budget > 0 && cat.path.isNotEmpty) {
      final next = cat.path.first;
      final dx = next.x - cat.x;
      final dy = next.y - cat.y;
      final distance = dx.abs() + dy.abs();
      if (distance < 1e-6) {
        cat.path.removeAt(0);
        continue;
      }

      final onFloorRow =
          HouseGeometry.floorRowOf(HouseGeometry.levelOfRow(next.y)) == next.y;
      final speed = (!onFloorRow && HouseGeometry.isStairColumn(next.x))
          ? stairSpeed
          : walkSpeed;
      final reachable = speed * budget;

      if (reachable >= distance) {
        cat.x = next.x.toDouble();
        cat.y = next.y.toDouble();
        if (dx.abs() > 1e-6) cat.facing = dx > 0 ? 1 : -1;
        budget -= distance / speed;
        cat.path.removeAt(0);
      } else {
        if (dx.abs() > 1e-6) {
          cat.x += reachable * (dx > 0 ? 1 : -1);
          cat.facing = dx > 0 ? 1 : -1;
        } else {
          cat.y += reachable * (dy > 0 ? 1 : -1);
        }
        budget = 0;
      }
    }
  }
}
