import 'need.dart';

/// Körperhaltung während einer Aktion – rein für die Darstellung.
enum Posture { stand, sit, lie, crouch }

/// Ein Angebot, das ein Objekt macht: "Bett: +Energie".
///
/// Affordances sind unveränderliche Daten. Sie kennen weder Bewohner noch Welt –
/// der ActionScorer bewertet sie, das Ausführungssystem führt sie aus.
class Affordance {
  const Affordance({
    required this.id,
    required this.label,
    required this.verb,
    required this.rates,
    required this.baseDurationMinutes,
    this.tags = const {},
    this.posture = Posture.stand,
    this.exclusive = true,
    this.requiresWorking = true,
    this.requiresBroken = false,
    this.requiresThirstyPlant = false,
    this.isSleep = false,
    this.preferredHour,
    this.preferredWindow = 3.0,
    this.wearPerUse = 0.0,
    this.cooldownMinutes = 0,
    this.minNeedToStart = const {},
  });

  final String id;

  /// Für Debug-Overlays und Gedankenblasen ("liest", "gießt die Monstera").
  final String label;

  /// Erste Person, poetisch nutzbar ("ich lese", "ich gieße").
  final String verb;

  /// Bedürfnisänderung **pro Sim-Stunde** während der Ausführung.
  final Map<NeedType, double> rates;

  final double baseDurationMinutes;
  final Set<String> tags;
  final Posture posture;

  /// Wenn `true`, kann nur ein Bewohner gleichzeitig – das Objekt ist besetzt.
  final bool exclusive;

  final bool requiresWorking;
  final bool requiresBroken;
  final bool requiresThirstyPlant;
  final bool isSleep;

  /// Bevorzugte Tageszeit als Stunde (0–24); `null` = jederzeit.
  final double? preferredHour;

  /// Halbwertsbreite des Zeitfensters in Stunden.
  final double preferredWindow;

  /// Verschleiß pro Nutzung; treibt die Ausfallwahrscheinlichkeit.
  final double wearPerUse;

  /// Sperrzeit des Objekts nach der Nutzung (Sim-Minuten).
  final int cooldownMinutes;

  /// Untergrenzen, unter denen die Aktion sinnlos ist
  /// (z. B. Kochen erst ab genug Energie).
  final Map<NeedType, double> minNeedToStart;

  /// Erwarteter Gewinn eines Bedürfnisses über die volle Dauer, gedeckelt auf
  /// den tatsächlich noch fehlenden Rest – ein volles Bedürfnis lässt sich
  /// nicht weiter füllen, also darf es den Score auch nicht treiben.
  double expectedGain(NeedType n, double currentValue) {
    final rate = rates[n];
    if (rate == null) return 0.0;
    final raw = rate * (baseDurationMinutes / 60.0);
    if (raw >= 0) {
      return raw.clamp(0.0, 1.0 - currentValue);
    }
    return -((-raw).clamp(0.0, currentValue));
  }

  @override
  String toString() => 'Affordance($id)';
}
