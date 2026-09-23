import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../sim/model/cat.dart';
import '../../sim/model/grid.dart';
import '../palette.dart';

/// Nebel. Ein kleines graues Rechteck mit Schwanz, das durchs Haus zieht.
class CatComponent extends PositionComponent {
  CatComponent(this.cat) : super(priority: 25);

  final Cat cat;

  static const double _tile = HouseGeometry.tileSize;

  final Paint _paint = Paint()..isAntiAlias = true;
  double _tailPhase = 0;

  @override
  void update(double dt) {
    _tailPhase += dt * 2.2;
    const w = _tile * 1.15;
    final h = cat.mood == CatMood.doze ? _tile * 0.36 : _tile * 0.55;
    size = Vector2(w, h);
    position = Vector2(
      cat.x * _tile + (_tile - w) / 2,
      (cat.y + 1) * _tile - h,
    );
  }

  @override
  void render(Canvas canvas) {
    _paint.color = Palette.cat;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Radius.circular(size.y * 0.45),
      ),
      _paint,
    );

    if (cat.mood == CatMood.doze) return;

    // Kopf vorn, Schwanz hinten – beides folgt der Blickrichtung.
    final forward = cat.facing > 0;
    final headSize = size.y * 0.85;
    canvas.drawOval(
      Rect.fromLTWH(
        forward ? size.x - headSize * 0.8 : -headSize * 0.2,
        -headSize * 0.35,
        headSize,
        headSize,
      ),
      _paint,
    );

    final p = _tailPhase % 2.0;
    final sway = p < 1.0 ? p : 2.0 - p;
    canvas.drawRect(
      Rect.fromLTWH(
        forward ? -3.0 : size.x,
        -sway * 3.0,
        3.0,
        size.y * 0.9,
      ),
      _paint,
    );
  }
}
