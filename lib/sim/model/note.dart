/// Eine Nachbarschaftsnotiz an der Pinnwand im Treppenhaus.
///
/// Die einzige Interaktion, die zwei Bewohner *zusammenbringt* – und auch die
/// tut das nur als Einladung: Sie erhöht den Nutzen gemeinsamer Aktionen,
/// erzwingt aber nichts. Wer gerade erschöpft ist, geht trotzdem ins Bett.
class NeighborhoodNote {
  NeighborhoodNote({
    required this.id,
    required this.text,
    required this.residentA,
    required this.residentB,
    required this.postedAtSim,
    required this.expiresAtSim,
  });

  final String id;
  final String text;
  final String residentA;
  final String residentB;
  final double postedAtSim;
  final double expiresAtSim;

  /// Wurde die Einladung schon eingelöst (beide waren gemeinsam am Brett)?
  bool fulfilled = false;

  bool involves(String residentId) =>
      residentId == residentA || residentId == residentB;

  String? partnerFor(String residentId) {
    if (residentId == residentA) return residentB;
    if (residentId == residentB) return residentA;
    return null;
  }

  bool isActive(double simSeconds) => !fulfilled && simSeconds < expiresAtSim;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'residentA': residentA,
        'residentB': residentB,
        'postedAtSim': postedAtSim,
        'expiresAtSim': expiresAtSim,
        'fulfilled': fulfilled,
      };

  static NeighborhoodNote fromJson(Map<String, dynamic> j) =>
      NeighborhoodNote(
        id: j['id'] as String,
        text: j['text'] as String,
        residentA: j['residentA'] as String,
        residentB: j['residentB'] as String,
        postedAtSim: (j['postedAtSim'] as num).toDouble(),
        expiresAtSim: (j['expiresAtSim'] as num).toDouble(),
      )..fulfilled = j['fulfilled'] as bool? ?? false;
}
