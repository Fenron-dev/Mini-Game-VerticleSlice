import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../../sim/model/grid.dart';
import '../../sim/model/room.dart';
import '../vertical_slice_game.dart';

/// Unsichtbare Fläche über einem Raum, die den **Fokusmodus** auslöst.
///
/// Liegt unter Möbeln und Bewohnern: Ein Doppeltipp zeigt den Raum, ein
/// einfacher Tipp trifft aber weiterhin das Sofa.
class RoomTouchComponent extends PositionComponent
    with DoubleTapCallbacks, HasGameReference<VerticalSliceGame> {
  RoomTouchComponent(this.room) : super(priority: 5);

  final Room room;

  static const double _tile = HouseGeometry.tileSize;

  final Paint _frame = Paint()
    ..color = const Color(0x44FFE2B8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void onLoad() {
    position = Vector2(room.bounds.left * _tile, room.bounds.top * _tile);
    size = Vector2(room.bounds.width * _tile, room.bounds.height * _tile);
  }

  @override
  void onDoubleTapUp(DoubleTapEvent event) => game.toggleFocus(room);

  @override
  void render(Canvas canvas) {
    if (game.focusedRoomId != room.id) return;
    // Ein dünner Rahmen markiert, worauf gerade geschaut wird.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
        const Radius.circular(3),
      ),
      _frame,
    );
  }
}
