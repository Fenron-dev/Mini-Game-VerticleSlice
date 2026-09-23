import 'dart:math' as math;

import '../core/sim_clock.dart';
import 'house_world.dart';
import 'model/affordance_catalog.dart';
import 'model/cat.dart';
import 'model/grid.dart';
import 'model/interactable.dart';
import 'model/need.dart';
import 'model/resident.dart';
import 'model/room.dart';
import 'model/trait.dart';
import 'nav/walk_grid.dart';

/// Baut das Haus. Ein einziger Ort für die gesamte Ausgangsaufstellung –
/// Räume, Möbel, Bewohner. Alles darüber hinaus entsteht in der Simulation.
abstract final class BuildingFactory {
  static HouseWorld createDefault({math.Random? rng, DateTime? now}) {
    final random = rng ?? math.Random(20240607);
    final rooms = <Room>[];
    final objects = <InteractableObject>[];

    // ---- Treppenhaus: ein Flurabschnitt pro Ebene -------------------------
    for (var level = 0; level < HouseGeometry.levelCount; level++) {
      rooms.add(
        Room(
          id: 'hall_$level',
          name: 'Treppenhaus',
          kind: RoomKind.hall,
          level: level,
          bounds: GridRect(
            HouseGeometry.stairLeft,
            HouseGeometry.topRowOf(level) + 1,
            HouseGeometry.stairRight,
            HouseGeometry.floorRowOf(level),
          ),
          windowColumns: const [HouseGeometry.stairRight],
        ),
      );
    }

    // ---- Dach -------------------------------------------------------------
    rooms.add(_room(
      id: 'roof',
      name: 'Dachterrasse',
      kind: RoomKind.roof,
      level: HouseGeometry.roofLevel,
      left: 1,
      right: 34,
    ));
    objects.addAll([
      _obj('o_roof_bench', ObjectKind.bench, 'roof', 6, 5),
      _obj('o_roof_plant_a', ObjectKind.plant, 'roof', 14, 5),
      _obj('o_roof_plant_b', ObjectKind.plant, 'roof', 24, 5),
      _obj('o_roof_bowl', ObjectKind.catBowl, 'roof', 30, 5),
    ]);

    // ---- 4. Etage: Mira, allein unterm Dach --------------------------------
    rooms.addAll([
      _room(
          id: 'r4_bed',
          name: 'Miras Schlafzimmer',
          kind: RoomKind.bedroom,
          level: 4,
          apartmentId: 'apt4',
          left: 1,
          right: 11,
          windows: [3, 9]),
      _room(
          id: 'r4_main',
          name: 'Miras Wohnküche',
          kind: RoomKind.living,
          level: 4,
          apartmentId: 'apt4',
          left: 12,
          right: 25,
          windows: [16, 21]),
      _room(
          id: 'r4_bath',
          name: 'Miras Bad',
          kind: RoomKind.bath,
          level: 4,
          apartmentId: 'apt4',
          left: 26,
          right: 34,
          windows: [31]),
    ]);
    objects.addAll([
      _obj('o_r4_bed', ObjectKind.bed, 'r4_bed', 2, 4),
      _obj('o_r4_shelf', ObjectKind.bookshelf, 'r4_bed', 7, 4),
      _obj('o_r4_table', ObjectKind.table, 'r4_main', 13, 4),
      _obj('o_r4_sofa', ObjectKind.sofa, 'r4_main', 18, 4),
      _obj('o_r4_sink', ObjectKind.sink, 'r4_main', 22, 4),
      _obj('o_r4_stove', ObjectKind.stove, 'r4_main', 23, 4),
      _obj('o_r4_shower', ObjectKind.shower, 'r4_bath', 27, 4),
      _obj('o_r4_toilet', ObjectKind.toilet, 'r4_bath', 30, 4),
      _obj('o_r4_plant', ObjectKind.plant, 'r4_bath', 33, 4),
    ]);

    // ---- 3. Etage: Tobias & Levent ----------------------------------------
    rooms.addAll(_sharedFlatRooms(level: 3, apartmentId: 'apt3', prefix: 'r3'));
    objects.addAll(_sharedFlatObjects(level: 3, prefix: 'r3'));

    // ---- 2. Etage: Hilde ---------------------------------------------------
    rooms.addAll([
      _room(
          id: 'r2_bed',
          name: 'Hildes Schlafzimmer',
          kind: RoomKind.bedroom,
          level: 2,
          apartmentId: 'apt2',
          left: 1,
          right: 8,
          windows: [3]),
      _room(
          id: 'r2_living',
          name: 'Hildes Wohnzimmer',
          kind: RoomKind.living,
          level: 2,
          apartmentId: 'apt2',
          left: 9,
          right: 19,
          windows: [12, 17]),
      _room(
          id: 'r2_kitchen',
          name: 'Hildes Küche',
          kind: RoomKind.kitchen,
          level: 2,
          apartmentId: 'apt2',
          left: 20,
          right: 28,
          windows: [22]),
      _room(
          id: 'r2_bath',
          name: 'Hildes Bad',
          kind: RoomKind.bath,
          level: 2,
          apartmentId: 'apt2',
          left: 29,
          right: 34,
          windows: [31]),
    ]);
    objects.addAll([
      _obj('o_r2_bed', ObjectKind.bed, 'r2_bed', 1, 2),
      _obj('o_r2_shelf', ObjectKind.bookshelf, 'r2_bed', 6, 2),
      _obj('o_r2_sofa', ObjectKind.sofa, 'r2_living', 9, 2),
      _obj('o_r2_chair', ObjectKind.armchair, 'r2_living', 14, 2),
      _obj('o_r2_plant', ObjectKind.plant, 'r2_living', 18, 2),
      _obj('o_r2_stove', ObjectKind.stove, 'r2_kitchen', 20, 2),
      _obj('o_r2_sink', ObjectKind.sink, 'r2_kitchen', 23, 2),
      _obj('o_r2_fridge', ObjectKind.fridge, 'r2_kitchen', 24, 2),
      _obj('o_r2_table', ObjectKind.table, 'r2_kitchen', 26, 2),
      _obj('o_r2_shower', ObjectKind.shower, 'r2_bath', 29, 2),
      _obj('o_r2_toilet', ObjectKind.toilet, 'r2_bath', 32, 2),
      _obj('o_r2_bathsink', ObjectKind.sink, 'r2_bath', 34, 2),
    ]);

    // ---- 1. Etage: Ayla & Bruno -------------------------------------------
    rooms.addAll(_sharedFlatRooms(level: 1, apartmentId: 'apt1', prefix: 'r1'));
    objects.addAll(_sharedFlatObjects(level: 1, prefix: 'r1'));

    // ---- Keller ------------------------------------------------------------
    rooms.addAll([
      _room(
          id: 'c_laundry',
          name: 'Waschküche',
          kind: RoomKind.cellar,
          level: 0,
          left: 1,
          right: 17),
      _room(
          id: 'c_storage',
          name: 'Abstellraum',
          kind: RoomKind.cellar,
          level: 0,
          left: 18,
          right: 34),
    ]);
    objects.addAll([
      _obj('o_c_washer_a', ObjectKind.washer, 'c_laundry', 3, 0),
      _obj('o_c_washer_b', ObjectKind.washer, 'c_laundry', 7, 0),
      _obj('o_c_sink', ObjectKind.sink, 'c_laundry', 12, 0),
      _obj('o_c_boiler', ObjectKind.boiler, 'c_storage', 20, 0),
      _obj('o_c_shelf', ObjectKind.bookshelf, 'c_storage', 25, 0),
      _obj('o_c_chair', ObjectKind.armchair, 'c_storage', 30, 0),
      // Das Radio steht im gemeinschaftlichen Keller: So kommt jeder daran,
      // und der Abstellraum bekommt einen Grund, besucht zu werden.
      _obj('o_c_radio', ObjectKind.radio, 'c_storage', 33, 0),
    ]);

    // ---- Pinnwand im Erdgeschossflur --------------------------------------
    objects.add(_obj('o_pinboard', ObjectKind.pinboard, 'hall_1', 35, 1));

    // ---- Bewohner ----------------------------------------------------------
    final residents = <Resident>[
      Resident(
        id: 'mira',
        name: 'Mira',
        apartmentId: 'apt4',
        traits: const [Trait.earlyBird, Trait.greenThumb, Trait.solitary],
        needs: NeedSet.initial(random),
        startCell: GridPos(4, HouseGeometry.floorRowOf(4)),
        hue: 145,
      ),
      Resident(
        id: 'tobias',
        name: 'Tobias',
        apartmentId: 'apt3',
        traits: const [Trait.nightOwl, Trait.tidy, Trait.handy],
        needs: NeedSet.initial(random),
        startCell: GridPos(3, HouseGeometry.floorRowOf(3)),
        hue: 208,
      ),
      Resident(
        id: 'levent',
        name: 'Levent',
        apartmentId: 'apt3',
        traits: const [Trait.sociable, Trait.gourmet, Trait.restless],
        needs: NeedSet.initial(random),
        startCell: GridPos(7, HouseGeometry.floorRowOf(3)),
        hue: 28,
      ),
      Resident(
        id: 'hilde',
        name: 'Hilde',
        apartmentId: 'apt2',
        traits: const [Trait.earlyBird, Trait.tidy, Trait.sociable],
        needs: NeedSet.initial(random),
        startCell: GridPos(5, HouseGeometry.floorRowOf(2)),
        hue: 335,
      ),
      Resident(
        id: 'ayla',
        name: 'Ayla',
        apartmentId: 'apt1',
        traits: const [Trait.nightOwl, Trait.sociable, Trait.greenThumb],
        needs: NeedSet.initial(random),
        startCell: GridPos(3, HouseGeometry.floorRowOf(1)),
        hue: 268,
      ),
      Resident(
        id: 'bruno',
        name: 'Bruno',
        apartmentId: 'apt1',
        traits: const [Trait.homebody, Trait.gourmet, Trait.handy],
        needs: NeedSet.initial(random),
        startCell: GridPos(7, HouseGeometry.floorRowOf(1)),
        hue: 48,
      ),
    ];

    final apartments = [
      Apartment(
        id: 'apt4',
        label: 'Dachgeschoss',
        level: 4,
        roomIds: const ['r4_bed', 'r4_main', 'r4_bath'],
        residentIds: const ['mira'],
      ),
      Apartment(
        id: 'apt3',
        label: '3. Stock',
        level: 3,
        roomIds: const ['r3_bed', 'r3_kitchen', 'r3_living', 'r3_bath'],
        residentIds: const ['tobias', 'levent'],
      ),
      Apartment(
        id: 'apt2',
        label: '2. Stock',
        level: 2,
        roomIds: const ['r2_bed', 'r2_living', 'r2_kitchen', 'r2_bath'],
        residentIds: const ['hilde'],
      ),
      Apartment(
        id: 'apt1',
        label: '1. Stock',
        level: 1,
        roomIds: const ['r1_bed', 'r1_kitchen', 'r1_living', 'r1_bath'],
        residentIds: const ['ayla', 'bruno'],
      ),
    ];

    final cat = Cat(
      name: 'Nebel',
      start: GridPos(20, HouseGeometry.floorRowOf(2)),
      hue: 220,
    );

    final world = HouseWorld(
      clock: SimClock.fromWallClock(now),
      rooms: rooms,
      apartments: apartments,
      objects: objects,
      residents: residents,
      cat: cat,
      walkGrid: WalkGrid(),
      rng: random,
    );

    // Nachbarn kennen sich ein bisschen; Mitbewohner mehr.
    for (final a in residents) {
      for (final b in residents) {
        if (a.id == b.id) continue;
        final sameFlat = a.apartmentId == b.apartmentId;
        a.relationships[b.id] =
            sameFlat ? 0.55 : 0.05 + random.nextDouble() * 0.15;
      }
    }

    return world;
  }

