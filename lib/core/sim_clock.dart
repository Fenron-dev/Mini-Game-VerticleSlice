import 'dart:math' as math;

/// Zeitraffer-Stufen. Bewusst diskret: ein stufenloser Regler lädt zum
/// Optimieren ein, drei Stufen laden zum Zuschauen ein.
enum TimeScale {
  x1(1, '1×'),
  x4(4, '4×'),
  x16(16, '16×');

  const TimeScale(this.factor, this.label);
  final int factor;
  final String label;

  static TimeScale fromFactor(int f) =>
      TimeScale.values.firstWhere((s) => s.factor == f, orElse: () => x1);
}

/// Die Uhr der Simulation.
///
/// **Kopplung an die echte Uhrzeit:** Bei 1× läuft die Sim-Zeit sekundengenau
/// mit der Wanduhr, und beim allerersten Start wird sie auf die lokale Uhrzeit
/// gesetzt. Wer morgens aufmacht, sieht das Haus aufwachen.
///
/// Zeitraffer lässt die Sim-Zeit *vorlaufen*; die Differenz zur Wanduhr bleibt
/// erhalten, statt zurückzuspringen – ein Rücksprung würde bedeuten, dass
/// Bewohner Dinge "un-tun".
class SimClock {
  SimClock({required double simEpochSeconds, this.scale = TimeScale.x1})
      : _sim = simEpochSeconds;

  /// Uhr, die auf die lokale Wanduhrzeit des heutigen Tages gestellt ist.
  factory SimClock.fromWallClock([DateTime? now]) {
    final t = now ?? DateTime.now();
    final midnight = DateTime(t.year, t.month, t.day);
    final secondsToday = t.difference(midnight).inMilliseconds / 1000.0;
    return SimClock(simEpochSeconds: secondsToday);
  }

  static const double secondsPerDay = 86400.0;

  double _sim;
  TimeScale scale;

  /// Absolute Sim-Zeit in Sekunden seit Tag 0, 00:00. Monoton steigend.
  double get simSeconds => _sim;

  double get simMinutes => _sim / 60.0;
  double get simHours => _sim / 3600.0;

  /// Tag seit Start (0-basiert).
  int get day => (_sim / secondsPerDay).floor();

  /// Uhrzeit als Stunde mit Nachkommastellen, 0.0 … 24.0.
  double get hourOfDay => (_sim % secondsPerDay) / 3600.0;

  int get hour => hourOfDay.floor();
  int get minute => ((hourOfDay - hour) * 60).floor();

  String get clockLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Sim-Zeit um [realSeconds] echte Sekunden weiterdrehen, skaliert.
  void advanceReal(double realSeconds) {
    _sim += realSeconds * scale.factor;
  }

  /// Sim-Zeit direkt weiterdrehen (Nachberechnung nutzt das mit 1×).
  void advanceSim(double simSeconds) {
    _sim += simSeconds;
  }

  /// Vorsprung der Sim-Zeit gegenüber der Wanduhr, in Sekunden.
  double driftFromWallClock([DateTime? now]) {
    final t = now ?? DateTime.now();
    final midnight = DateTime(t.year, t.month, t.day);
    final wall = t.difference(midnight).inMilliseconds / 1000.0;
    return (_sim % secondsPerDay) - wall;
  }

  /// Setzt die Tageszeit wieder auf die Wanduhr, ohne den Tageszähler
  /// zurückzudrehen (die Sim-Zeit bleibt monoton).
  void resyncToWallClock([DateTime? now]) {
    final t = now ?? DateTime.now();
    final midnight = DateTime(t.year, t.month, t.day);
    final wall = t.difference(midnight).inMilliseconds / 1000.0;
    var target = day * secondsPerDay + wall;
    if (target < _sim) target += secondsPerDay; // nie rückwärts
    _sim = target;
  }

  /// 0 = tiefe Nacht, 1 = heller Mittag. Weiche Kurve für Lichtstimmung.
  double get daylight {
    // Sonnenaufgang ~6:30, Sonnenuntergang ~20:30.
    const sunrise = 6.5;
    const sunset = 20.5;
    final h = hourOfDay;
    if (h <= sunrise - 1.0 || h >= sunset + 1.0) return 0.0;
    if (h >= sunrise + 1.0 && h <= sunset - 1.0) return 1.0;
    if (h < sunrise + 1.0) {
      return ((h - (sunrise - 1.0)) / 2.0).clamp(0.0, 1.0);
    }
    return (((sunset + 1.0) - h) / 2.0).clamp(0.0, 1.0);
  }

  /// 0 … 1, Maximum zur goldenen Stunde – treibt das warme Abendlicht.
  double get eveningWarmth {
    const goldenHour = 19.5;
    final d = circularHourDistance(hourOfDay, goldenHour);
    return math.exp(-(d * d) / 3.0);
  }

  Map<String, dynamic> toJson() => {
        'sim': _sim,
        'scale': scale.factor,
      };

  static SimClock fromJson(Map<String, dynamic> j) => SimClock(
        simEpochSeconds: (j['sim'] as num).toDouble(),
        scale: TimeScale.fromFactor(j['scale'] as int? ?? 1),
      );
}

/// Kreisförmiger Abstand zweier Uhrzeiten in Stunden (max. 12).
double circularHourDistance(double a, double b) {
  final d = (a - b).abs() % 24.0;
  return d > 12.0 ? 24.0 - d : d;
}
