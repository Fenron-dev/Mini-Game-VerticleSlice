import 'dart:math' as math;

import '../../core/sim_clock.dart';
import '../house_world.dart';
import '../model/affordance.dart';
import '../model/interactable.dart';
import '../model/need.dart';
import '../model/resident.dart';
import '../model/room.dart';
import '../nav/travel_estimate.dart';

/// Aufschlüsselung eines Scores – für ein Debug-Overlay und dafür, dass
/// Gedankenblasen sagen können, *warum* jemand etwas tut.
class ScoreBreakdown {
  double needUtility = 0;
  double travel = 0;
  double circadian = 0;
  double social = 0;
  double note = 0;
  double traits = 0;
  double variety = 0;
  double inertia = 0;
  double condition = 0;
  double privacy = 0;
  double noise = 0;

  /// Abzug für Handlungen, die niemandem etwas bringen – siehe
  /// [ActionScorer.minimumReason].
  double marginal = 0;

  NeedType? dominantNeed;

  /// Wie viel Anlass es überhaupt gibt zu handeln: Bedürfnisgewinn plus äußere
  /// Anlässe (Notiz, durstige Pflanze, Defekt, Gesellschaft). **Ohne** die
  /// reinen Vorlieben – die dürfen umsortieren, aber keinen Grund erfinden.
  double get reason =>
      needUtility +
      note +
      (condition > 0 ? condition : 0) +
      (social > 0 ? social : 0);

  double get total =>
      needUtility +
      travel +
      circadian +
      social +
      note +
      traits +
      variety +
      inertia +
      condition +
      privacy +
      marginal +
      noise;

  @override
  String toString() => 'need=${needUtility.toStringAsFixed(2)} '
      'travel=${travel.toStringAsFixed(2)} '
      'circ=${circadian.toStringAsFixed(2)} '
      'social=${social.toStringAsFixed(2)} '
      'note=${note.toStringAsFixed(2)} '
      'traits=${traits.toStringAsFixed(2)} '
      'var=${variety.toStringAsFixed(2)} '
      'inert=${inertia.toStringAsFixed(2)} '
      'cond=${condition.toStringAsFixed(2)} '
      'priv=${privacy.toStringAsFixed(2)} '
      'marg=${marginal.toStringAsFixed(2)}';
}

class ScoredAction {
  ScoredAction({
    required this.object,
    required this.affordance,
    required this.breakdown,
    required this.estimatedTravel,
  });

  final InteractableObject object;
  final Affordance affordance;
  final ScoreBreakdown breakdown;
  final double estimatedTravel;

  double get score => breakdown.total;

  @override
  String toString() =>
      '${affordance.id}@${object.id} = ${score.toStringAsFixed(3)}';
}

/// Utility-basierte Aktionswahl.
///
/// Ein Bewohner trifft keine Pläne – er bewertet in jedem Entscheidungsmoment
/// alles, was das Haus gerade anbietet, und nimmt das Beste. Verhalten
/// entsteht dadurch aus Bedürfnissen, Charakter, Tageszeit und **Geometrie**:
/// Ein Sofa, das näher steht, wird tatsächlich häufiger benutzt.
class ActionScorer {
  const ActionScorer({
    this.jitter = 0.05,
    this.travelWeight = 0.055,
    this.timeCostPerHour = 0.18,
    this.traitWeight = 0.18,
    this.varietyWeight = 0.20,
    this.inertiaBonus = 0.13,
    this.socialWeight = 0.22,
    this.circadianWeight = 0.45,
    this.privacyPenalty = 1.2,
    this.minimumReason = 0.035,
    this.marginalPenalty = 0.5,
    this.relevanceReference = 0.25,
    this.offPeakFactor = 0.35,
    this.brokenCallWeight = 0.28,
  });

  /// Kleines Rauschen, damit gleich gute Optionen nicht immer gleich ausgehen.
  /// In Tests auf 0 setzen.
  final double jitter;

  final double travelWeight;
  final double timeCostPerHour;
  final double traitWeight;
  final double varietyWeight;
  final double inertiaBonus;
  final double socialWeight;
  final double circadianWeight;
  final double privacyPenalty;

  /// Unterhalb dieses Anlasses (siehe [ScoreBreakdown.reason]) gilt eine
  /// Handlung als sinnlos und bekommt [marginalPenalty] aufgebrummt.
  ///
  /// Ohne diese Schwelle gewinnt eine Aktion allein durch Tageszeit- und
  /// Charakterboni – jemand mit Ordnungsliebe duscht dann den halben Tag,
  /// obwohl er längst sauber ist. Sinnlose Handlungen werden **nicht**
  /// verworfen: Wenn wirklich nichts ansteht, soll jemand trotzdem lieber
  /// herumsitzen als einzufrieren.
  final double minimumReason;
  final double marginalPenalty;

  /// Bezugsgröße, ab der Vorlieben voll durchschlagen.
  final double relevanceReference;