  /// Die beiden Zwei-Personen-Wohnungen haben denselben Grundriss. Er steht
  /// genau einmal hier: Als die Etagen noch einzeln ausgeschrieben waren, fehlte
  /// einer von ihnen unbemerkt das Bad.
  static List<Room> _sharedFlatRooms({
    required int level,
    required String apartmentId,
    required String prefix,
  }) =>
      [
        _room(
            id: '${prefix}_bed',
            name: 'Schlafzimmer',
            kind: RoomKind.bedroom,
            level: level,
            apartmentId: apartmentId,
            left: 1,
            right: 9,
            windows: [3, 7]),
        _room(
            id: '${prefix}_kitchen',
            name: 'Küche',
            kind: RoomKind.kitchen,
            level: level,
            apartmentId: apartmentId,
            left: 10,
            right: 19,
            windows: [12]),
        _room(
            id: '${prefix}_living',
            name: 'Wohnzimmer',
            kind: RoomKind.living,
            level: level,
            apartmentId: apartmentId,
            left: 20,
            right: 28,
            windows: [23]),
        _room(
            id: '${prefix}_bath',
            name: 'Bad',
            kind: RoomKind.bath,
            level: level,
            apartmentId: apartmentId,
            left: 29,
            right: 34,
            windows: [31]),
      ];

