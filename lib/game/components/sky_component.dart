import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../sim/house_world.dart';
import '../../sim/model/grid.dart';
import '../palette.dart';

/// Großzügige Fläche um das Haus herum – der Himmel und die Atmosphäre
/// müssen beide genau diese Fläche abdecken, sonst entsteht an der Hauskante
/// eine sichtbare Naht (über dem Dach warm, einen Pixel daneben nicht).
final Rect skyArea = Rect.fromLTRB(
  -HouseGeometry.worldWidth,
  -HouseGeometry.worldHeight,
  HouseGeometry.worldWidth * 2,
  HouseGeometry.worldHeight * 2,
);

/// Der Himmel hinter dem Haus.
///
/// Das Haus ist höher als breit, auf einem Tablet im Querformat bleibt also
/// links und rechts Platz. Ein Verlauf statt einer glatten Fläche lässt diesen
/// Rand wie Absicht aussehen – und trägt den Tageszeitwechsel mit.
class SkyComponent extends PositionComponent {
  SkyComponent(this.world) : super(priority: -10);

  final HouseWorld world;
  final Paint _paint = Paint();

  @override
  void render(Canvas canvas) {
    final daylight = world.clock.daylight;
    final base = Palette.sky(daylight, world.clock.eveningWarmth);

    _paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Palette.skyHigh(base, daylight),
        base,
        Palette.skyLow(base, daylight),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(skyArea);
    canvas.drawRect(skyArea, _paint);

    _renderStars(canvas, daylight);
  }

  /// Ein paar Punkte am Nachthimmel. Fest platziert, nicht zufällig pro Bild –
  /// flackernde Sterne wären genau das Gegenteil von ruhig.
  void _renderStars(Canvas canvas, double daylight) {
    final strength = (1.0 - daylight * 2.2).clamp(0.0, 1.0);
    if (strength <= 0.02) return;

    _paint
      ..shader = null
      ..color = const Color(0xFFF0F3FF).withValues(alpha: 0.5 * strength);

    var seed = 1;
    for (var i = 0; i < 60; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final x = -HouseGeometry.worldWidth +
          (seed % 3000) / 3000 * HouseGeometry.worldWidth * 3;
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final y = -HouseGeometry.worldHeight +
          (seed % 3000) / 3000 * HouseGeometry.worldHeight * 1.4;
      canvas.drawRect(Rect.fromLTWH(x, y, 1.6, 1.6), _paint);
    }
  }
}
