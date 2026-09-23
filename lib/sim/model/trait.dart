import 'need.dart';

/// Charaktereigenschaften. Jeder Bewohner trägt 3–4 davon.
///
/// Traits sind bewusst **rein deklarativ**: Sie liefern Multiplikatoren, keine
/// Sonderlogik. Der ActionScorer fragt sie ab, niemand verzweigt auf
/// `if (trait == earlyBird)`. So bleibt neues Verhalten eine Datenänderung.
enum Trait {
  earlyBird(
    label: 'Frühaufsteher',
    blurb: 'Wach, bevor das Haus es ist.',
    circadianShiftHours: -1.8,
    needWeights: {NeedType.energy: 1.1},
    decayMultipliers: {NeedType.energy: 1.08},
    tagAffinity: {'morning': 0.35, 'quiet': 0.15},
  ),
  nightOwl(
    label: 'Nachteule',
    blurb: 'Die besten Gedanken kommen nach elf.',
    circadianShiftHours: 2.6,
    needWeights: {NeedType.energy: 0.92},
    decayMultipliers: {NeedType.energy: 0.94},
    tagAffinity: {'leisure': 0.3, 'quiet': 0.2, 'morning': -0.4},
  ),
  tidy(
    label: 'Ordnungsliebe',
    blurb: 'Merkt den Staub, bevor er sich setzt.',
    needWeights: {NeedType.hygiene: 1.45},
    // Nicht "wird schneller schmutzig", sondern "stört sich früher daran".
    decayMultipliers: {NeedType.hygiene: 1.3},
    tagAffinity: {'clean': 0.5, 'repair': 0.2, 'messy': -0.45},
  ),
  sociable(
    label: 'Geselligkeit',
    blurb: 'Ein Flur ist auch ein Wohnzimmer.',
    needWeights: {NeedType.social: 1.5},
    decayMultipliers: {NeedType.social: 1.35},
    tagAffinity: {'social': 0.55, 'shared': 0.3, 'solo': -0.2},
  ),
  solitary(
    label: 'Zurückgezogen',
    blurb: 'Stille ist kein Mangel.',
    needWeights: {NeedType.social: 0.6},
    decayMultipliers: {NeedType.social: 0.55},
    tagAffinity: {'solo': 0.4, 'quiet': 0.35, 'social': -0.35},
  ),
  greenThumb(
    label: 'Grüner Daumen',
    blurb: 'Redet mit den Blättern, leise.',
    needWeights: {NeedType.contentment: 1.15},
    tagAffinity: {'plant': 0.7, 'care': 0.3},
  ),
  handy(
    label: 'Handwerklich',
    blurb: 'Sieht in jedem Defekt eine Verabredung.',
    tagAffinity: {'repair': 0.75, 'broken': 0.4},
  ),
  gourmet(
    label: 'Genießer',
    blurb: 'Kochen ist die längere Freude.',
    needWeights: {NeedType.hunger: 1.12},
    tagAffinity: {'cook': 0.55, 'snack': -0.3, 'shared': 0.2},
  ),
  restless(
    label: 'Rastlos',
    blurb: 'Bleibt selten zweimal am selben Ort.',
    inertiaMultiplier: 0.45,
    varietyMultiplier: 1.9,
    tagAffinity: {'leisure': 0.2},
  ),
  homebody(
    label: 'Stubenhocker',
    blurb: 'Die eigenen vier Wände reichen weit.',
    inertiaMultiplier: 1.5,
    tagAffinity: {'home': 0.45, 'shared': -0.15},
    travelCostMultiplier: 1.7,
  );

  const Trait({
    required this.label,
    required this.blurb,
    this.circadianShiftHours = 0.0,
    this.needWeights = const {},
    this.decayMultipliers = const {},
    this.tagAffinity = const {},
    this.inertiaMultiplier = 1.0,
    this.varietyMultiplier = 1.0,
    this.travelCostMultiplier = 1.0,
  });

  final String label;
  final String blurb;

  /// Verschiebung des Tagesrhythmus in Stunden (negativ = früher).
  final double circadianShiftHours;

  /// Multiplikatoren auf [NeedTypeInfo.baseWeight].
  final Map<NeedType, double> needWeights;

  /// Multiplikatoren auf [NeedTypeInfo.baseDecayPerHour].
  final Map<NeedType, double> decayMultipliers;

  /// Zuschlag pro Affordance-Tag, additiv im Score.
  final Map<String, double> tagAffinity;

  final double inertiaMultiplier;
  final double varietyMultiplier;
  final double travelCostMultiplier;
}

/// Aggregiert die Traits eines Bewohners zu fertigen Nachschlagetabellen.
/// Einmal beim Laden gebaut, danach nur noch gelesen – der Scorer läuft oft.
class TraitProfile {
  TraitProfile(this.traits)
      : needWeights = {
          for (final n in NeedType.values)
            n: traits.fold<double>(
              n.baseWeight,
              (acc, t) => acc * (t.needWeights[n] ?? 1.0),
            ),
        },
        decayMultipliers = {
          for (final n in NeedType.values)
            n: traits.fold<double>(
              1.0,
              (acc, t) => acc * (t.decayMultipliers[n] ?? 1.0),
            ),
        },
        tagAffinity = _mergeTags(traits),
        circadianShiftHours =
            traits.fold<double>(0.0, (acc, t) => acc + t.circadianShiftHours),
        inertia =
            traits.fold<double>(1.0, (acc, t) => acc * t.inertiaMultiplier),
        variety =
            traits.fold<double>(1.0, (acc, t) => acc * t.varietyMultiplier),
        travelCost = traits.fold<double>(
            1.0, (acc, t) => acc * t.travelCostMultiplier);

  final List<Trait> traits;
  final Map<NeedType, double> needWeights;
  final Map<NeedType, double> decayMultipliers;
  final Map<String, double> tagAffinity;
  final double circadianShiftHours;
  final double inertia;
  final double variety;
  final double travelCost;

  static Map<String, double> _mergeTags(List<Trait> traits) {
    final merged = <String, double>{};
    for (final t in traits) {
      t.tagAffinity.forEach((tag, v) {
        merged[tag] = (merged[tag] ?? 0.0) + v;
      });
    }
    return merged;
  }

  /// Summierte Affinität über alle Tags einer Aktion.
  double affinityFor(Set<String> tags) {
    var sum = 0.0;
    for (final tag in tags) {
      sum += tagAffinity[tag] ?? 0.0;
    }
    return sum;
  }

  bool has(Trait t) => traits.contains(t);
}