  /// Im Wohnzimmer bleiben bewusst drei zusammenhängende Tiles frei – sonst
  /// ließe sich das Sofa nirgendwohin ziehen.
  static List<InteractableObject> _sharedFlatObjects({
    required int level,
    required String prefix,
  }) =>
      [
        _obj('o_${prefix}_bed_a', ObjectKind.bed, '${prefix}_bed', 1, level),
        _obj('o_${prefix}_bed_b', ObjectKind.bed, '${prefix}_bed', 6, level),
        _obj('o_${prefix}_stove', ObjectKind.stove, '${prefix}_kitchen', 10,
            level),
        _obj('o_${prefix}_sink', ObjectKind.sink, '${prefix}_kitchen', 13,
            level),
        _obj('o_${prefix}_fridge', ObjectKind.fridge, '${prefix}_kitchen', 15,
            level),
        _obj('o_${prefix}_table', ObjectKind.table, '${prefix}_kitchen', 17,
            level),
        _obj('o_${prefix}_sofa', ObjectKind.sofa, '${prefix}_living', 20, level),
        _obj('o_${prefix}_desk', ObjectKind.desk, '${prefix}_living', 26, level),
        _obj('o_${prefix}_plant', ObjectKind.plant, '${prefix}_living', 28,
            level),
        _obj('o_${prefix}_shower', ObjectKind.shower, '${prefix}_bath', 29,
            level),
        _obj('o_${prefix}_toilet', ObjectKind.toilet, '${prefix}_bath', 32,
            level),
        _obj('o_${prefix}_bathsink', ObjectKind.sink, '${prefix}_bath', 34,
            level),
      ];

