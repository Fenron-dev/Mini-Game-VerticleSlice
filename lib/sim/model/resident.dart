import 'dart:math' as math;

import '../ai/activity.dart';
import 'grid.dart';
import 'need.dart';
import 'trait.dart';

/// Ein Bewohner-Agent.
///
/// Der Bewohner hält *Zustand*, keine Entscheidungslogik – die steckt im
/// ActionScorer und den Systemen. Dadurch bleibt er serialisierbar und die
/// Simulation kopfrechenbar (Nachberechnung nach dem Beenden der App).
class Resident {
  Resident({
    required this.id,
    required this.name,
    required this.apartmentId,
    required List<Trait> traits,
    required this.needs,
    required GridPos startCell,
    required this.hue,
  })  : profile = TraitProfile(traits),
        x = startCell.x.toDouble(),
        y = startCell.y.toDouble();

  final String id;
  final String name;
  final String apartmentId;
  final TraitProfile profile;
  final NeedSet needs;

  /// Farbton für die prozeduralen Farbflächen (0–360).
  final double hue;

  /// Position in **Gitterkoordinaten mit Nachkommastellen** – die Darstellung
  /// interpoliert daraus, die Simulation rechnet in Tiles.
  double x;
  double y;

  /// -1 = blickt nach links, 1 = nach rechts.
  int facing = 1;

  Activity? activity;

  /// Sim-Zeit (Sekunden), zu der frühestens neu entschieden wird. Verhindert,
  /// dass jeder Bewohner in jedem Tick das komplette Scoring durchläuft.
  double nextDecisionAt = 0;

  /// Kurzzeitgedächtnis der letzten Aktionen für den Abwechslungsbonus.
  /// Ältester Eintrag zuerst.
  final List<String> recentAffordanceIds = [];

  /// Beziehungswerte zu anderen Bewohnern, -1 … 1.
  final Map<String, double> relationships = {};

  /// Vom Sozialsystem gesetzt: Wunsch, sich mit dieser Person zu treffen.
  String? pendingMeetWith;
  double meetUrgency = 0.0;

  /// Letzte erzeugte Gedankenzeile (für die Blase beim Antippen).
  String? lastThought;
  double lastThoughtAtSim = -1e9;

  GridPos get cell => GridPos(x.round(), y.round());
  int get level => HouseGeometry.levelOfRow(y.round());

  bool get isAsleep =>
      activity?.affordance.isSleep == true && activity!.isPerforming;
  bool get isBusy => activity != null && !activity!.isDone;

  /// Der circadiane Sollzeitpunkt, von Traits verschoben.
  double get bedtimeHour => (23.0 + profile.circadianShiftHours) % 24.0;
  double get wakeHour => (7.0 + profile.circadianShiftHours) % 24.0;

  double relationTo(String otherId) => relationships[otherId] ?? 0.0;

  void nudgeRelation(String otherId, double delta) {
    relationships[otherId] = (relationTo(otherId) + delta).clamp(-1.0, 1.0);
  }

  void rememberAffordance(String affordanceId) {
    recentAffordanceIds.add(affordanceId);
    if (recentAffordanceIds.length > 6) {
      recentAffordanceIds.removeAt(0);
    }
  }

  /// 0 = frisch, 1 = gerade eben schon gemacht. Speist den Abwechslungsabzug.
  double recencyOf(String affordanceId) {
    if (recentAffordanceIds.isEmpty) return 0.0;
    var score = 0.0;
    for (var i = 0; i < recentAffordanceIds.length; i++) {
      if (recentAffordanceIds[i] == affordanceId) {
        final recency = (i + 1) / recentAffordanceIds.length;
        score = math.max(score, recency);
      }
    }
    return score;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'apartmentId': apartmentId,
        'traits': profile.traits.map((t) => t.name).toList(),
        'needs': needs.toJson(),
        'x': x,
        'y': y,
        'facing': facing,
        'hue': hue,
        'nextDecisionAt': nextDecisionAt,
        'recent': recentAffordanceIds,
        'relationships': relationships,
        'pendingMeetWith': pendingMeetWith,
        'meetUrgency': meetUrgency,
        'activity': activity?.toJson(),
      };

  /// Zustand aus einem Spielstand übernehmen. Identität und Traits stammen aus
  /// der Hausdefinition, damit ein Update am Cast nicht am Save scheitert.
  void applyJson(
    Map<String, dynamic> j,
    Activity? Function(Map<String, dynamic>) activityFromJson,
  ) {
    final loaded =
        NeedSet.fromJson(Map<String, dynamic>.from(j['needs'] as Map));
    for (final n in NeedType.values) {
      needs[n] = loaded[n];
    }
    x = (j['x'] as num).toDouble();
    y = (j['y'] as num).toDouble();
    facing = j['facing'] as int? ?? 1;
    nextDecisionAt = (j['nextDecisionAt'] as num?)?.toDouble() ?? 0;
    recentAffordanceIds
      ..clear()
      ..addAll((j['recent'] as List?)?.cast<String>() ?? const []);
    relationships
      ..clear()
      ..addAll(
        (j['relationships'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
            ) ??
            const {},
      );
    pendingMeetWith = j['pendingMeetWith'] as String?;
    meetUrgency = (j['meetUrgency'] as num?)?.toDouble() ?? 0.0;
    final act = j['activity'];
    activity = act == null
        ? null
        : activityFromJson(Map<String, dynamic>.from(act as Map));
  }

  @override
  String toString() => 'Resident($id "$name")';
}
