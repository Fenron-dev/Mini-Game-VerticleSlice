import 'dart:convert';

import '../sim/building_factory.dart';
import '../sim/simulation.dart';
import 'game_snapshot.dart';
import 'save_store.dart';

/// Ergebnis des Startvorgangs: die laufbereite Simulation und, falls die App
/// pausiert war, der Bericht über die Nachberechnung.
class LoadResult {
  LoadResult({required this.simulation, this.catchUp, required this.wasFresh});

  final HouseSimulation simulation;
  final CatchUpReport? catchUp;

  /// `true`, wenn kein (brauchbarer) Spielstand vorlag.
  final bool wasFresh;
}

/// Verbindet Ablage, Serialisierung und Nachberechnung.
class SaveService {
  SaveService({SaveStore? store}) : store = store ?? FileSaveStore();

  final SaveStore store;

  /// Lädt den Spielstand und rechnet die Zeit nach, die die App aus war.
  Future<LoadResult> loadOrCreate({DateTime? now}) async {
    final wallNow = now ?? DateTime.now();
    final raw = await store.read();

    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final restored = GameSnapshot.restore(json);
        if (restored != null) {
          final simulation = HouseSimulation(world: restored.world);
          final gap = restored.offlineSince(wallNow);
          final report = gap > Duration.zero ? simulation.catchUp(gap) : null;
          return LoadResult(
            simulation: simulation,
            catchUp: report,
            wasFresh: false,
          );
        }
      } on FormatException {
        // Beschädigter Stand: still verwerfen und neu anfangen. Ein Haus ist
        // keine Buchhaltung – ein Fehlerdialog wäre hier fehl am Platz.
      } on TypeError {
        // dito: Struktur passt nicht mehr zum Code.
      }
    }

    final world = BuildingFactory.createDefault(now: wallNow);
    return LoadResult(
      simulation: HouseSimulation(world: world),
      wasFresh: true,
    );
  }

  Future<void> save(HouseSimulation simulation, {DateTime? now}) async {
    final json = GameSnapshot.capture(simulation.world, wallClock: now);
    await store.write(jsonEncode(json));
  }

  Future<void> reset() => store.clear();
}
