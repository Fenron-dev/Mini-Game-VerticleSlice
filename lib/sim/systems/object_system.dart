import '../house_world.dart';
import '../model/affordance_catalog.dart';
import '../model/interactable.dart';

/// Pflegt den Zustand der Dinge: Pflanzen trocknen aus, Geräte verschleißen und
/// gehen gelegentlich kaputt.
///
/// Defekte sind kein Schaden, den man "verliert" – sie sind ein Anlass. Ein
/// kaputter Herd bringt Bruno (handwerklich) ins Schrauben.
class ObjectSystem {
  const ObjectSystem();

  /// Austrocknung pro Sim-Stunde. ~2 Tage von frisch gegossen bis durstig.
  static const double plantDryingPerHour = 0.021;

  /// Grundwahrscheinlichkeit eines Defekts pro Sim-Stunde bei Fragilität 1.0.
  static const double breakChancePerHour = 0.0045;

  void update(HouseWorld world, double dtSim) {
    final hours = dtSim / 3600.0;

    for (final object in world.objects) {
      if (object.isPlant) {
        final wasThirsty = object.isThirsty;
        object.moisture =
            (object.moisture - plantDryingPerHour * hours).clamp(0.0, 1.0);
        if (!wasThirsty && object.isThirsty) {
          final room = world.roomById[object.roomId];
          world.log('Die Pflanze in ${room?.name ?? 'einem Raum'} '
              'lässt die Blätter hängen.');
        }
        continue;
      }

      final fragility = AffordanceCatalog.fragilityOf(object.kind);
      if (fragility <= 0 || object.broken) continue;

      // Je abgenutzter, desto wahrscheinlicher – aber nie garantiert.
      final wearFactor = 0.25 + (1.0 - object.condition);
      final p = breakChancePerHour * fragility * wearFactor * hours;
      if (p > 0 && world.rng.nextDouble() < p) {
        _breakObject(world, object);
      }
    }
  }

  void _breakObject(HouseWorld world, InteractableObject object) {
    object.broken = true;
    final room = world.roomById[object.roomId];
    world.log('${object.kind.label} in ${room?.name ?? 'dem Haus'} '
        'gibt ein letztes Seufzen von sich.');
  }

  /// Verschleiß nach einer Nutzung. Wird vom ExecutionSystem aufgerufen.
  static void applyWear(InteractableObject object, double amount) {
    if (amount <= 0) return;
    object.condition = (object.condition - amount).clamp(0.0, 1.0);
  }
}
