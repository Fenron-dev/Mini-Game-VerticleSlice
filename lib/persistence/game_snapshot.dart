import 'dart:math' as math;

import '../core/sim_clock.dart';
import '../sim/ai/activity.dart';
import '../sim/building_factory.dart';
import '../sim/house_world.dart';
import '../sim/model/affordance.dart';
import '../sim/model/note.dart';

/// Serialisierung des Spielstands.
///
/// Grundsatz: Gespeichert wird **Zustand**, nicht Definition. Räume, Möbelarten
/// und Charaktere kommen beim Laden aus der [BuildingFactory]; der Spielstand
/// legt nur Positionen, Bedürfnisse, Beziehungen und Uhrzeit darüber. Dadurch
/// überleben Spielstände jedes Balancing-Update, und ein neues Möbelstück
/// taucht in alten Ständen einfach auf.
abstract final class GameSnapshot {
  static const int schemaVersion = 1;

  static Map<String, dynamic> capture(
    HouseWorld world, {
    DateTime? wallClock,
  }) =>
      {
        'schema': schemaVersion,
        'savedAtWall': (wallClock ?? DateTime.now()).toIso8601String(),
        'world': world.toJson(),
      };

  /// Baut eine Welt aus einem Spielstand. `null`, wenn der Stand nicht lesbar
  /// oder zu neu ist – der Aufrufer startet dann ein frisches Haus.
  static RestoredWorld? restore(
    Map<String, dynamic> json, {
    math.Random? rng,
  }) {
    final schema = json['schema'];
    if (schema is! int || schema > schemaVersion) return null;

    final worldJson = json['world'];
    if (worldJson is! Map) return null;
    final data = Map<String, dynamic>.from(worldJson);

    final world = BuildingFactory.createDefault(rng: rng);

    // ---- Uhr ---------------------------------------------------------------
    final clockJson = data['clock'];
    if (clockJson is Map) {
      final restored = SimClock.fromJson(Map<String, dynamic>.from(clockJson));
      world.clock
        ..scale = restored.scale
        ..advanceSim(restored.simSeconds - world.clock.simSeconds);
    }

    // ---- Wetter ------------------------------------------------------------
    final weatherName = data['weather'];
    if (weatherName is String) {
      world.weather = Weather.values.firstWhere(
        (w) => w.name == weatherName,
        orElse: () => Weather.overcast,
      );
    }
    world.weatherTimer = (data['weatherTimer'] as num?)?.toDouble() ?? 3600.0;

    // ---- Objekte -----------------------------------------------------------
    for (final entry in (data['objects'] as List? ?? const [])) {
      final objectJson = Map<String, dynamic>.from(entry as Map);
      // Unbekannte IDs überspringen: Möbel, die es nicht mehr gibt.
      world.objectById[objectJson['id']]?.applyJson(objectJson);
    }
    world.pathfinder.invalidate();

    // ---- Bewohner ----------------------------------------------------------
    Affordance? resolve(String objectId, String affordanceId) {
      final object = world.objectById[objectId];
      if (object == null) return null;
      for (final a in object.affordances) {
        if (a.id == affordanceId) return a;
      }
      return null;
    }

    for (final entry in (data['residents'] as List? ?? const [])) {
      final residentJson = Map<String, dynamic>.from(entry as Map);
      world.residentById[residentJson['id']]?.applyJson(
        residentJson,
        (activityJson) => Activity.fromJson(activityJson, resolve),
      );
    }

    // Reservierungen konsistent halten: Ein Objekt, dessen Belegung auf einen
    // Bewohner ohne passende Aktivität zeigt, wird frei.
    for (final object in world.objects) {
      final holder = object.occupantId;
      if (holder == null) continue;
      final activity = world.residentById[holder]?.activity;
      final holds =
          activity?.objectId == object.id && activity?.holdsOccupancy == true;
      if (!holds) object.occupantId = null;
    }

    // ---- Katze und Notizen -------------------------------------------------
    final catJson = data['cat'];
    if (catJson is Map) {
      world.cat.applyJson(Map<String, dynamic>.from(catJson));
    }

    world.notes
      ..clear()
      ..addAll(
        (data['notes'] as List? ?? const []).map(
          (e) => NeighborhoodNote.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    final savedAt = DateTime.tryParse(json['savedAtWall'] as String? ?? '');
    return RestoredWorld(world: world, savedAtWall: savedAt);
  }
}

class RestoredWorld {
  RestoredWorld({required this.world, required this.savedAtWall});

  final HouseWorld world;

  /// Wanduhrzeit beim Speichern – Grundlage der Nachberechnung.
  final DateTime? savedAtWall;

  /// Wie lange die App aus war. Negative Werte (Systemuhr zurückgestellt)
  /// werden zu null: lieber nichts nachrechnen als rückwärts.
  Duration offlineSince(DateTime now) {
    if (savedAtWall == null) return Duration.zero;
    final gap = now.difference(savedAtWall!);
    return gap.isNegative ? Duration.zero : gap;
  }
}
