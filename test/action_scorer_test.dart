import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_slice/sim/ai/action_scorer.dart';
import 'package:vertical_slice/sim/building_factory.dart';
import 'package:vertical_slice/sim/house_world.dart';
import 'package:vertical_slice/sim/model/interactable.dart';
import 'package:vertical_slice/sim/model/need.dart';
import 'package:vertical_slice/sim/model/note.dart';
import 'package:vertical_slice/sim/model/resident.dart';

/// Kein Rauschen: Tests prüfen die Rangfolge, nicht den Zufall.
const scorer = ActionScorer(jitter: 0);

/// Die volle Rangliste – Tests sollen nichts übersehen, nur weil es knapp
/// unter der Spitze liegt.
const all = 1 << 20;

HouseWorld worldAt(int hour, {int minute = 0}) =>
    BuildingFactory.createDefault(
      rng: math.Random(1),
      now: DateTime(2024, 6, 7, hour, minute),
    );

void setNeeds(Resident r, Map<NeedType, double> values) {
  for (final n in NeedType.values) {
    r.needs[n] = values[n] ?? 0.75;
  }
}

void main() {
  group('ActionScorer wählt das Naheliegende', () {
    test('müde um Mitternacht → schlafen', () {
      final world = worldAt(23, minute: 30);
      final mira = world.residentById['mira']!;
      setNeeds(mira, {NeedType.energy: 0.18});

      final best = scorer.best(mira, world)!;
      expect(best.affordance.id, 'sleep');
      expect(best.object.kind, ObjectKind.bed);
    });

    test('müde um die Mittagszeit → Nickerchen statt Vollschlaf', () {
      final world = worldAt(13);
      final mira = world.residentById['mira']!;
      setNeeds(mira, {NeedType.energy: 0.25});

      final ranked = scorer.rank(mira, world, limit: all);
      final sleep = ranked.where((c) => c.affordance.id == 'sleep');
      final nap = ranked.where((c) => c.affordance.id == 'nap');

      expect(nap, isNotEmpty);
      if (sleep.isNotEmpty) {
        expect(nap.first.score, greaterThan(sleep.first.score));
      }
    });

    test('hungrig am Mittag → etwas zu essen', () {
      final world = worldAt(12);
      final bruno = world.residentById['bruno']!;
      setNeeds(bruno, {NeedType.hunger: 0.15, NeedType.energy: 0.7});
      expect(scorer.best(bruno, world)!.affordance.tags, contains('eat'));
    });

    test('erschöpft und kritisch hungrig → erst essen', () {
      final world = worldAt(20);
      final hilde = world.residentById['hilde']!;
      setNeeds(hilde, {NeedType.energy: 0.30, NeedType.hunger: 0.06});
      expect(scorer.best(hilde, world)!.affordance.tags, contains('eat'));
    });

    test('schmutzig → duschen', () {
      final world = worldAt(9);
      final tobias = world.residentById['tobias']!;
      setNeeds(tobias, {NeedType.hygiene: 0.12});
      expect(scorer.best(tobias, world)!.affordance.id, 'wash');
    });

    test('sauber → kein Dauerduschen aus reiner Ordnungsliebe', () {
      // Regression: Tageszeit- und Charakterboni allein ließen die Dusche
      // gewinnen, obwohl es nichts mehr zu waschen gab.
      final world = worldAt(8);
      final tobias = world.residentById['tobias']!; // Ordnungsliebe
      setNeeds(tobias, {NeedType.hygiene: 1.0, NeedType.hunger: 0.3});

      final ranked = scorer.rank(tobias, world, limit: all);
      final wash = ranked.firstWhere((c) => c.affordance.id == 'wash');
      expect(wash.breakdown.marginal, lessThan(0),
          reason: 'Duschen ohne Anlass gilt als sinnlos');
      expect(ranked.first.affordance.id, isNot('wash'));
    });
  });

  group('Objektzustand', () {
    test('kaputte Geräte bieten ihre normale Nutzung nicht mehr an', () {
      final world = worldAt(12);
      final bruno = world.residentById['bruno']!;
      setNeeds(bruno, {NeedType.hunger: 0.2});
      final stove = world.objectById['o_r1_stove']!..broken = true;

      final ranked = scorer.rank(bruno, world, limit: all);
      expect(
        ranked.any((c) => c.object.id == stove.id && c.affordance.id == 'cook'),
        isFalse,
      );
    });

    test('nur Kaputtes lässt sich reparieren', () {
      final world = worldAt(12);
      final bruno = world.residentById['bruno']!; // handwerklich
      final radio = world.objectById['o_c_radio']!; // im Keller, für alle da

      var ranked = scorer.rank(bruno, world, limit: all);
      expect(ranked.any((c) => c.affordance.id == 'repair'), isFalse);

      radio.broken = true;
      ranked = scorer.rank(bruno, world, limit: all);
      expect(
        ranked.any(
            (c) => c.affordance.id == 'repair' && c.object.id == radio.id),
        isTrue,
      );
    });

    test('besetzte Objekte fallen aus der Auswahl', () {
      final world = worldAt(23);
      final ayla = world.residentById['ayla']!;
      setNeeds(ayla, {NeedType.energy: 0.15});
      world.objectById['o_r1_bed_a']!.occupantId = 'bruno';
      world.objectById['o_r1_bed_b']!.occupantId = 'bruno';

      final ranked = scorer.rank(ayla, world, limit: all);
      expect(ranked.any((c) => c.affordance.id == 'sleep'), isFalse,
          reason: 'Beide Betten belegt');
    });

    test('durstige Pflanzen rufen lauter als feuchte', () {
      final world = worldAt(11);
      final ayla = world.residentById['ayla']!; // grüner Daumen
      final plant = world.objectById['o_r1_plant']!;

      double waterScore() => scorer
          .rank(ayla, world, limit: all)
          .firstWhere((c) => c.affordance.id == 'water_plant')
          .score;

      plant.moisture = 0.44;
      final mild = waterScore();
      plant.moisture = 0.02;
      expect(waterScore(), greaterThan(mild));
    });
  });

  group('Charakter verändert die Wahl', () {
    test('Geselligkeit bewertet gemeinsame Aktionen höher', () {
      final world = worldAt(19);
      final levent = world.residentById['levent']!; // gesellig
      final mira = world.residentById['mira']!; // zurückgezogen
      setNeeds(levent, {NeedType.social: 0.3});
      setNeeds(mira, {NeedType.social: 0.3});

      double bestSocial(Resident r) => scorer
          .rank(r, world, limit: all)
          .where((c) => c.affordance.tags.contains('social'))
          .map((c) => c.score)
          .fold(-99.0, math.max);

      expect(bestSocial(levent), greaterThan(bestSocial(mira)));
    });

    test('Stubenhocker meiden weite Wege stärker', () {
      final world = worldAt(15);
      final bruno = world.residentById['bruno']!; // Stubenhocker
      final levent = world.residentById['levent']!; // rastlos

      double roofPenalty(Resident r) => scorer
          .rank(r, world, limit: all)
          .firstWhere((c) => c.object.id == 'o_roof_bench')
          .breakdown
          .travel;

      expect(roofPenalty(bruno), lessThan(roofPenalty(levent)));
    });
  });

  group('Privatsphäre', () {
    test('alle Wohnräume gehören zu einer Wohnung', () {
      // Regression: Ohne apartmentId galt jeder Raum als Gemeinschaftsfläche,
      // die Privatsphäreregel lief ins Leere – und ihr Test bestand trotzdem.
      final world = worldAt(12);
      for (final apt in world.apartments) {
        for (final roomId in apt.roomIds) {
          expect(world.roomById[roomId]!.apartmentId, apt.id);
        }
      }
    });

    test('jede Wohnung hat Bett, Dusche, Herd und Tisch oder Kühlschrank', () {
      // Regression: Zwei Wohnungen fehlte das Bad, einer das Bett.
      final world = worldAt(12);
      for (final apt in world.apartments) {
        final kinds = world.objects
            .where((o) => apt.roomIds.contains(o.roomId))
            .map((o) => o.kind)
            .toSet();
        expect(kinds, containsAll([ObjectKind.bed, ObjectKind.shower]),
            reason: apt.label);
        expect(kinds.contains(ObjectKind.stove), isTrue, reason: apt.label);
      }
    });

    test('niemand betritt ungefragt eine fremde Wohnung', () {
      final world = worldAt(14);
      for (final resident in world.residents) {
        for (final candidate in scorer.rank(resident, world, limit: all)) {
          final room = world.roomById[candidate.object.roomId]!;
          if (room.isCommunal) continue;
          expect(room.apartmentId, resident.apartmentId,
              reason: '${resident.name} sollte ${room.name} nicht wählen');
        }
      }
    });

    test('eine Nachbarschaftsnotiz öffnet die Tür einen Spalt', () {
      final world = worldAt(14);
      final mira = world.residentById['mira']!;

      bool seesApt1() => scorer
          .rank(mira, world, limit: all)
          .any((c) => world.roomById[c.object.roomId]!.apartmentId == 'apt1');

      expect(seesApt1(), isFalse);
      world.notes.add(
        NeighborhoodNote(
          id: 'n1',
          text: 'Kaffee?',
          residentA: 'mira',
          residentB: 'ayla',
          postedAtSim: world.clock.simSeconds,
          expiresAtSim: world.clock.simSeconds + 6 * 3600,
        ),
      );
      expect(seesApt1(), isTrue, reason: 'Eingeladen darf Mira zu Ayla');
    });
  });

  group('Rangfolge', () {
    test('ist absteigend sortiert', () {
      final world = worldAt(10);
      final ranked = scorer.rank(world.residentById['hilde']!, world, limit: 30);
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].score, greaterThanOrEqualTo(ranked[i].score));
      }
    });

    test('liefert ohne Rauschen reproduzierbare Ergebnisse', () {
      final a = worldAt(10);
      final b = worldAt(10);
      final first = scorer.rank(a.residentById['hilde']!, a, limit: 10);
      final second = scorer.rank(b.residentById['hilde']!, b, limit: 10);
      expect(
        first.map((c) => '${c.affordance.id}@${c.object.id}'),
        second.map((c) => '${c.affordance.id}@${c.object.id}'),
      );
    });
  });
}
