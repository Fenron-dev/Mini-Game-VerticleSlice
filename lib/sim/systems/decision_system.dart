import '../ai/action_scorer.dart';
import '../ai/activity.dart';
import '../house_world.dart';
import '../model/need.dart';
import '../model/resident.dart';

/// Wählt für jeden Bewohner die nächste Handlung.
///
/// Entscheidungen sind **selten** und **billig**: Wer beschäftigt ist, denkt
/// nicht ständig neu nach. Nur wenn eine Aktivität endet oder ein Bedürfnis
/// kritisch wird, läuft das Scoring – deshalb bleiben auch 16× flüssig.
class DecisionSystem {
  const DecisionSystem({this.scorer = const ActionScorer()});

  final ActionScorer scorer;

  /// Wartezeit, bis ein untätiger Bewohner erneut überlegt (Sim-Sekunden).
  static const double idleRecheckSeconds = 20.0;

  /// Abstand der Unterbrechungsprüfung während einer laufenden Aktivität.
  static const double interruptCheckSeconds = 240.0;

  /// Unterhalb dieses Werts gilt ein Bedürfnis als Notlage.
  static const double criticalNeed = 0.15;

  /// Wie viel besser eine Alternative sein muss, um eine laufende Aktivität
  /// abzubrechen. Hysterese gegen Zappeln.
  static const double interruptMargin = 0.30;

  /// Fenster, in dem "bis zum Aufwachen schlafen" als Nachtschlaf zählt.
  static const double minNightHours = 4.0;
  static const double maxNightHours = 10.0;

  /// Grenzen für Erholungsschlaf außerhalb der eigenen Nacht.
  static const double minRecoveryHours = 1.5;
  static const double maxRecoveryHours = 4.0;

  void update(HouseWorld world, double _) {
    final now = world.clock.simSeconds;

    for (final resident in world.residents) {
      final activity = resident.activity;

      if (activity == null || activity.isDone) {
        if (activity != null) _release(world, resident);
        if (now >= resident.nextDecisionAt) {
          _decide(world, resident);
        }
        continue;
      }

      if (activity.isPerforming && now >= resident.nextDecisionAt) {
        resident.nextDecisionAt = now + interruptCheckSeconds;
        _maybeInterrupt(world, resident);
      }
    }
  }

  /// Reservierung und Belegung freigeben.
  void _release(HouseWorld world, Resident resident) {
    final activity = resident.activity;
    if (activity != null && activity.holdsOccupancy) {
      final object = world.objectById[activity.objectId];
      if (object?.occupantId == resident.id) {
        object!.occupantId = null;
      }
    }
    resident.activity = null;
  }

  void _decide(HouseWorld world, Resident resident) {
    final now = world.clock.simSeconds;
    final candidates = scorer.rank(resident, world, limit: 6);

    for (final candidate in candidates) {
      final object = candidate.object;
      final path = world.pathfinder.findPath(resident.cell, object.useCell);
      if (path == null) continue; // unerreichbar – nächster Kandidat

      final activity = Activity(
        objectId: object.id,
        affordance: candidate.affordance,
        path: path,
        startedAtSim: now,
        plannedMinutes: _plannedMinutes(world, resident, candidate),
      );

      // Exklusive Angebote werden schon beim Losgehen reserviert – sonst
      // laufen zwei Leute zur selben Dusche und einer steht dumm da.
      if (candidate.affordance.exclusive) {
        object.occupantId = resident.id;
        activity.holdsOccupancy = true;
      }

      if (resident.pendingMeetWith != null &&
          candidate.affordance.tags.contains('note')) {
        activity.partnerId = resident.pendingMeetWith;
      }

      resident.activity = activity;
      resident.nextDecisionAt = now + interruptCheckSeconds;
      return;
    }

    // Nichts Sinnvolles gefunden – gleich nochmal schauen.
    resident.nextDecisionAt = now + idleRecheckSeconds;
  }

  double _plannedMinutes(
    HouseWorld world,
    Resident resident,
    ScoredAction candidate,
  ) {
    final a = candidate.affordance;
    if (a.isSleep) {
      var untilWake = resident.wakeHour - world.clock.hourOfDay;
      if (untilWake <= 0) untilWake += 24.0;

      // Liegt der eigene Aufwachzeitpunkt in einer plausiblen Nachtdistanz,
      // wird bis dahin geschlafen.
      if (untilWake >= minNightHours && untilWake <= maxNightHours) {
        return untilWake * 60.0;
      }

      // Sonst ist es kein Nachtschlaf, sondern Erholung zur falschen Zeit –
      // etwa nach einer durchwachten Nacht. Die darf kurz sein. Ohne diese
      // Unterscheidung wird aus "ich habe meinen Weckzeitpunkt um eine Stunde
      // verpasst" ein Rest-Tagesabstand von 23 Stunden und damit ein
      // Dauerschlaf durch den ganzen Tag.
      final energyRate = a.rates[NeedType.energy] ?? 0.16;
      final deficitHours =
          (1.0 - resident.needs[NeedType.energy]) / energyRate;
      return deficitHours.clamp(minRecoveryHours, maxRecoveryHours) * 60.0;
    }
    final variation = 0.85 + world.rng.nextDouble() * 0.3;
    return a.baseDurationMinutes * variation;
  }

  void _maybeInterrupt(HouseWorld world, Resident resident) {
    final activity = resident.activity!;

    // Was ist gerade wirklich dringend?
    NeedType? critical;
    var lowest = criticalNeed;
    for (final need in NeedType.values) {
      if (need == NeedType.contentment) continue;
      final v = resident.needs[need];
      if (v < lowest) {
        lowest = v;
        critical = need;
      }
    }
    if (critical == null) return;

    // Schlaf ist geschützt: Nur echter Hunger holt jemanden aus dem Bett.
    if (activity.affordance.isSleep) {
      if (critical != NeedType.hunger ||
          resident.needs[NeedType.hunger] > 0.08) {
        return;
      }
    }

    // Die laufende Aktion kümmert sich bereits darum? Dann dabeibleiben.
    if ((activity.affordance.rates[critical] ?? 0.0) > 0) return;

    final candidates = scorer.rank(resident, world, limit: 6);
    final currentScore = _scoreOfCurrent(candidates, activity);
    for (final candidate in candidates) {
      final helps = (candidate.affordance.rates[critical] ?? 0.0) > 0;
      if (!helps) continue;
      if (candidate.score < currentScore + interruptMargin) continue;

      final path =
          world.pathfinder.findPath(resident.cell, candidate.object.useCell);
      if (path == null) continue;

      _release(world, resident);
      final next = Activity(
        objectId: candidate.object.id,
        affordance: candidate.affordance,
        path: path,
        startedAtSim: world.clock.simSeconds,
        plannedMinutes: _plannedMinutes(world, resident, candidate),
      );
      if (candidate.affordance.exclusive) {
        candidate.object.occupantId = resident.id;
        next.holdsOccupancy = true;
      }
      resident.activity = next;
      return;
    }
  }

  /// Score der laufenden Aktion, falls sie noch in der Rangliste steht.
  /// Sonst konservativ 0 – die Alternative muss dann deutlich überzeugen.
  double _scoreOfCurrent(List<ScoredAction> ranked, Activity activity) {
    for (final c in ranked) {
      if (c.object.id == activity.objectId &&
          c.affordance.id == activity.affordance.id) {
        return c.score;
      }
    }
    return 0.0;
  }
}
