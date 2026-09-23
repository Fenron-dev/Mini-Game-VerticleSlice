import '../house_world.dart';
import '../model/room.dart';

/// Wetter und Licht – die Systeme, die nichts entscheiden, aber alles färben.
class AtmosphereSystem {
  const AtmosphereSystem();

  /// Unterhalb dieser Tageshelligkeit macht man Licht an.
  static const double lightThreshold = 0.42;

  void update(HouseWorld world, double dtSim) {
    _weather(world, dtSim);
    _lighting(world);
  }

  void _weather(HouseWorld world, double dtSim) {
    world.weatherTimer -= dtSim;
    if (world.weatherTimer > 0) return;

    // Weiche Übergänge: aus Regen wird eher bedeckt als schlagartig klar.
    final roll = world.rng.nextDouble();
    world.weather = switch (world.weather) {
      Weather.clear when roll < 0.55 => Weather.clear,
      Weather.clear when roll < 0.9 => Weather.overcast,
      Weather.clear => Weather.rain,
      Weather.overcast when roll < 0.35 => Weather.clear,
      Weather.overcast when roll < 0.7 => Weather.overcast,
      Weather.overcast => Weather.rain,
      Weather.rain when roll < 0.1 => Weather.clear,
      Weather.rain when roll < 0.6 => Weather.overcast,
      Weather.rain => Weather.rain,
    };
    world.weatherTimer = (1.5 + world.rng.nextDouble() * 4.0) * 3600.0;
  }

  /// Welche Fenster leuchten? Licht folgt Menschen, nicht der Uhr allein.
  void _lighting(HouseWorld world) {
    world.litRooms.clear();
    if (world.clock.daylight >= lightThreshold) return;

    for (final resident in world.residents) {
      if (resident.isAsleep) continue;
      final room = world.roomAt(resident.cell);
      if (room == null) continue;
      world.litRooms.add(room.id);

      // Im Treppenhaus geht das Licht für das ganze Haus an – so sieht man
      // jemanden nachts nach Hause kommen.
      if (room.kind == RoomKind.hall) {
        for (final r in world.rooms) {
          if (r.kind == RoomKind.hall) world.litRooms.add(r.id);
        }
      }
    }
  }
}
