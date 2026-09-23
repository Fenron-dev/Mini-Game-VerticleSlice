import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_slice/sim/model/need.dart';

void main() {
  group('NeedSet', () {
    test('Verfall bleibt im gültigen Bereich', () {
      final needs = NeedSet.filled(0.5);
      needs.decay(100); // absurd lange
      for (final n in NeedType.values) {
        expect(needs[n], inInclusiveRange(0.0, 1.0));
      }
    });

    test('Schlaf schont Hygiene und Sozialkontakt', () {
      final awake = NeedSet.filled(0.8);
      final asleep = NeedSet.filled(0.8);
      awake.decay(4);
      asleep.decay(4, asleep: true);

      expect(asleep[NeedType.hygiene], greaterThan(awake[NeedType.hygiene]));
      expect(asleep[NeedType.social], greaterThan(awake[NeedType.social]));
    });

    test('Schlaf lässt Energie nicht von selbst verfallen', () {
      final needs = NeedSet.filled(0.5);
      needs.decay(6, asleep: true);
      expect(needs[NeedType.energy], 0.5);
    });

    test('Trait-Multiplikatoren beschleunigen den Verfall', () {
      final normal = NeedSet.filled(0.9);
      final tidy = NeedSet.filled(0.9);
      normal.decay(5);
      tidy.decay(5, decayMultipliers: {NeedType.hygiene: 1.5});
      expect(tidy[NeedType.hygiene], lessThan(normal[NeedType.hygiene]));
    });

    test('Zufriedenheit folgt dem Grundwohlbefinden', () {
      final good = NeedSet({
        NeedType.energy: 0.9,
        NeedType.hunger: 0.9,
        NeedType.hygiene: 0.9,
        NeedType.social: 0.9,
        NeedType.contentment: 0.2,
      });
      final before = good[NeedType.contentment];
      good.decay(3);
      expect(good[NeedType.contentment], greaterThan(before));

      final bad = NeedSet({
        NeedType.energy: 0.1,
        NeedType.hunger: 0.1,
        NeedType.hygiene: 0.1,
        NeedType.social: 0.1,
        NeedType.contentment: 0.9,
      });
      bad.decay(3);
      expect(bad[NeedType.contentment], lessThan(0.9));
    });

    test('mostUrgent findet das knappste Bedürfnis', () {
      final needs = NeedSet.filled(0.8)..[NeedType.hunger] = 0.1;
      expect(needs.mostUrgent, NeedType.hunger);
    });

    test('applyRates rechnet pro Stunde', () {
      final needs = NeedSet.filled(0.0);
      needs.applyRates({NeedType.energy: 0.5}, 1.0);
      expect(needs[NeedType.energy], closeTo(0.5, 1e-9));
    });
  });

  group('urgencyCurve', () {
    test('ist monoton fallend im Bedürfniswert', () {
      var previous = double.infinity;
      for (var v = 0.0; v <= 1.0; v += 0.05) {
        final u = urgencyCurve(v);
        expect(u, lessThanOrEqualTo(previous + 1e-9));
        previous = u;
      }
    });

    test('gibt kritischen Bedürfnissen deutlichen Vorrang', () {
      expect(urgencyCurve(0.05) / urgencyCurve(0.5), greaterThan(4.0));
    });

    test('ist bei vollem Bedürfnis null', () {
      expect(urgencyCurve(1.0), closeTo(0.0, 1e-12));
    });
  });

  test('NeedSet überlebt eine Runde durch JSON', () {
    final original = NeedSet.initial(math.Random(7));
    final restored = NeedSet.fromJson(original.toJson());
    for (final n in NeedType.values) {
      expect(restored[n], closeTo(original[n], 1e-12));
    }
  });
}
