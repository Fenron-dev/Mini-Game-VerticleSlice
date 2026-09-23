import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_slice/core/sim_clock.dart';
import 'package:vertical_slice/sim/building_factory.dart';
import 'package:vertical_slice/sim/house_world.dart';
import 'package:vertical_slice/sim/model/grid.dart';
import 'package:vertical_slice/sim/model/need.dart';
import 'package:vertical_slice/sim/simulation.dart';

HouseSimulation freshSim({int seed = 3, int hour = 7}) => HouseSimulation(
      world: BuildingFactory.createDefault(
        rng: math.Random(seed),
        now: DateTime(2024, 6, 7, hour),
      ),
    );

/// Erste Position im Raum, auf die [objectId] tatsächlich passt. Das Objekt
/// bleibt dabei stehen, wo es war – die Suche stellt jeden Treffer zurück.
GridPos freeSpotFor(HouseSimulation sim, String objectId, String roomId) {
  final object = sim.world.objectById[objectId]!;
  final room = sim.world.roomById[roomId]!;
  final start = object.cell;
  for (var x = room.bounds.left; x <= room.bounds.right; x++) {
    final target = GridPos(x, room.floorRow);
    if (target == start) continue;
    if (sim.moveObject(objectId, target)) {
      sim.moveObject(objectId, start);
      return target;
    }
  }
  throw StateError('Kein freier Platz für $objectId in $roomId');
}

/// Sim-Minuten am Stück – die Schrittweite der Nachberechnung.
void runMinutes(HouseSimulation sim, int minutes) {
  for (var i = 0; i < minutes; i++) {
    sim.advanceSim(60, step: 60);
  }
}

