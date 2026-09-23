import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/painting.dart';

import '../sim/model/interactable.dart';
import '../sim/model/room.dart';

/// Prozedurale Farbflächen als Platzhalter-Assets.
///
/// Alles im Haus ist zunächst ein farbiges Rechteck. Das ist Absicht: Die
/// Simulation soll lesbar sein, bevor irgendjemand Pixel malt. Wenn später
/// Sprites kommen, ändert sich nur diese Datei und die `render`-Methoden –
/// die Palette bleibt der Ort, an dem die Stimmung festgelegt wird.
abstract final class Palette {
  static const nightSky = Color(0xFF1B2033);
  static const daySky = Color(0xFF9FB6C9);
  static const duskSky = Color(0xFFD9906A);

  static const wall = Color(0xFF3A3340);
  static const slab = Color(0xFF2E2833);
  static const outerWall = Color(0xFF272230);

  static const stairwell = Color(0xFF4A4150);
  static const stairTread = Color(0xFF5C5266);

  /// Warmes Kunstlicht in bewohnten Räumen.
  static const lampLight = Color(0xFFFFCB8A);

  static const cat = Color(0xFF7C8896);

  static Color roomFill(RoomKind kind) => switch (kind) {
        RoomKind.bedroom => const Color(0xFF4C4560),
        RoomKind.kitchen => const Color(0xFF56503F),
        RoomKind.living => const Color(0xFF5A4A46),
        RoomKind.bath => const Color(0xFF3F5259),
        RoomKind.hall => stairwell,
        RoomKind.roof => const Color(0xFF3E4A50),
        RoomKind.cellar => const Color(0xFF332E38),
      };

  /// Boden eines Raums – etwas dunkler als die Wand dahinter.
  static Color roomFloor(RoomKind kind) => _darken(roomFill(kind), 0.22);

  static Color objectColor(ObjectKind kind) => switch (kind) {
        ObjectKind.bed => const Color(0xFFB9A6C4),
        ObjectKind.sofa => const Color(0xFF9C6F63),
        ObjectKind.armchair => const Color(0xFF8E6A60),
        ObjectKind.table => const Color(0xFFB28B62),
        ObjectKind.stove => const Color(0xFF8C8B93),
        ObjectKind.fridge => const Color(0xFFCFD3D6),
        ObjectKind.sink => const Color(0xFFB6C4C9),
        ObjectKind.shower => const Color(0xFF8FB4BF),
        ObjectKind.toilet => const Color(0xFFDCE2E4),
        ObjectKind.desk => const Color(0xFF9C7B55),
        ObjectKind.bookshelf => const Color(0xFF7A5C46),
        ObjectKind.radio => const Color(0xFFC4A25E),
        ObjectKind.plant => const Color(0xFF6FA25E),
        ObjectKind.washer => const Color(0xFFC9CED2),
        ObjectKind.pinboard => const Color(0xFFC7A46B),
        ObjectKind.bench => const Color(0xFF8A7A63),
        ObjectKind.catBowl => const Color(0xFFD08C6A),
        ObjectKind.boiler => const Color(0xFF6E5B4E),
        ObjectKind.lamp => lampLight,
      };

  /// Sichthöhe eines Möbelstücks in Tiles – der Querschnitt ist eine
  /// Seitenansicht, also braucht jedes Ding eine Silhouette.
  static double objectHeight(ObjectKind kind) => switch (kind) {
        ObjectKind.bed => 0.9,
        ObjectKind.sofa => 1.2,
        ObjectKind.armchair => 1.3,
        ObjectKind.table => 1.1,
        ObjectKind.stove => 1.6,
        ObjectKind.fridge => 2.4,
        ObjectKind.sink => 1.1,
        ObjectKind.shower => 2.6,
        ObjectKind.toilet => 1.0,
        ObjectKind.desk => 1.3,
        ObjectKind.bookshelf => 2.6,
        ObjectKind.radio => 0.7,
        ObjectKind.plant => 1.5,
        ObjectKind.washer => 1.5,
        ObjectKind.pinboard => 1.6,
        ObjectKind.bench => 0.8,
        ObjectKind.catBowl => 0.3,
        ObjectKind.boiler => 2.2,
        ObjectKind.lamp => 0.8,
      };

  /// Bewohnerfarbe aus dem Farbton. Gedämpft, damit niemand herausschreit.
  static Color resident(double hue, {double lightness = 0.62}) =>
      HSLColor.fromAHSL(1.0, hue % 360, 0.42, lightness).toColor();

  // ---- Tageslicht --------------------------------------------------------

  /// Himmelsfarbe aus Tageshelligkeit und Abendwärme.
  static Color sky(double daylight, double warmth) {
    final base = Color.lerp(nightSky, daySky, daylight)!;
    return Color.lerp(base, duskSky, warmth * 0.55 * (1 - daylight * 0.4))!;
  }

  /// Oberer und unterer Rand des Himmelsverlaufs. Oben kühler und dunkler,
  /// unten wärmer – wie Dunst über einer Stadt.
  static Color skyHigh(Color base, double daylight) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness(
            (hsl.lightness * (0.62 + 0.12 * daylight)).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 1.15).clamp(0.0, 1.0))
        .toColor();
  }

  static Color skyLow(Color base, double daylight) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness(
            (hsl.lightness * (1.12 + 0.1 * daylight)).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0))
        .toColor();
  }

  /// Schleier über dem ganzen Bild: nachts blau und dicht, tagsüber weg.
  static Color nightVeil(double daylight) {
    final strength = (1.0 - daylight).clamp(0.0, 1.0);
    return const Color(0xFF141A2E).withValues(alpha: 0.68 * strength);
  }

  /// Warmes Abendlicht, schräg über alles gelegt.
  static Color eveningWash(double warmth) =>
      const Color(0xFFFF9E4F).withValues(alpha: 0.22 * warmth.clamp(0.0, 1.0));

  static Color rain(double alpha) =>
      const Color(0xFFBFD4E4).withValues(alpha: alpha);

  // ---- Zustände ----------------------------------------------------------

  /// Ein Defekt zeigt sich als Entsättigung, nicht als rotes Warnsymbol.
  static Color broken(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withSaturation(hsl.saturation * 0.2)
        .withLightness(hsl.lightness * 0.72)
        .toColor();
  }

  /// Eine durstige Pflanze verliert Farbe, statt zu blinken.
  static Color thirsty(Color base, double moisture) {
    final hsl = HSLColor.fromColor(base);
    final t = (1.0 - (moisture / 0.45)).clamp(0.0, 1.0);
    return HSLColor.fromAHSL(
      1.0,
      lerpDouble(hsl.hue, 38, t)!,
      hsl.saturation * (1 - 0.45 * t),
      hsl.lightness * (1 - 0.18 * t),
    ).toColor();
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Leichte, deterministische Aufhellung – gibt gleichen Flächen Textur,
  /// ohne dass irgendwo ein Bild geladen werden müsste.
  static Color speckle(Color base, int seed) {
    final delta = (math.Random(seed).nextDouble() - 0.5) * 0.05;
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }
}