  /// [apartmentId] `null` lässt den Raum gemeinschaftlich – Flur, Dach, Keller.
  /// Für Wohnräume ist er Pflicht: Daran hängt, dass niemand ungefragt in einer
  /// fremden Wohnung landet.
  static Room _room({
    required String id,
    required String name,
    required RoomKind kind,
    required int level,
    required int left,
    required int right,
    String? apartmentId,
    List<int> windows = const [],
  }) =>
      Room(
        id: id,
        name: name,
        kind: kind,
        level: level,
        apartmentId: apartmentId,
        bounds: GridRect(
          left,
          HouseGeometry.topRowOf(level) + 1,
          right,
          HouseGeometry.floorRowOf(level),
        ),
        windowColumns: windows,
      );

  /// Objekt auf der Bodenreihe von [level] an Spalte [x].
  static InteractableObject _obj(
    String id,
    ObjectKind kind,
    String roomId,
    int x,
    int level,
  ) =>
      InteractableObject(
        id: id,
        kind: kind,
        roomId: roomId,
        cell: GridPos(x, HouseGeometry.floorRowOf(level)),
        width: AffordanceCatalog.widthOf(kind),
        movable: AffordanceCatalog.movableOf(kind),
        affordances: AffordanceCatalog.forKind(kind),
      );
}
