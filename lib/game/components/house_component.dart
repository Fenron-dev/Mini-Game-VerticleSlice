import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../sim/house_world.dart';
import '../../sim/model/grid.dart';
import '../../sim/model/room.dart';
import '../palette.dart';

/// Der Querschnitt selbst: Mauerwerk, Böden, Räume, Fenster, Treppenhaus.
///
/// Ein einziger Zeichendurchgang statt hunderter Komponenten. Die Struktur
/// ändert sich nie, nur das Licht in den Fenstern.
class HouseComponent extends PositionComponent {
  HouseComponent(this.world) : super(priority: 0);

  final HouseWorld world;

  static const double _tile = HouseGeometry.tileSize;

  final Paint _paint = Paint()..isAntiAlias = false;

  @override
  void render(Canvas canvas) {
    _renderShell(canvas);
    for (final room in world.rooms) {
      _renderRoom(canvas, room);
    }
    _renderStairs(canvas);
  }

  void _renderShell(Canvas canvas) {
    // Außenmauern links und rechts – erst ab Brüstungshöhe des Dachs, darüber
    // ist Himmel, keine Mauer.
    final top =
        (HouseGeometry.floorRowOf(HouseGeometry.roofLevel) + 1) * _tile -
            _tile * 2.6;
    _paint.color = Palette.outerWall;
    canvas.drawRect(
      Rect.fromLTWH(0, top, _tile, HouseGeometry.worldHeight - top),
      _paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (HouseGeometry.gridWidth - 1) * _tile,
        top,
        _tile,
        HouseGeometry.worldHeight - top,
      ),
      _paint,
    );

    // Geschossdecken. Über dem Dach liegt keine – dort ist Himmel.
    _paint.color = Palette.slab;
    for (var level = 0; level < HouseGeometry.roofLevel; level++) {
      final row = HouseGeometry.topRowOf(level);
      canvas.drawRect(
        Rect.fromLTWH(0, row * _tile, HouseGeometry.worldWidth, _tile),
        _paint,
      );
    }
    // Kellersohle.
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        HouseGeometry.worldHeight - _tile * 0.4,
        HouseGeometry.worldWidth,
        _tile * 0.4,
      ),
      _paint,
    );
  }

  void _renderRoom(Canvas canvas, Room room) {
    final rect = Rect.fromLTWH(
      room.bounds.left * _tile,
      room.bounds.top * _tile,
      room.bounds.width * _tile,
      room.bounds.height * _tile,
    );

    if (room.kind == RoomKind.roof) {
      // Die Dachterrasse hat kein Zimmer über sich – hier bleibt der Himmel
      // stehen. Nur Boden und Brüstung, sonst sähe das Dach aus wie eine
      // weitere, sehr dunkle Wohnung.
      _renderRoofTerrace(canvas, room, rect);
      return;
    }

    _paint.color =
        Palette.speckle(Palette.roomFill(room.kind), room.id.codeUnits.length);
    canvas.drawRect(rect, _paint);

    // Trennwand zum nächsten Raum.
    if (room.kind != RoomKind.hall) {
      _paint.color = Palette.wall;
      canvas.drawRect(
        Rect.fromLTWH(
            rect.right - _tile * 0.25, rect.top, _tile * 0.25, rect.height),
        _paint,
      );
    }

    // Fußboden.
    _paint.color = Palette.roomFloor(room.kind);
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left,
        (room.floorRow + 1) * _tile - _tile * 0.3,
        rect.width,
        _tile * 0.3,
      ),
      _paint,
    );

    _renderWindows(canvas, room);
  }

  void _renderRoofTerrace(Canvas canvas, Room room, Rect rect) {
    // Belag, auf dem gestanden wird.
    _paint.color = Palette.roomFill(RoomKind.roof);
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left,
        (room.floorRow + 1) * _tile - _tile * 1.1,
        rect.width,
        _tile * 1.1,
      ),
      _paint,
    );

    // Brüstung: eine niedrige Mauer an der Außenkante.
    _paint.color = Palette.wall;
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left,
        (room.floorRow + 1) * _tile - _tile * 2.6,
        _tile * 0.5,
        _tile * 2.6,
      ),
      _paint,
    );
  }

  /// Fenster sind der einzige Ort, an dem das Haus nach außen spricht: Tagsüber
  /// hell, nachts entweder erleuchtet oder dunkel – je nachdem, ob jemand wach
  /// ist. Wer abends aufs Haus schaut, sieht sofort, wer noch auf ist.
  void _renderWindows(Canvas canvas, Room room) {
    if (room.windowColumns.isEmpty) return;

    final daylight = world.clock.daylight;
    final lit = world.litRooms.contains(room.id);

    for (final column in room.windowColumns) {
      final top = (room.bounds.top + 1) * _tile;
      final rect = Rect.fromLTWH(column * _tile, top, _tile * 1.6, _tile * 2.2);

      if (lit) {
        _paint.color = Palette.lampLight.withValues(alpha: 0.85);
      } else {
        // Ungenutzte Fenster spiegeln nur den Himmel.
        _paint.color = Color.lerp(
          const Color(0xFF20263A),
          Palette.sky(daylight, world.clock.eveningWarmth),
          0.45 + 0.5 * daylight,
        )!;
      }
      canvas.drawRect(rect, _paint);

      // Fensterkreuz.
      _paint.color = Palette.wall.withValues(alpha: 0.9);
      canvas.drawRect(
        Rect.fromLTWH(rect.center.dx - 1, rect.top, 2, rect.height),
        _paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.center.dy - 1, rect.width, 2),
        _paint,
      );

      if (lit) {
        // Warmer Schein in den Raum hinein.
        _paint.color = Palette.lampLight.withValues(alpha: 0.10);
        canvas.drawRect(rect.inflate(_tile * 1.4), _paint);
      }
    }
  }

  void _renderStairs(Canvas canvas) {
    final topRow = HouseGeometry.floorRowOf(HouseGeometry.roofLevel);
    final bottomRow = HouseGeometry.floorRowOf(HouseGeometry.cellarLevel);

    _paint.color = Palette.stairwell;
    canvas.drawRect(
      Rect.fromLTWH(
        HouseGeometry.stairLeft * _tile,
        topRow * _tile,
        (HouseGeometry.stairRight - HouseGeometry.stairLeft + 1) * _tile,
        (bottomRow - topRow + 1) * _tile,
      ),
      _paint,
    );

    // Stufen als schräge Bänder zwischen den Etagen.
    _paint.color = Palette.stairTread;
    for (var y = topRow; y <= bottomRow; y++) {
      final level = HouseGeometry.levelOfRow(y);
      if (HouseGeometry.floorRowOf(level) == y) continue;
      final t = (y - HouseGeometry.topRowOf(level)) / HouseGeometry.levelHeight;
      final x = HouseGeometry.stairWalkLeft * _tile + t * _tile * 1.6;
      canvas.drawRect(
        Rect.fromLTWH(x, y * _tile + _tile * 0.7, _tile * 1.6, _tile * 0.3),
        _paint,
      );
    }
  }
}
