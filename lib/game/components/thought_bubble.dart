import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../sim/model/grid.dart';
import '../../sim/model/resident.dart';

/// Die Gedankenblase über einem Bewohner – oder eine kurze Rückmeldung an
/// einem Ding ("gegossen").
///
/// Bewusst ein Spielobjekt und kein Flutter-Overlay: Sie gehört an eine Person
/// im Haus, nicht an einen Bildschirmrand, und sie wandert mit, wenn jemand
/// weitergeht.
class ThoughtBubble extends PositionComponent {
  ThoughtBubble({
    required this.text,
    this.resident,
    this.anchorCell,
    this.lifetime = 7.0,
  })  : assert(
          resident != null || anchorCell != null,
          'Eine Blase braucht jemanden oder einen Ort',
        ),
        super(priority: 60);

  /// Folgt dieser Person, wenn gesetzt.
  final Resident? resident;

  /// Fester Ort im Gitter – für Rückmeldungen auf Dinge statt auf Menschen.
  final GridPos? anchorCell;

  final String text;

  /// Sekunden **echter** Zeit – eine Gedankenblase gehört dem Betrachter,
  /// nicht der Simulation, und verschwindet auch bei 16× nicht schneller.
  final double lifetime;

  static const double _tile = HouseGeometry.tileSize;
  static const double _maxWidth = 150.0;
  static const double _padding = 7.0;

  double _age = 0;

  late final TextPainter _painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xFF2C2733),
        fontSize: 9.5,
        height: 1.32,
        fontStyle: FontStyle.italic,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  @override
  void onLoad() {
    _painter.layout(maxWidth: _maxWidth - _padding * 2);
    size = Vector2(
      _painter.width + _padding * 2,
      _painter.height + _padding * 2,
    );
    _follow();
  }

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= lifetime) {
      removeFromParent();
      return;
    }
    _follow();
  }

  void _follow() {
    final cellX = resident?.x ?? anchorCell!.x.toDouble();
    final cellY = resident?.y ?? anchorCell!.y.toDouble();

    // Über dem Kopf bzw. über dem Ding, aber nie außerhalb des Hauses.
    final x = (cellX * _tile + _tile / 2 - size.x / 2)
        .clamp(_tile, HouseGeometry.worldWidth - size.x - _tile);
    final y = (cellY + 1) * _tile - _tile * 2.4 - size.y;
    position = Vector2(x, y.clamp(2.0, HouseGeometry.worldHeight - size.y));
  }

  /// Ein- und Ausblenden, damit nichts hart aufpoppt.
  double get _opacity {
    const fade = 0.45;
    if (_age < fade) return _age / fade;
    final remaining = lifetime - _age;
    if (remaining < fade) return (remaining / fade).clamp(0.0, 1.0);
    return 1.0;
  }

  @override
  void render(Canvas canvas) {
    final alpha = _opacity;
    if (alpha <= 0.01) return;

    // Eine Ebene für alles: So verblasst der Text mit der Blase, statt bis
    // zuletzt scharf über einem halb verschwundenen Kasten zu stehen.
    canvas.saveLayer(
      Rect.fromLTWH(-8, -4, size.x + 16, size.y + 20),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
    );

    const bubble = Color(0xFFF2ECE2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(7),
      ),
      Paint()..color = bubble.withValues(alpha: 0.94),
    );

    // Zwei Tupfen als Gedankenschwanz nach unten.
    final tail = Paint()..color = bubble.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(size.x * 0.32, size.y + 5), 3.2, tail);
    canvas.drawCircle(Offset(size.x * 0.26, size.y + 11), 1.9, tail);

    _painter.paint(canvas, const Offset(_padding, _padding));
    canvas.restore();
  }
}
