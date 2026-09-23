import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../sim/house_world.dart';
import '../palette.dart';
import 'sky_component.dart';

/// Licht und Wetter über dem ganzen Bild.
///
/// Diese Schicht entscheidet nichts – sie färbt nur. Genau deshalb liegt sie
/// ganz oben und ganz außerhalb der Simulation: Man kann sie wegnehmen, ohne
/// dass sich am Verhalten der Bewohner etwas ändert.
///
/// Sie deckt dieselbe Fläche ab wie der Himmel ([skyArea]), **nicht** nur das
/// Haus: Auf die Hausfläche begrenzt endete das Abendlicht exakt an der
/// Gebäudekante – eine rechteckige Naht mitten in der Luft.
class AtmosphereComponent extends PositionComponent {
  AtmosphereComponent(this.world) : super(priority: 100);

  final HouseWorld world;

  static const int _dropCount = 140;

  final Paint _paint = Paint();
  final math.Random _rng = math.Random(11);

  late final List<_Drop> _drops = List.generate(
    _dropCount,
    (_) => _Drop(
      x: skyArea.left + _rng.nextDouble() * skyArea.width,
      y: skyArea.top + _rng.nextDouble() * skyArea.height,
      speed: 180 + _rng.nextDouble() * 220,
      length: 5 + _rng.nextDouble() * 9,
    ),
  );

  /// Weicher Übergang, damit Regen nicht schlagartig einsetzt.
  double _rainStrength = 0;

  @override
  void update(double dt) {
    final target = world.weather == Weather.rain ? 1.0 : 0.0;
    _rainStrength += (target - _rainStrength) * (dt * 0.6).clamp(0.0, 1.0);
    if (_rainStrength <= 0.01) return;

    for (final drop in _drops) {
      drop.y += drop.speed * dt;
      // Leichte Schräge – Regen fällt selten senkrecht.
      drop.x -= drop.speed * dt * 0.18;
      if (drop.y > skyArea.bottom) {
        drop.y = skyArea.top;
        drop.x = skyArea.left + _rng.nextDouble() * skyArea.width;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final daylight = world.clock.daylight;

    // Nacht legt sich als Schleier über alles Gezeichnete.
    final veil = Palette.nightVeil(daylight);
    if (veil.a > 0.01) {
      _paint
        ..shader = null
        ..color = veil
        ..blendMode = BlendMode.srcOver;
      canvas.drawRect(skyArea, _paint);
    }

    // Warmes Abendlicht, von links oben einfallend.
    final warmth = world.clock.eveningWarmth;
    if (warmth > 0.02) {
      _paint
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.eveningWash(warmth),
            Palette.eveningWash(warmth * 0.15),
          ],
        ).createShader(skyArea)
        ..blendMode = BlendMode.plus;
      canvas.drawRect(skyArea, _paint);
      _paint
        ..shader = null
        ..blendMode = BlendMode.srcOver;
    }

    if (_rainStrength > 0.01) {
      final stroke = Paint()
        ..color = Palette.rain(0.35 * _rainStrength)
        ..strokeWidth = 1.2
        ..isAntiAlias = false;
      for (final drop in _drops) {
        canvas.drawLine(
          Offset(drop.x, drop.y),
          Offset(drop.x - drop.length * 0.18, drop.y + drop.length),
          stroke,
        );
      }
    }
  }
}

class _Drop {
  _Drop({
    required this.x,
    required this.y,
    required this.speed,
    required this.length,
  });

  double x;
  double y;
  final double speed;
  final double length;
}
