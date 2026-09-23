import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../../sim/model/grid.dart';
import '../../sim/model/interactable.dart';
import '../../sim/simulation.dart';
import '../palette.dart';
import '../vertical_slice_game.dart';

/// Ein Möbelstück im Querschnitt.
///
/// Zwei Eingaben, beide sanft:
/// * **Tippen** repariert, was kaputt ist, und gießt, was durstig ist.
/// * **Ziehen** stellt es um – und verändert damit tatsächlich Gewohnheiten,
///   weil der ActionScorer Wege einrechnet.
class ObjectComponent extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameReference<VerticalSliceGame> {
  ObjectComponent(this.object, this.sim) : super(priority: 20);

  final InteractableObject object;
  final HouseSimulation sim;

  static const double _tile = HouseGeometry.tileSize;

  final Paint _paint = Paint()..isAntiAlias = false;
  final Paint _crackPaint = Paint()
    ..color = const Color(0x77101018)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;

  bool _dragging = false;

  @override
  void onMount() {
    super.onMount();
    _syncToGrid();
  }

  void _syncToGrid() {
    final height = Palette.objectHeight(object.kind) * _tile;
    position = Vector2(
      object.cell.x * _tile,
      (object.cell.y + 1) * _tile - height,
    );
    size = Vector2(object.width * _tile, height);
  }

  @override
  void update(double dt) {
    if (!_dragging) _syncToGrid();
  }

  @override
  void render(Canvas canvas) {
    var color = Palette.objectColor(object.kind);
    if (object.broken) {
      color = Palette.broken(color);
    } else if (object.isPlant) {
      color = Palette.thirsty(color, object.moisture);
    }

    final body = Rect.fromLTWH(0, 0, size.x, size.y);

    // Beim Ziehen halbtransparent, damit der Raum darunter sichtbar bleibt.
    _paint.color = _dragging ? color.withValues(alpha: 0.75) : color;
    canvas.drawRect(body, _paint);

    // Eine hellere Oberkante gibt dem Klotz eine Richtung.
    _paint.color = const Color(0x33FFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y * 0.18), _paint);

    if (object.isOccupied) {
      _paint.color = Palette.lampLight.withValues(alpha: 0.22);
      canvas.drawRect(body, _paint);
    }

    if (object.broken) {
      // Ein Riss statt eines Warnsymbols: Der Defekt bleibt Teil des Bildes.
      canvas.drawPath(
        Path()
          ..moveTo(size.x * 0.3, 0)
          ..lineTo(size.x * 0.45, size.y * 0.45)
          ..lineTo(size.x * 0.32, size.y * 0.6)
          ..lineTo(size.x * 0.5, size.y),
        _crackPaint,
      );
    }
    if (object.isPlant && object.isThirsty) {
      _paint.color = const Color(0x559A7B43);
      canvas.drawRect(
          Rect.fromLTWH(0, size.y * 0.1, size.x, size.y * 0.25), _paint);
    }
  }

  // ------------------------------------------------------------------ Tippen

  @override
  void onTapUp(TapUpEvent event) {
    event.handled = true;

    if (object.broken && sim.repairObject(object.id)) {
      game.showTouch(object.cell, 'repariert');
      return;
    }
    if (object.isPlant) {
      final wasThirsty = object.isThirsty;
      sim.waterPlant(object.id);
      game.showTouch(object.cell, wasThirsty ? 'gegossen' : 'schon feucht');
      return;
    }
    if (object.kind == ObjectKind.pinboard) {
      game.openNoteComposer();
      return;
    }
    game.showObjectLabel(object);
  }

  // ------------------------------------------------------------------ Ziehen

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // Fest installiert oder gerade benutzt – gar nicht erst anfassen.
    if (!object.movable || object.isOccupied) return;
    event.handled = true;
    _dragging = true;
    priority = 40; // über allem anderen mitziehen
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_dragging) return;
    event.handled = true;
    position.add(event.localDelta);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _finishDrag();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _finishDrag();
  }

  void _finishDrag() {
    if (!_dragging) return;
    _dragging = false;
    priority = 20;

    final target = _candidateCell();
    if (target != null && sim.moveObject(object.id, target)) {
      game.showTouch(object.cell, '${object.kind.label} umgestellt');
    }
    // Gültig oder nicht: Die Position kommt aus dem Simulationszustand
    // zurück, es gibt keinen dritten Ort, an dem sie stehen könnte.
    _syncToGrid();
  }

  /// Zelle unter der aktuellen Zeichenposition.
  GridPos? _candidateCell() {
    final gx = (position.x / _tile).round();
    final gy = ((position.y + size.y) / _tile).round() - 1;
    if (gy < 0 || gy >= HouseGeometry.gridHeight) return null;
    return GridPos(gx, gy);
  }
}