  /// Dämpfung der Tageszeit-*Abneigung* gegenüber der Tageszeit-Vorliebe.
  final double offPeakFactor;

  /// Wie laut ein defektes Objekt nach Reparatur ruft.
  final double brokenCallWeight;

  /// Alle gerade möglichen Aktionen, absteigend nach Nutzen.
  List<ScoredAction> rank(
    Resident resident,
    HouseWorld world, {
    int limit = 8,
  }) {
    final out = <ScoredAction>[];
    final now = world.clock.simSeconds;
    final from = resident.cell;

    for (final object in world.objects) {
      if (object.affordances.isEmpty) continue;

      final room = world.roomById[object.roomId];
      if (room == null) continue;

      final privacy = _privacyScore(resident, world, room);
      // Fremde Wohnung ohne Einladung: gar nicht erst bewerten.
      if (privacy <= -privacyPenalty) continue;

      final travelEstimate = estimateTravelCost(from, object.useCell);

      for (final affordance in object.affordances) {
        if (!object.supports(affordance, now, forResident: resident.id)) {
          continue;
        }
        if (!_meetsMinimums(resident, affordance)) continue;

        out.add(
          ScoredAction(
            object: object,
            affordance: affordance,
            breakdown: _score(
              resident: resident,
              world: world,
              object: object,
              affordance: affordance,
              travelEstimate: travelEstimate,
              privacy: privacy,
            ),
            estimatedTravel: travelEstimate,
          ),
        );
      }
    }

    out.sort((a, b) => b.score.compareTo(a.score));
    return out.length <= limit ? out : out.sublist(0, limit);
  }

  ScoredAction? best(Resident resident, HouseWorld world) {
    final ranked = rank(resident, world, limit: 1);
    return ranked.isEmpty ? null : ranked.first;
  }

  bool _meetsMinimums(Resident r, Affordance a) {
    for (final e in a.minNeedToStart.entries) {
      if (r.needs[e.key] < e.value) return false;
    }
    return true;
  }

  /// Privatsphäre: Die eigene Wohnung ist offen, fremde Wohnungen sind es
  /// nicht – außer eine Notiz an der Pinnwand lädt ausdrücklich ein.
  double _privacyScore(Resident r, HouseWorld world, Room room) {
    if (room.isCommunal) return 0.0;
    if (room.apartmentId == r.apartmentId) return 0.08; // zu Hause ist zu Hause
    final apt = world.apartmentOf(room.apartmentId!);
    if (apt != null) {
      for (final note in world.activeNotesFor(r.id)) {
        final partner = note.partnerFor(r.id);
        if (partner != null && apt.residentIds.contains(partner)) {
          return -0.15; // eingeladen, aber immer noch Besuch
        }
      }
    }
    return -privacyPenalty;
  }

