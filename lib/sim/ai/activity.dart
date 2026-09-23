import '../model/affordance.dart';
import '../model/grid.dart';

enum ActivityPhase {
  /// Unterwegs zum Objekt.
  traveling,

  /// Am Objekt, führt die Aktion aus.
  performing,

  /// Fertig – wird im nächsten Tick aufgeräumt.
  finished,
}

/// Eine laufende Handlung eines Bewohners: das Ergebnis einer Entscheidung des
/// ActionScorer, das vom Ausführungssystem abgearbeitet wird.
class Activity {
  Activity({
    required this.objectId,
    required this.affordance,
    required this.path,
    required this.startedAtSim,
    required this.plannedMinutes,
  }) : remainingMinutes = plannedMinutes;

  final String objectId;
  final Affordance affordance;

  /// Restweg in Gitterzellen; wird beim Laufen vorne abgetragen.
  List<GridPos> path;

  final double startedAtSim;
  final double plannedMinutes;
  double remainingMinutes;

  ActivityPhase phase = ActivityPhase.traveling;

  /// Bewohner, mit dem diese Aktivität geteilt wird (für Sozial-Aktionen).
  String? partnerId;

  /// Wurde das Objekt bereits als besetzt markiert? Verhindert doppeltes
  /// Belegen/Freigeben beim Phasenwechsel.
  bool holdsOccupancy = false;

  bool get isTraveling => phase == ActivityPhase.traveling;
  bool get isPerforming => phase == ActivityPhase.performing;
  bool get isDone => phase == ActivityPhase.finished;

  double get progress =>
      plannedMinutes <= 0 ? 1.0 : 1.0 - (remainingMinutes / plannedMinutes);

  Map<String, dynamic> toJson() => {
        'objectId': objectId,
        'affordanceId': affordance.id,
        'path': path.map((p) => p.toJson()).toList(),
        'startedAtSim': startedAtSim,
        'plannedMinutes': plannedMinutes,
        'remainingMinutes': remainingMinutes,
        'phase': phase.name,
        'partnerId': partnerId,
        'holdsOccupancy': holdsOccupancy,
      };

  static Activity? fromJson(
    Map<String, dynamic> j,
    Affordance? Function(String objectId, String affordanceId) resolve,
  ) {
    final objectId = j['objectId'] as String;
    final affordance = resolve(objectId, j['affordanceId'] as String);
    // Objekt oder Angebot existiert nicht mehr (z. B. nach Balancing-Update):
    // Aktivität still verwerfen, der Bewohner entscheidet neu.
    if (affordance == null) return null;
    return Activity(
      objectId: objectId,
      affordance: affordance,
      path: (j['path'] as List)
          .map((e) => GridPos.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      startedAtSim: (j['startedAtSim'] as num).toDouble(),
      plannedMinutes: (j['plannedMinutes'] as num).toDouble(),
    )
      ..remainingMinutes = (j['remainingMinutes'] as num).toDouble()
      ..phase = ActivityPhase.values.byName(j['phase'] as String)
      ..partnerId = j['partnerId'] as String?
      ..holdsOccupancy = j['holdsOccupancy'] as bool? ?? false;
  }
}