void main() {
  group('Tick-Loop', () {
    test('Zeitraffer skaliert die Sim-Zeit', () {
      final sim = freshSim();
      final before = sim.world.clock.simSeconds;
      sim.world.clock.scale = TimeScale.x4;
      sim.tickReal(0.5); // eine halbe Sekunde echte Zeit
      expect(sim.world.clock.simSeconds - before, closeTo(2.0, 0.1));
    });

    test('1× entspricht Echtzeit', () {
      final sim = freshSim();
      final before = sim.world.clock.simSeconds;
      for (var i = 0; i < 60; i++) {
        sim.tickReal(1 / 60);
      }
      expect(sim.world.clock.simSeconds - before, closeTo(1.0, 0.05));
    });

    test('ein einzelner riesiger Frame reißt die Simulation nicht mit', () {
      final sim = freshSim();
      final before = sim.world.clock.simSeconds;
      sim.world.clock.scale = TimeScale.x16;
      sim.tickReal(60); // ein hängengebliebener Frame von einer Minute
      expect(
        sim.world.clock.simSeconds - before,
        lessThanOrEqualTo(
          HouseSimulation.maxStepsPerFrame * HouseSimulation.fixedStep +
              HouseSimulation.fixedStep,
        ),
      );
    });

    test('Gehen ist fließend, nicht sprunghaft', () {
      // Regression: Bei einer Schrittweite von einer Sim-Sekunde sprang
      // jemand 1,8 Tiles pro Update.
      final sim = freshSim();
      var maxJump = 0.0;
      final last = {for (final r in sim.world.residents) r.id: r.x};
      for (var i = 0; i < 600; i++) {
        sim.tickReal(1 / 60);
        for (final r in sim.world.residents) {
          maxJump = math.max(maxJump, (r.x - last[r.id]!).abs());
          last[r.id] = r.x;
        }
      }
      expect(maxJump, lessThan(0.2));
    });
  });

  group('Eine Woche im Haus', () {
    test('läuft ohne Ausnahme und ohne Wertebruch', () {
      final sim = freshSim();
      runMinutes(sim, 7 * 24 * 60);
      for (final r in sim.world.residents) {
        for (final n in NeedType.values) {
          expect(r.needs[n], inInclusiveRange(0.0, 1.0));
        }
        expect(r.x.isFinite && r.y.isFinite, isTrue);
      }
    });

    test('niemand verhungert oder verwahrlost', () {
      // Der erste Tag ist Einschwingen; danach muss das Haus tragen.
      for (final seed in [1, 2, 3, 4]) {
        final sim = freshSim(seed: seed);
        runMinutes(sim, 24 * 60);

        var worst = 1.0;
        String? worstLabel;
        for (var i = 0; i < 6 * 24 * 60; i++) {
          sim.advanceSim(60, step: 60);
          for (final r in sim.world.residents) {
            for (final n in NeedType.values) {
              if (r.needs[n] < worst) {
                worst = r.needs[n];
                worstLabel = '${r.name}/${n.name}';
              }
            }
          }
        }
        expect(worst, greaterThan(0.02),
            reason: 'Seed $seed, schlechtester Wert bei $worstLabel');
      }
    });

    test('alle schlafen jeden Tag', () {
      final sim = freshSim();
      final sleepDays = <String, Set<int>>{};
      for (var i = 0; i < 7 * 24 * 60; i++) {
        sim.advanceSim(60, step: 60);
        for (final r in sim.world.residents) {
          if (r.isAsleep) {
            (sleepDays[r.id] ??= <int>{}).add(sim.world.clock.day);
          }
        }
      }
      for (final r in sim.world.residents) {
        expect(sleepDays[r.id]?.length ?? 0, greaterThanOrEqualTo(6),
            reason: '${r.name} hat zu selten geschlafen');
      }
    });

    test('niemand verschläft den ganzen Tag', () {
      // Regression: Wer seinen Weckzeitpunkt knapp verpasste, bekam 22
      // Stunden Restabstand und schlief durch den Tag.
      final sim = freshSim();
      runMinutes(sim, 2 * 24 * 60);
      final asleepMinutes = <String, int>{};
      for (var i = 0; i < 24 * 60; i++) {
        sim.advanceSim(60, step: 60);
        for (final r in sim.world.residents) {
          if (r.isAsleep) asleepMinutes[r.id] = (asleepMinutes[r.id] ?? 0) + 1;
        }
      }
      for (final entry in asleepMinutes.entries) {
        expect(entry.value, lessThan(14 * 60), reason: entry.key);
      }
    });

    test('Bewohner bleiben nicht auf ihrer Etage kleben', () {
      final sim = freshSim();
      final levels = <String, Set<int>>{};
      for (var i = 0; i < 7 * 24 * 60; i++) {
        sim.advanceSim(60, step: 60);
        for (final r in sim.world.residents) {
          (levels[r.id] ??= <int>{}).add(r.level);
        }
      }
      // Sonst sind Treppenhaus, Dach und Keller totes Kapital.
      expect(levels.values.any((s) => s.length > 1), isTrue,
          reason: 'Niemand hat in einer Woche die Etage gewechselt');
    });

    test('exklusive Objekte werden nie doppelt belegt', () {
      final sim = freshSim();
      for (var i = 0; i < 3 * 24 * 60; i++) {
        sim.advanceSim(60, step: 60);
        final holders = <String, List<String>>{};
        for (final r in sim.world.residents) {
          final a = r.activity;
          if (a != null && a.holdsOccupancy) {
            (holders[a.objectId] ??= []).add(r.id);
          }
        }
        for (final entry in holders.entries) {
          expect(entry.value.length, 1,
              reason: '${entry.key} von ${entry.value} gleichzeitig belegt');
        }
      }
    });

    test('Belegung wird immer wieder freigegeben', () {
      final sim = freshSim();
      runMinutes(sim, 3 * 24 * 60);
      final stuck = sim.world.objects.where((o) {
        if (o.occupantId == null) return false;
        final r = sim.world.residentById[o.occupantId!];
        return r?.activity?.objectId != o.id;
      });
      expect(stuck, isEmpty);
    });
  });

  group('Pflanzen und Defekte', () {
    test('Pflanzen trocknen aus, wenn niemand gießt', () {
      final sim = freshSim();
      final plant = sim.world.objectById['o_roof_plant_a']!..moisture = 1.0;
      runMinutes(sim, 24 * 60);
      expect(plant.moisture, lessThan(1.0));
    });

    test('Gießen per Tap macht eine durstige Pflanze satt', () {
      final sim = freshSim();
      final plant = sim.world.objectById['o_r1_plant']!..moisture = 0.1;
      expect(sim.waterPlant(plant.id), isTrue);
      expect(plant.moisture, 1.0);
      expect(plant.isThirsty, isFalse);
    });

    test('Gießen greift nur bei Pflanzen', () {
      final sim = freshSim();
      expect(sim.waterPlant('o_r1_sofa'), isFalse);
      expect(sim.waterPlant('gibt_es_nicht'), isFalse);
    });

    test('Reparieren per Tap wirkt nur auf Kaputtes', () {
      final sim = freshSim();
      final washer = sim.world.objectById['o_c_washer_a']!;
      expect(sim.repairObject(washer.id), isFalse, reason: 'noch heil');

      washer.broken = true;
      expect(sim.repairObject(washer.id), isTrue);
      expect(washer.broken, isFalse);
      expect(washer.condition, greaterThan(0.9));
    });

    test('ein Defekt wird von jemandem im Haus repariert', () {
      // Regression: Solange Reparieren nur Zufriedenheit brachte, hat niemand
      // je etwas repariert – eine kaputte Dusche blieb eine ganze Woche kaputt.
      final sim = freshSim();
      final shower = sim.world.objectById['o_r1_shower']!..broken = true;
      var repaired = false;
      for (var i = 0; i < 2 * 24 * 60 && !repaired; i++) {
        sim.advanceSim(60, step: 60);
        repaired = !shower.broken;
      }
      expect(repaired, isTrue, reason: 'Die Dusche blieb zwei Tage kaputt');
    });

    test('ein defektes Objekt beendet die laufende Nutzung', () {
      final sim = freshSim();
      var victim = -1;
      for (var i = 0; i < 600 && victim < 0; i++) {
        sim.advanceSim(60, step: 60);
        for (var j = 0; j < sim.world.residents.length; j++) {
          final a = sim.world.residents[j].activity;
          if (a != null && a.isPerforming && a.affordance.requiresWorking) {
            victim = j;
            break;
          }
        }
      }
      expect(victim, greaterThanOrEqualTo(0), reason: 'niemand war beschäftigt');

      final resident = sim.world.residents[victim];
      final object = sim.world.objectById[resident.activity!.objectId]!;
      object.broken = true;
      sim.advanceSim(60, step: 60);
      expect(object.occupantId, isNot(resident.id));
    });
  });

  group('Möbel umstellen', () {
    test('jedes Wohnzimmer hat Platz, das Sofa woandershin zu stellen', () {
      // Ohne freie Fläche wäre "Möbel per Drag umstellen" eine Funktion, die
      // nie auslöst.
      for (final prefix in ['r1', 'r3']) {
        final sim = freshSim();
        expect(
          () => freeSpotFor(sim, 'o_${prefix}_sofa', '${prefix}_living'),
          returnsNormally,
        );
      }
    });

    test('gültiges Ziel im selben Raum wird übernommen', () {
      final sim = freshSim();
      final sofa = sim.world.objectById['o_r1_sofa']!;
      final target = freeSpotFor(sim, sofa.id, 'r1_living');
      expect(sim.moveObject(sofa.id, target), isTrue);
      expect(sofa.cell, target);
      expect(sofa.roomId, 'r1_living');
    });

    test('rastet auf die Bodenreihe ein', () {
      final sim = freshSim();
      final sofa = sim.world.objectById['o_r1_sofa']!;
      final room = sim.world.roomById['r1_living']!;
      final target = freeSpotFor(sim, sofa.id, room.id);
      expect(
        sim.moveObject(sofa.id, GridPos(target.x, room.floorRow - 4)),
        isTrue,
      );
      expect(sofa.cell.y, room.floorRow);
    });

    test('über die Raumgrenze hinaus wird abgelehnt', () {
      final sim = freshSim();
      final sofa = sim.world.objectById['o_r1_sofa']!;
      final before = sofa.cell;
      final room = sim.world.roomById['r1_living']!;
      expect(
        sim.moveObject(sofa.id, GridPos(room.bounds.right, room.floorRow)),
        isFalse,
      );
      expect(sofa.cell, before);
    });

    test('auf ein anderes Möbel wird abgelehnt', () {
      final sim = freshSim();
      final sofa = sim.world.objectById['o_r1_sofa']!;
      final desk = sim.world.objectById['o_r1_desk']!;
      final before = sofa.cell;
      expect(sim.moveObject(sofa.id, desk.cell), isFalse);
      expect(sofa.cell, before);
    });

    test('Installationen bleiben, wo sie sind', () {
      final sim = freshSim();
      final shower = sim.world.objectById['o_r1_shower']!;
      final before = shower.cell;
      expect(sim.moveObject(shower.id, GridPos(31, shower.cell.y)), isFalse);
      expect(shower.cell, before);
    });

    test('ins Treppenhaus wird nicht umgestellt', () {
      final sim = freshSim();
      expect(
        sim.moveObject(
          'o_r1_sofa',
          GridPos(HouseGeometry.stairWalkLeft, HouseGeometry.floorRowOf(1)),
        ),
        isFalse,
      );
    });

    test('ein näher gerücktes Objekt wird besser bewertet', () {
      final sim = freshSim(hour: 20);
      final ayla = sim.world.residentById['ayla']!;
      final sofa = sim.world.objectById['o_r1_sofa']!;

      double sofaTravelPenalty() => sim.decisionSystem.scorer
          .rank(ayla, sim.world, limit: 1 << 20)
          .firstWhere((c) => c.object.id == sofa.id)
          .breakdown
          .travel;

      // Ayla steht links; das Sofa weiter rechts ist der weitere Weg.
      final nearSpot = sofa.cell;
      final farSpot = freeSpotFor(sim, sofa.id, 'r1_living');
      expect(farSpot.x, greaterThan(nearSpot.x));

      final near = sofaTravelPenalty();
      expect(sim.moveObject(sofa.id, farSpot), isTrue);
      final far = sofaTravelPenalty();

      expect(near, greaterThan(far), reason: 'näher = geringerer Abzug');
    });
  });

  group('Nachbarschaftsnotiz', () {
    test('weckt bei beiden den Wunsch, sich zu treffen', () {
      final sim = freshSim();
      expect(
        sim.postNote(residentA: 'mira', residentB: 'hilde', text: 'Kaffee?'),
        isNotNull,
      );
      sim.advanceSim(60, step: 60);
      expect(sim.world.residentById['mira']!.pendingMeetWith, 'hilde');
      expect(sim.world.residentById['hilde']!.pendingMeetWith, 'mira');
    });

    test('bringt die beiden im Flur zusammen', () {
      final sim = freshSim(hour: 10);
      sim.postNote(residentA: 'mira', residentB: 'hilde', text: 'Auf ein Wort?');

      var fulfilled = false;
      for (var i = 0; i < 14 * 60 && !fulfilled; i++) {
        sim.advanceSim(60, step: 60);
        fulfilled = sim.world.notes.any((n) => n.fulfilled);
      }
      expect(fulfilled, isTrue, reason: 'Die Notiz wurde nie eingelöst');
      expect(sim.world.residentById['mira']!.relationTo('hilde'),
          greaterThan(0.2));
    });

    test('zwingt niemanden – sie bleibt eine Einladung', () {
      final sim = freshSim(hour: 3);
      final mira = sim.world.residentById['mira']!;
      mira.needs[NeedType.energy] = 0.05;
      sim.postNote(residentA: 'mira', residentB: 'hilde', text: 'Jetzt?');
      runMinutes(sim, 30);
      expect(mira.activity?.affordance.isSleep, isTrue);
    });

    test('eine Notiz pro Paar', () {
      final sim = freshSim();
      sim.postNote(residentA: 'mira', residentB: 'hilde', text: 'A');
      sim.postNote(residentA: 'hilde', residentB: 'mira', text: 'B');
      expect(sim.world.notes.length, 1);
      expect(sim.world.notes.single.text, 'B');
    });

    test('unsinnige Notizen werden abgelehnt', () {
      final sim = freshSim();
      expect(sim.postNote(residentA: 'mira', residentB: 'mira', text: 'X'),
          isNull);
      expect(sim.postNote(residentA: 'mira', residentB: 'wer?', text: 'X'),
          isNull);
    });
  });

  group('Gedankenblase', () {
    test('liefert für jeden Bewohner eine Zeile', () {
      final sim = freshSim();
      runMinutes(sim, 120);
      for (final r in sim.world.residents) {
        final thought = sim.thoughtFor(r.id);
        expect(thought, isNotEmpty);
        expect(r.lastThought, thought);
      }
    });

    test('ist im selben Moment stabil und verändert sich über den Tag', () {
      final sim = freshSim();
      final first = sim.thoughtFor('mira');
      expect(sim.thoughtFor('mira'), first, reason: 'kein Würfeln pro Tap');

      final seen = <String>{first};
      for (var h = 0; h < 12; h++) {
        runMinutes(sim, 60);
        seen.add(sim.thoughtFor('mira'));
      }
      expect(seen.length, greaterThan(1));
    });

    test('unbekannte Bewohner liefern eine leere Zeile', () {
      expect(freshSim().thoughtFor('niemand'), '');
    });
  });

  group('Katze, Wetter, Licht', () {
    test('Nebel bewegt sich durchs Haus und bleibt auf begehbaren Tiles', () {
      final sim = freshSim();
      final visited = <GridPos>{sim.world.cat.cell};
      for (var i = 0; i < 6 * 3600; i++) {
        sim.advanceSim(1, step: 1);
        final c = sim.world.cat.cell;
        visited.add(c);
        expect(sim.world.walkGrid.isWalkableAt(c), isTrue, reason: '$c');
      }
      expect(visited.length, greaterThan(5));
    });

    test('das Wetter wechselt im Lauf der Tage', () {
      final sim = freshSim();
      final seen = <Weather>{sim.world.weather};
      for (var i = 0; i < 5 * 24 * 60; i++) {
        sim.advanceSim(60, step: 60);
        seen.add(sim.world.weather);
      }
      expect(seen.length, greaterThan(1));
    });

    test('mittags macht niemand Licht', () {
      final noon = freshSim(hour: 12);
      runMinutes(noon, 30);
      expect(noon.world.litRooms, isEmpty);
    });
  });

  group('Eingaben', () {
    test('findet ein Objekt unter dem Finger, auf jedem Tile seiner Breite', () {
      final sim = freshSim();
      final sofa = sim.world.objectById['o_r1_sofa']!;
      expect(sim.objectAt(sofa.cell)?.id, sofa.id);
      expect(sim.objectAt(GridPos(sofa.cell.x + 2, sofa.cell.y))?.id, sofa.id);
    });

    test('findet einen Bewohner in der Nähe, nichts im Leeren', () {
      final sim = freshSim();
      final ayla = sim.world.residentById['ayla']!;
      expect(sim.residentAt(ayla.cell)?.id, ayla.id);
      expect(sim.objectAt(const GridPos(0, 0)), isNull);
      expect(sim.residentAt(const GridPos(0, 0)), isNull);
    });

    test('16× rechnet dieselbe Zeit wie 1×, nur schneller', () {
      final slow = freshSim();
      final fast = freshSim()..setTimeScale(TimeScale.x16);
      for (var i = 0; i < 16 * 60; i++) {
        slow.tickReal(1);
      }
      for (var i = 0; i < 60; i++) {
        fast.tickReal(1);
      }
      expect(fast.world.clock.simSeconds,
          closeTo(slow.world.clock.simSeconds, 2.0));
    });
  });
}
