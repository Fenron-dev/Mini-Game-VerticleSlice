import 'dart:math' as math;

/// Die fünf Grundbedürfnisse eines Bewohners.
///
/// Konvention: **Alle Werte laufen von 0.0 (leer / dringend) bis 1.0 (gestillt).**
/// Auch [NeedType.hunger] – ein Wert von 1.0 heißt "satt", nicht "hungrig".
/// Diese Einheitlichkeit macht das Utility-Scoring trivial: Dringlichkeit ist
/// immer eine Funktion von `1 - wert`.
enum NeedType { energy, hunger, hygiene, social, contentment }

extension NeedTypeInfo on NeedType {
  String get label => switch (this) {
        NeedType.energy => 'Energie',
        NeedType.hunger => 'Sättigung',
        NeedType.hygiene => 'Sauberkeit',
        NeedType.social => 'Sozialkontakt',
        NeedType.contentment => 'Zufriedenheit',
      };

  /// Basisverfall pro Sim-Stunde im Wachzustand.
  double get baseDecayPerHour => switch (this) {
        NeedType.energy => 0.055, // ~18 h bis zur Erschöpfung
        NeedType.hunger => 0.075, // ~13 h bis zum Hungern
        NeedType.hygiene => 0.042,
        NeedType.social => 0.048,
        // Zufriedenheit verfällt kaum von selbst – sie *folgt* den anderen
        // Bedürfnissen (siehe [NeedSet.decay]).
        NeedType.contentment => 0.008,
      };

  /// Grundgewicht im Utility-Scoring. Traits skalieren das pro Bewohner.
  double get baseWeight => switch (this) {
        NeedType.energy => 1.15,
        NeedType.hunger => 1.10,
        NeedType.hygiene => 0.85,
        NeedType.social => 0.80,
        NeedType.contentment => 0.70,
      };
}

/// Antwortkurve des Utility-Systems: aus einem Bedürfniswert wird Dringlichkeit.
///
/// Konvex (Exponent > 1), damit ein halb volles Bedürfnis noch entspannt ist und
/// erst der untere Bereich wirklich zieht. Unterhalb von `criticalThreshold`
/// kommt ein Notfall-Multiplikator dazu, damit ein fast leeres Bedürfnis jede
/// gemütliche Alternative überstimmt.
double urgencyCurve(double value) {
  const criticalThreshold = 0.18;
  final v = value.clamp(0.0, 1.0);
  var u = math.pow(1.0 - v, 2.2).toDouble();
  if (v < criticalThreshold) {
    // Sanft einsetzender Faktor bis 2.5x, kein Sprung an der Schwelle.
    final t = (criticalThreshold - v) / criticalThreshold;
    u *= 1.0 + 1.5 * t;
  }
  return u;
}

/// Der Bedürfnisvektor eines Bewohners. Bewusst mutierbar – pro Tick wird er
/// tausendfach angefasst, Value-Semantik wäre reine Allokationsarbeit.
class NeedSet {
  NeedSet(Map<NeedType, double> values)
      : _v = {
          for (final n in NeedType.values)
            n: (values[n] ?? 0.7).clamp(0.0, 1.0),
        };

  NeedSet.filled(double value)
      : _v = {for (final n in NeedType.values) n: value.clamp(0.0, 1.0)};

  /// Leicht gestreute Startwerte, damit nicht alle Bewohner im Gleichschritt
  /// dasselbe Bedürfnis entwickeln.
  factory NeedSet.initial(math.Random rng) => NeedSet({
        for (final n in NeedType.values) n: 0.55 + rng.nextDouble() * 0.35,
      });

  final Map<NeedType, double> _v;

  double operator [](NeedType n) => _v[n]!;

  void operator []=(NeedType n, double value) {
    _v[n] = value.clamp(0.0, 1.0);
  }

  Map<NeedType, double> get values => Map.unmodifiable(_v);

  /// Dringlichkeit eines einzelnen Bedürfnisses (0 = zufrieden).
  double urgency(NeedType n) => urgencyCurve(_v[n]!);

  /// Das Bedürfnis mit der höchsten Dringlichkeit – Basis für Gedankenblasen.
  NeedType get mostUrgent {
    var best = NeedType.values.first;
    var bestU = urgency(best);
    for (final n in NeedType.values.skip(1)) {
      final u = urgency(n);
      if (u > bestU) {
        best = n;
        bestU = u;
      }
    }
    return best;
  }

  /// Mittelwert ohne Zufriedenheit – das "Lebensgefühl", dem sich
  /// [NeedType.contentment] annähert.
  double get baselineWellbeing {
    var sum = 0.0;
    var count = 0;
    for (final n in NeedType.values) {
      if (n == NeedType.contentment) continue;
      sum += _v[n]!;
      count++;
    }
    return sum / count;
  }

  /// Wendet Raten (Einheit: Anteil **pro Sim-Stunde**) für [hours] an.
  void applyRates(Map<NeedType, double> ratesPerHour, double hours) {
    ratesPerHour.forEach((n, rate) {
      this[n] = _v[n]! + rate * hours;
    });
  }

  /// Natürlicher Verfall über [hours] Sim-Stunden.
  ///
  /// [decayMultipliers] kommt aus den Traits (Ordnungsliebe lässt Sauberkeit
  /// schneller "verfallen", weil die Person es früher merkt).
  /// Im Schlaf ([asleep]) ruhen Hygiene und Sozialkontakt fast vollständig.
  void decay(
    double hours, {
    Map<NeedType, double> decayMultipliers = const {},
    bool asleep = false,
  }) {
    for (final n in NeedType.values) {
      if (n == NeedType.contentment) continue;
      if (n == NeedType.energy && asleep) continue; // Schlaf füllt separat auf
      var rate = n.baseDecayPerHour * (decayMultipliers[n] ?? 1.0);
      if (asleep && (n == NeedType.hygiene || n == NeedType.social)) {
        rate *= 0.15;
      }
      this[n] = _v[n]! - rate * hours;
    }

    // Zufriedenheit driftet träge Richtung Grundwohlbefinden. Dadurch ist sie
    // ein Nachlaufindikator für "läuft das Leben gerade rund?" und lässt sich
    // nicht direkt farmen.
    final target = baselineWellbeing;
    final delta = target - _v[NeedType.contentment]!;
    const driftPerHour = 0.22;
    this[NeedType.contentment] = _v[NeedType.contentment]! +
        delta * (1 - math.exp(-driftPerHour * hours)) -
        NeedType.contentment.baseDecayPerHour * hours;
  }

  NeedSet copy() => NeedSet(Map.of(_v));

  Map<String, dynamic> toJson() =>
      {for (final e in _v.entries) e.key.name: e.value};

  static NeedSet fromJson(Map<String, dynamic> json) => NeedSet({
        for (final n in NeedType.values)
          n: (json[n.name] as num?)?.toDouble() ?? 0.7,
      });

  @override
  String toString() => _v.entries
      .map((e) => '${e.key.name}=${e.value.toStringAsFixed(2)}')
      .join(' ');
}
