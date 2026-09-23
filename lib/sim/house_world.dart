import 'dart:math' as math;

import '../core/sim_clock.dart';
import 'model/cat.dart';
import 'model/grid.dart';
import 'model/interactable.dart';
import 'model/note.dart';
import 'model/resident.dart';
import 'model/room.dart';
import 'nav/pathfinder.dart';
import 'nav/walk_grid.dart';

enum Weather {
  clear('klar'),
  overcast('bedeckt'),
  rain('Regen');

  const Weather(this.label);
  final String label;
}

/// Eine leise Notiz über etwas, das passiert ist. Kein Punktestand – nur ein
/// Protokoll, aus dem die Oberfläche gelegentlich eine Zeile zeigt.
class SimEvent {
  SimEvent(this.atSim, this.text, {this.residentId});
  final double atSim;
  final String text;
  final String? residentId;
}

/// Der gesamte Zustand des Hauses.
///
/// Bewusst frei von Flutter- und Flame-Abhängigkeiten: Die Welt lässt sich in
/// einem reinen Dart-Test tausend Sim-Stunden weit laufen. Die Darstellung
/// liest hier nur ab. (Der Name vermeidet die Kollision mit Flames `World`.)
class HouseWorld {
  HouseWorld({
    required this.clock,
    required this.rooms,
    required this.apartments,
    required this.objects,
    required this.residents,
    required this.cat,
    required this.walkGrid,
    math.Random? rng,
  })  : rng = rng ?? math.Random(20240607),
        pathfinder = Pathfinder(walkGrid),
        roomById = {for (final r in rooms) r.id: r},
        objectById = {for (final o in objects) o.id: o},
        residentById = {for (final r in residents) r.id: r};

  final SimClock clock;
  final List<Room> rooms;
  final List<Apartment> apartments;
  final List<InteractableObject> objects;
  final List<Resident> residents;
  final Cat cat;
  final WalkGrid walkGrid;
  final Pathfinder pathfinder;
  final math.Random rng;

  final Map<String, Room> roomById;
  final Map<String, InteractableObject> objectById;
  final Map<String, Resident> residentById;

  final List<NeighborhoodNote> notes = [];

  Weather weather = Weather.overcast;

  /// Sim-Sekunden bis zum nächsten möglichen Wetterwechsel.
  double weatherTimer = 3 * 3600.0;

  final List<SimEvent> events = [];

  /// Räume, in denen gerade Licht brennt (vom AtmosphereSystem gepflegt).
  final Set<String> litRooms = {};

  void log(String text, {String? residentId}) {
    events.add(SimEvent(clock.simSeconds, text, residentId: residentId));
    if (events.length > 60) events.removeRange(0, events.length - 60);
  }

  Room? roomAt(GridPos p) {
    for (final r in rooms) {
      if (r.bounds.contains(p)) return r;
    }
    return null;
  }

  Iterable<InteractableObject> objectsInRoom(String roomId) =>
      objects.where((o) => o.roomId == roomId);

  Iterable<InteractableObject> objectsOfKind(ObjectKind kind) =>
      objects.where((o) => o.kind == kind);

  Apartment? apartmentOf(String apartmentId) {
    for (final a in apartments) {
      if (a.id == apartmentId) return a;
    }
    return null;
  }

  /// Andere Bewohner in Reichweite – Basis für Sozialgewinne und dafür, dass
  /// gemeinsame Aktionen attraktiver werden, wenn jemand da ist.
  List<Resident> residentsNear(GridPos p, {double radius = 4.0}) {
    final out = <Resident>[];
    for (final r in residents) {
      final dx = r.x - p.x;
      final dy = r.y - p.y;
      if (math.sqrt(dx * dx + dy * dy) <= radius) out.add(r);
    }
    return out;
  }

  List<NeighborhoodNote> activeNotesFor(String residentId) => notes
      .where((n) => n.isActive(clock.simSeconds) && n.involves(residentId))
      .toList();

  /// Möbel umstellen. Gibt `true` zurück, wenn der Platz gültig war.
  ///
  /// Das ist die eine Interaktion, die das Verhalten wirklich verändert: Weil
  /// der ActionScorer Wegkosten einrechnet, verschiebt ein Sofa neben dem
  /// Fenster tatsächlich, wo jemand seinen Abend verbringt.
  bool tryMoveObject(String objectId, GridPos target) {
    final obj = objectById[objectId];
    if (obj == null || !obj.movable) return false;
    if (obj.isOccupied) return false;

    final row = target.y.clamp(0, HouseGeometry.gridHeight - 1);
    final level = HouseGeometry.levelOfRow(row);
    final snapped = GridPos(target.x, HouseGeometry.floorRowOf(level));

    final room = roomAt(snapped);
    if (room == null || room.kind == RoomKind.hall) return false;

    // Vollständig innerhalb des Raums?
    if (snapped.x < room.bounds.left ||
        snapped.x + obj.width - 1 > room.bounds.right) {
      return false;
    }

    // Kollision mit anderen Möbeln?
    final newRight = snapped.x + obj.width - 1;
    for (final other in objects) {
      if (other.id == obj.id) continue;
      if (other.cell.y != snapped.y) continue;
      final otherRight = other.cell.x + other.width - 1;
      if (snapped.x <= otherRight && newRight >= other.cell.x) return false;
    }

    obj.moveTo(snapped, room.id);
    pathfinder.invalidate();
    log('${obj.kind.label} steht jetzt in ${room.name}.');
    return true;
  }

  Map<String, dynamic> toJson() => {
        'clock': clock.toJson(),
        'weather': weather.name,
        'weatherTimer': weatherTimer,
        'objects': objects.map((o) => o.toJson()).toList(),
        'residents': residents.map((r) => r.toJson()).toList(),
        'cat': cat.toJson(),
        'notes': notes.map((n) => n.toJson()).toList(),
      };
}