  ScoreBreakdown _score({
    required Resident resident,
    required HouseWorld world,
    required InteractableObject object,
    required Affordance affordance,
    required double travelEstimate,
    required double privacy,
  }) {
    final b = ScoreBreakdown()..privacy = privacy;

    // --- 1. Bedürfnisnutzen ------------------------------------------------
    var utility = 0.0;
    var bestNeedContribution = 0.0;
    for (final need in NeedType.values) {
      final gain = affordance.expectedGain(need, resident.needs[need]);
      if (gain == 0) continue;
      final weight = resident.profile.needWeights[need]!;
      if (gain > 0) {
        final contribution = gain * resident.needs.urgency(need) * weight;
        utility += contribution;
        if (contribution > bestNeedContribution) {
          bestNeedContribution = contribution;
          b.dominantNeed = need;
        }
      } else {
        // Kosten wiegen weniger schwer als Gewinne – sonst traut sich niemand
        // mehr zu kochen. Aber sie wiegen umso mehr, je knapper es ohnehin ist.
        final scarcity = 0.4 + 0.6 * resident.needs.urgency(need);
        utility += gain * weight * scarcity;
      }
    }

    // Opportunitätskosten der Zeit: Eine Stunde, die ich hier verbringe, fehlt
    // woanders. Ohne das gewinnt immer die längste Aktion.
    final hours = affordance.baseDurationMinutes / 60.0;
    b.needUtility = utility / (1.0 + hours * timeCostPerHour);

    // --- 2. Weg -------------------------------------------------------------
    //
    // Wurzelförmig, nicht linear. Linear war der Weg in den vierten Stock
    // teurer als jede Handlung dort wert sein kann – das Treppenhaus, das
    // Dach und der Keller blieben schlicht leer. Die Wurzel hält kurze Wege
    // spürbar unterschiedlich und macht weite Wege zu einer Hürde statt zu
    // einer Mauer.
    b.travel = -math.sqrt(travelEstimate) *
        travelWeight *
        resident.profile.travelCost;

    // --- 3. Gesellschaft ----------------------------------------------------
    //
    // Maßgeblich ist, ob die Handlung Sozialkontakt tatsächlich *stillt* –
    // nicht, ob sie zufällig an einem geteilten Möbel stattfindet. Sonst wird
    // aus einem Anziehungspunkt eine Falle: Alle sitzen auf dem Dach, weil dort
    // alle sitzen, und niemand isst mehr.
    final isSocial = (affordance.rates[NeedType.social] ?? 0.0) > 0;
    if (isSocial) {
      final others = world
          .residentsNear(object.useCell, radius: 3.5)
          .where((o) => o.id != resident.id && !o.isAsleep);
      var bond = 0.0;
      for (final o in others) {
        bond += 0.5 + resident.relationTo(o.id);
      }
      // Gesellschaft zieht so stark, wie man sie gerade braucht.
      final appetite =
          (0.25 + 0.75 * resident.needs.urgency(NeedType.social))
              .clamp(0.25, 1.5);
      // Wer allein am Tisch sitzt, hat davon wenig – aber genug, um sich
      // hinzusetzen und zu warten.
      b.social = socialWeight * math.min(bond, 2.0) * appetite +
          (others.isEmpty ? -0.04 : 0.0);
    }

    // --- 4. Nachbarschaftsnotiz --------------------------------------------
    if (resident.pendingMeetWith != null) {
      if (affordance.tags.contains('note')) {
        b.note += resident.meetUrgency;
      }
      final partnerHere = world
          .residentsNear(object.useCell, radius: 3.5)
          .any((o) => o.id == resident.pendingMeetWith);
      if (partnerHere && isSocial) {
        b.note += resident.meetUrgency * 0.6;
      }
    }

    // --- 5. Zustand des Objekts --------------------------------------------
    if (!object.broken) {
      b.condition = -(1.0 - object.condition) * 0.12;
    }
    if (object.isPlant && object.isThirsty && affordance.id == 'water_plant') {
      // Eine durstige Pflanze ruft umso lauter, je trockener sie ist.
      b.condition += (0.45 - object.moisture).clamp(0.0, 0.45) * 0.8;
    }
    if (object.broken && affordance.requiresBroken) {
      // Ein Defekt ruft von sich aus – wie die durstige Pflanze.
      //
      // Ohne diesen Anlass ist Reparieren nur ein Zufriedenheitsgewinn, und
      // wer zufrieden ist, repariert nie: Eine kaputte Dusche blieb eine ganze
      // Woche kaputt, während die Bewohner sich stattdessen die Hände wuschen.
      b.condition += brokenCallWeight;
    }

    // --- 6. Anlass abwägen --------------------------------------------------
    //
    // Ab hier kommen reine *Vorlieben*. Sie werden mit der Relevanz skaliert,
    // damit sie eine Handlung umsortieren, aber nicht aus dem Nichts
    // attraktiv machen können.
    final reason = b.reason;
    final relevance = (reason / relevanceReference).clamp(0.0, 1.0);
    if (reason < minimumReason) {
      b.marginal = -marginalPenalty;
    }

    // --- 7. Tageszeit -------------------------------------------------------
    if (affordance.preferredHour != null) {
      final target =
          (affordance.preferredHour! + resident.profile.circadianShiftHours) %
              24.0;
      final d = circularHourDistance(world.clock.hourOfDay, target);
      final w = affordance.preferredWindow;
      final gauss = math.exp(-(d * d) / (2 * w * w));
      final raw = 2 * gauss - 1; // -1 … +1

      // Asymmetrisch: Die bevorzugte Stunde *zieht* stark, die falsche Stunde
      // *stößt* nur sanft ab. Sonst wird aus "duscht lieber morgens" ein
      // Duschverbot für den Rest des Tages – auch wenn es dringend wäre.
      // Beim Schlaf ist die Abschreckung dagegen der eigentliche Zweck:
      // Sie hält Bewohner nachts im Bett und tagsüber heraus.
      final signed =
          raw >= 0 ? raw : raw * (affordance.isSleep ? 1.0 : offPeakFactor);
      b.circadian = circadianWeight * signed * relevance;
    }

    // --- 8. Charakter -------------------------------------------------------
    b.traits =
        resident.profile.affinityFor(affordance.tags) * traitWeight * relevance;

    // --- 9. Abwechslung und Trägheit ---------------------------------------
    b.variety = -resident.recencyOf(affordance.id) *
        varietyWeight *
        resident.profile.variety *
        relevance;

    final current = resident.activity;
    if (current != null &&
        current.objectId == object.id &&
        current.affordance.id == affordance.id) {
      b.inertia = inertiaBonus * resident.profile.inertia * relevance;
    }

    // --- 10. Rauschen -------------------------------------------------------
    if (jitter > 0) {
      b.noise = (world.rng.nextDouble() - 0.5) * 2 * jitter;
    }

    return b;
  }
}
