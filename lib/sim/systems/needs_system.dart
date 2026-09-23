import '../house_world.dart';

/// Lässt Bedürfnisse über die Zeit verfallen.
///
/// Bewusst das erste Bewohner-System im Tick: Alles andere reagiert auf den
/// Zustand, den dieses System hinterlässt.
class NeedsSystem {
  const NeedsSystem();

  void update(HouseWorld world, double dtSim) {
    final hours = dtSim / 3600.0;
    for (final resident in world.residents) {
      resident.needs.decay(
        hours,
        decayMultipliers: resident.profile.decayMultipliers,
        asleep: resident.isAsleep,
      );
    }
  }
}
