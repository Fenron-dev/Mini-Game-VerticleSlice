import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../sim/model/grid.dart';
import '../sim/model/interactable.dart';
import '../sim/model/resident.dart';
import '../sim/model/room.dart';
import '../sim/simulation.dart';
import 'components/atmosphere_component.dart';
import 'components/cat_component.dart';
import 'components/house_component.dart';
import 'components/object_component.dart';
import 'components/resident_component.dart';
import 'components/room_touch_component.dart';
import 'components/sky_component.dart';
import 'components/thought_bubble.dart';
import 'palette.dart';

/// Die Darstellungsschicht.
///
/// Sie **liest** die Simulation und leitet Eingaben an sie weiter – sie hält
/// keinen eigenen Spielzustand. Deshalb kann die Simulation in einem reinen
/// Dart-Test tagelang laufen, ohne dass hier irgendetwas existiert.
class VerticalSliceGame extends FlameGame {
  VerticalSliceGame({
    required this.sim,
    this.onOpenNoteComposer,
  }) : super(world: World());

  final HouseSimulation sim;

  /// Wird gerufen, wenn jemand die Pinnwand antippt – die Oberfläche zeigt
  /// dann den Notizzettel.
  final void Function()? onOpenNoteComposer;

  /// Wie stark der Fokusmodus gegenüber der Gesamtansicht heranholt.
  static const double focusZoomFactor = 2.9;

  /// Kehrwert der Zeitkonstante, mit der die Kamera ihr Ziel einholt.
  static const double cameraEase = 6.0;

  String? focusedRoomId;

  double _baseZoom = 1.0;
  double _targetZoom = 1.0;
  Vector2 _targetCenter = Vector2.zero();

  @override
  Color backgroundColor() =>
      Palette.sky(sim.world.clock.daylight, sim.world.clock.eveningWarmth);

  @override
  Future<void> onLoad() async {
    world.add(SkyComponent(sim.world));
    world.add(HouseComponent(sim.world));
    for (final room in sim.world.rooms) {
      world.add(RoomTouchComponent(room));
    }
    for (final object in sim.world.objects) {
      world.add(ObjectComponent(object, sim));
    }
    world.add(CatComponent(sim.world.cat));
    for (final resident in sim.world.residents) {
      world.add(ResidentComponent(resident, sim));
    }
    world.add(AtmosphereComponent(sim.world));

    camera.viewfinder.anchor = Anchor.center;
    _recomputeBaseZoom();
    _applyCameraTarget(instant: true);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _recomputeBaseZoom();
    _applyCameraTarget(instant: true);
  }

  void _recomputeBaseZoom() {
    if (size.x <= 0 || size.y <= 0) return;
    // Das ganze Haus soll hineinpassen, mit etwas Luft am Rand.
    _baseZoom = math.min(
          size.x / HouseGeometry.worldWidth,
          size.y / HouseGeometry.worldHeight,
        ) *
        0.94;
  }

  @override
  void update(double dt) {
    // Erst die Welt weiterdrehen, dann sie zeichnen lassen.
    sim.tickReal(dt);
    super.update(dt);
    _easeCamera(dt);
  }

  // -------------------------------------------------------------- Fokusmodus

  /// Doppeltipp auf einen Raum: hinein – oder wieder heraus, wenn er schon
  /// im Fokus ist. Kein zusätzlicher Knopf, kein Modus zum Merken.
  void toggleFocus(Room room) {
    focusedRoomId = focusedRoomId == room.id ? null : room.id;
    _applyCameraTarget();
  }

  void clearFocus() {
    if (focusedRoomId == null) return;
    focusedRoomId = null;
    _applyCameraTarget();
  }

  void _applyCameraTarget({bool instant = false}) {
    final room =
        focusedRoomId == null ? null : sim.world.roomById[focusedRoomId];

    if (room == null) {
      _targetZoom = _baseZoom;
      _targetCenter = Vector2(
        HouseGeometry.worldWidth / 2,
        HouseGeometry.worldHeight / 2,
      );
    } else {
      _targetZoom = _baseZoom * focusZoomFactor;
      final b = room.bounds;
      _targetCenter = Vector2(
        (b.left + b.width / 2) * HouseGeometry.tileSize,
        (b.top + b.height / 2) * HouseGeometry.tileSize,
      );
    }
    _targetCenter = _clampToHouse(_targetCenter, _targetZoom);

    if (instant) {
      camera.viewfinder
        ..zoom = _targetZoom
        ..position = _targetCenter;
    }
  }

  /// Hält die Kamera innerhalb des Hauses – sonst schaut der Fokusmodus an den
  /// Rändern ins Leere.
  Vector2 _clampToHouse(Vector2 center, double zoom) {
    if (zoom <= 0 || size.x <= 0) return center;
    final halfW = size.x / (2 * zoom);
    final halfH = size.y / (2 * zoom);

    double axis(double value, double half, double extent) {
      if (half * 2 >= extent) return extent / 2;
      return value.clamp(half, extent - half);
    }

    return Vector2(
      axis(center.x, halfW, HouseGeometry.worldWidth),
      axis(center.y, halfH, HouseGeometry.worldHeight),
    );
  }

  void _easeCamera(double dt) {
    final viewfinder = camera.viewfinder;
    // Exponentielle Annäherung: bildratenunabhängig und ohne Überschwingen.
    final t = 1 - math.exp(-cameraEase * dt);

    final zoom = viewfinder.zoom + (_targetZoom - viewfinder.zoom) * t;
    viewfinder.zoom = zoom;

    // Die Begrenzung hängt am aktuellen Zoom, nicht am Ziel – sonst ruckt es
    // während des Hineinfahrens gegen den Rand.
    final clamped = _clampToHouse(_targetCenter, zoom);
    viewfinder.position += (clamped - viewfinder.position) * t;
  }

  // ------------------------------------------------------------ Rückmeldungen

  void showThought(Resident resident, String text) {
    if (text.isEmpty) return;
    _clearBubbles();
    world.add(ThoughtBubble(resident: resident, text: text));
  }

  /// Kurze Bestätigung an einem Ort – "gegossen", "repariert", "umgestellt".
  void showTouch(GridPos cell, String text) {
    _clearBubbles();
    world.add(ThoughtBubble(anchorCell: cell, text: text, lifetime: 2.6));
  }

  void showObjectLabel(InteractableObject object) {
    final room = sim.world.roomById[object.roomId];
    final where = room == null ? '' : ' · ${room.name}';
    showTouch(object.cell, '${object.kind.label}$where');
  }

  void openNoteComposer() => onOpenNoteComposer?.call();

  /// Immer nur eine Blase: Zwei gleichzeitig lesen sich wie ein Streit.
  void _clearBubbles() {
    for (final bubble in world.children.whereType<ThoughtBubble>().toList()) {
      bubble.removeFromParent();
    }
  }
}
