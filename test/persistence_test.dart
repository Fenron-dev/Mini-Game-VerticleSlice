import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_slice/core/sim_clock.dart';
import 'package:vertical_slice/persistence/game_snapshot.dart';
import 'package:vertical_slice/persistence/save_service.dart';
import 'package:vertical_slice/persistence/save_store.dart';
import 'package:vertical_slice/sim/building_factory.dart';
import 'package:vertical_slice/sim/model/grid.dart';
import 'package:vertical_slice/sim/model/need.dart';
import 'package:vertical_slice/sim/simulation.dart';

HouseSimulation freshSim({int seed = 3, int hour = 9}) => HouseSimulation(
      world: BuildingFactory.createDefault(
        rng: math.Random(seed),
        now: DateTime(2024, 6, 7, hour),
      ),
    );

void runMinutes(HouseSimulation sim, int minutes) {
  for (var i = 0; i < minutes; i++) {
    sim.advanceSim(60, step: 60);
  }
}

void main() {
  group('Momentaufnahme', () {
    test('Uhr, Bedürfnisse und Positionen überstehen eine Runde', () {
      final sim = freshSim();
      runMinutes(sim, 300);

      final restored = GameSnapshot.restore(GameSnapshot.capture(sim.world))!;
      expect(restored.world.clock.simSeconds,
          closeTo(sim.world.clock.simSeconds, 1e-6));

      for (final original in sim.world.residents) {
        final copy = restored.world.residentById[original.id]!;
        for (final n in NeedType.values) {
          expect(copy.needs[n], closeTo(original.needs[n], 1e-9),
              reason: '${original.name}/${n.name}');
        }
        expect(copy.x, closeTo(original.x, 1e-9));
        expect(copy.y, closeTo(original.y, 1e-9));
        expect(copy.relationships, original.relationships);
      }
    });

    test('laufende Aktivitäten laufen weiter', () {
      final sim = freshSim();
      runMinutes(sim, 200);
      final busy = sim.world.residents.where((r) => r.activity != null);
      expect(busy, isNotEmpty);

      final restored = GameSnapshot.restore(GameSnapshot.capture(sim.world))!;
      for (final original in busy) {
        final copy = restored.world.residentById[original.id]!;
        expect(copy.activity?.affordance.id, original.activity!.affordance.id);
        expect(copy.activity?.objectId, original.activity!.objectId);
        expect(copy.activity?.remainingMinutes,
            closeTo(original.activity!.remainingMinutes, 1e-9));
      }
    });

    test('Möbelpositionen und Objektzustände bleiben erhalten', () {
      final sim = freshSim();
      final sofa = sim.world.objectById['o_r1_sofa']!;
      final room = sim.world.roomById['r1_living']!;
      // Das Sofa steht am linken Rand; drei Tiles weiter ist frei.
      expect(sim.moveObject(sofa.id, GridPos(sofa.cell.x + 3, room.floorRow)),
          isTrue);

      sim.world.objectById['o_r1_plant']!.moisture = 0.13;
      sim.world.objectById['o_c_washer_a']!
        ..broken = true
        ..condition = 0.42;

      final restored = GameSnapshot.restore(GameSnapshot.capture(sim.world))!;
      expect(restored.world.objectById['o_r1_sofa']!.cell, sofa.cell);
      expect(restored.world.objectById['o_r1_plant']!.moisture,
          closeTo(0.13, 1e-9));
      expect(restored.world.objectById['o_c_washer_a']!.broken, isTrue);
      expect(restored.world.objectById['o_c_washer_a']!.condition,
          closeTo(0.42, 1e-9));
    });

    test('Katze, Wetter und Notizen kommen mit', () {
      final sim = freshSim();
      sim.postNote(
        residentA: 'mira',
        residentB: 'hilde',
        text: 'Der Hausflur riecht nach Frühling.',
      );
      runMinutes(sim, 120);

      final restored = GameSnapshot.restore(GameSnapshot.capture(sim.world))!;
      expect(restored.world.weather, sim.world.weather);
      expect(restored.world.cat.x, closeTo(sim.world.cat.x, 1e-9));
      expect(restored.world.cat.y, closeTo(sim.world.cat.y, 1e-9));
      expect(restored.world.notes.length, sim.world.notes.length);
      expect(restored.world.notes.single.text,
          'Der Hausflur riecht nach Frühling.');
    });

    test('verwaiste Belegungen werden beim Laden gelöst', () {
      final sim = freshSim();
      sim.world.objectById['o_r1_bed_a']!.occupantId = 'ayla';
      final restored = GameSnapshot.restore(GameSnapshot.capture(sim.world))!;
      expect(restored.world.objectById['o_r1_bed_a']!.occupantId, isNull);
    });

    test('unbekannte Objekte im Spielstand werden übergangen', () {
      final json = GameSnapshot.capture(freshSim().world);
      (json['world'] as Map)['objects'] = [
        {
          'id': 'o_gibt_es_nicht_mehr',
          'kind': 'sofa',
          'roomId': 'r1_living',
          'cell': {'x': 5, 'y': 39},
          'condition': 1.0,
          'moisture': 1.0,
          'broken': false,
          'occupantId': null,
          'cooldownUntil': 0.0,
        }
      ];
      expect(GameSnapshot.restore(json), isNotNull);
    });

    test('zu neues Schema und Müll werden abgelehnt', () {
      final json = GameSnapshot.capture(freshSim().world);
      json['schema'] = GameSnapshot.schemaVersion + 1;
      expect(GameSnapshot.restore(json), isNull);
      expect(GameSnapshot.restore({'schema': 'nein'}), isNull);
      expect(GameSnapshot.restore({'schema': 1}), isNull);
    });
  });

  group('Nachberechnung', () {
    test('holt die Zeit auf, die die App aus war', () {
      final sim = freshSim();
      final before = sim.world.clock.simSeconds;
      final report = sim.catchUp(const Duration(hours: 5));
      expect(report.capped, isFalse);
      expect(sim.world.clock.simSeconds - before, closeTo(5 * 3600, 60));
      expect(report.applied.inMinutes, closeTo(300, 1));
    });

    test('lässt in der Zwischenzeit tatsächlich etwas passieren', () {
      final sim = freshSim();
      final before = {
        for (final r in sim.world.residents) r.id: r.needs[NeedType.hunger],
      };
      sim.catchUp(const Duration(hours: 6));
      expect(
        sim.world.residents.where(
            (r) => (r.needs[NeedType.hunger] - before[r.id]!).abs() > 1e-6),
        isNotEmpty,
      );
    });

    test('ist auf ein sinnvolles Maß gedeckelt', () {
      final sim = freshSim();
      final before = sim.world.clock.simSeconds;
      final report = sim.catchUp(const Duration(days: 30));
      expect(report.capped, isTrue);
      expect(sim.world.clock.simSeconds - before,
          closeTo(HouseSimulation.maxCatchUp.inSeconds.toDouble(), 120));
    });

    test('null Sekunden verändern nichts', () {
      final sim = freshSim();
      final before = sim.world.clock.simSeconds;
      expect(sim.catchUp(Duration.zero).steps, 0);
      expect(sim.world.clock.simSeconds, before);
    });
  });

  group('SaveService', () {
    test('erster Start erzeugt ein frisches Haus', () async {
      final result = await SaveService(store: MemorySaveStore())
          .loadOrCreate(now: DateTime(2024, 6, 7, 9));
      expect(result.wasFresh, isTrue);
      expect(result.catchUp, isNull);
      expect(result.simulation.world.residents.length, 6);
    });

    test('rechnet die Pause zwischen Speichern und Laden nach', () async {
      final service = SaveService(store: MemorySaveStore());
      final first = await service.loadOrCreate(now: DateTime(2024, 6, 7, 9));
      final savedAt = DateTime(2024, 6, 7, 9);
      await service.save(first.simulation, now: savedAt);
      final simAtSave = first.simulation.world.clock.simSeconds;

      final second = await service.loadOrCreate(
          now: savedAt.add(const Duration(hours: 7)));
      expect(second.wasFresh, isFalse);
      expect(second.catchUp!.applied.inMinutes, closeTo(420, 2));
      expect(second.simulation.world.clock.simSeconds - simAtSave,
          closeTo(7 * 3600, 120));
    });

    test('offline vergeht immer 1×, auch bei aktivem Zeitraffer', () async {
      final service = SaveService(store: MemorySaveStore());
      final first = await service.loadOrCreate(now: DateTime(2024, 6, 7, 9));
      first.simulation.setTimeScale(TimeScale.x16);
      final savedAt = DateTime(2024, 6, 7, 9);
      await service.save(first.simulation, now: savedAt);

      final second = await service.loadOrCreate(
          now: savedAt.add(const Duration(hours: 4)));
      expect(second.catchUp!.applied.inMinutes, closeTo(240, 2));
      // Der Regler bleibt aber, wo der Spieler ihn gelassen hat.
      expect(second.simulation.world.clock.scale, TimeScale.x16);
    });

    test('eine zurückgestellte Systemuhr rechnet nicht rückwärts', () async {
      final service = SaveService(store: MemorySaveStore());
      final first = await service.loadOrCreate(now: DateTime(2024, 6, 7, 12));
      await service.save(first.simulation, now: DateTime(2024, 6, 7, 12));

      final second = await service.loadOrCreate(now: DateTime(2024, 6, 7, 8));
      expect(second.catchUp, isNull);
      expect(second.simulation.world.clock.simSeconds,
          closeTo(first.simulation.world.clock.simSeconds, 1.0));
    });

    test('beschädigte Spielstände führen nicht zum Absturz', () async {
      final store = MemorySaveStore();
      await store.write('{kaputt,,,');
      expect((await SaveService(store: store).loadOrCreate()).wasFresh, isTrue);

      await store.write(jsonEncode({'schema': 1, 'world': 42}));
      expect((await SaveService(store: store).loadOrCreate()).wasFresh, isTrue);
    });

    test('reset löscht den Stand', () async {
      final store = MemorySaveStore();
      final service = SaveService(store: store);
      await service.save((await service.loadOrCreate()).simulation);
      await service.reset();
      expect(await store.read(), isNull);
    });
  });

  group('SimClock', () {
    test('startet auf der lokalen Uhrzeit', () {
      final clock = SimClock.fromWallClock(DateTime(2024, 6, 7, 14, 30));
      expect(clock.hour, 14);
      expect(clock.minute, 30);
    });

    test('läuft nie rückwärts, auch beim Neusynchronisieren', () {
      final clock = SimClock.fromWallClock(DateTime(2024, 6, 7, 23, 0));
      clock.advanceSim(3 * 3600);
      final before = clock.simSeconds;
      clock.resyncToWallClock(DateTime(2024, 6, 7, 23, 30));
      expect(clock.simSeconds, greaterThanOrEqualTo(before));
    });

    test('Tageslicht ist mittags hell und nachts dunkel', () {
      expect(SimClock.fromWallClock(DateTime(2024, 6, 7, 13)).daylight, 1.0);
      expect(SimClock.fromWallClock(DateTime(2024, 6, 7, 3)).daylight, 0.0);
    });

    test('Abendwärme hat ihr Maximum zur goldenen Stunde', () {
      final golden =
          SimClock.fromWallClock(DateTime(2024, 6, 7, 19, 30)).eveningWarmth;
      final noon =
          SimClock.fromWallClock(DateTime(2024, 6, 7, 12)).eveningWarmth;
      expect(golden, greaterThan(noon));
      expect(golden, closeTo(1.0, 0.05));
    });

    test('Zeitraffer skaliert echte Sekunden', () {
      final clock = SimClock(simEpochSeconds: 0, scale: TimeScale.x16);
      clock.advanceReal(10);
      expect(clock.simSeconds, 160);
    });
  });
}
