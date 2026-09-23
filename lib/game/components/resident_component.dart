import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../../sim/ai/activity.dart';
import '../../sim/model/affordance.dart';
import '../../sim/model/grid.dart';
import '../../sim/model/resident.dart';
import '../../sim/simulation.dart';
import '../palette.dart';
import '../vertical_slice_game.dart';

/// Ein Bewohner als Farbfläche.
///
/// Die Haltung folgt der laufenden Handlung: Wer schläft, liegt; wer liest,
/// sitzt. Mehr Animation braucht es für den vertikalen Schnitt nicht – die
/// Silhouette allein sagt schon, was gerade los ist.
class ResidentComponent extends PositionComponent
    with TapCallbacks, HasGameReference<VerticalSliceGame> {
  ResidentComponent(this.resident, this.sim) : super(priority: 30);

  final Resident resident;
  final HouseSimulation sim;

  static const double _tile = HouseGeometry.tileSize;
  static const double _standWidth = _tile * 0.72;
  static const double _standHeight = _tile * 1.7;

  final Paint _paint = Paint()..isAntiAlias = true;

  /// Sanfter Schrittversatz, damit Laufen nicht wie Gleiten aussieht.
  double _bob = 0;

  Posture get _posture {
    final activity = resident.activity;
    if (activity == null || activity.phase != ActivityPhase.performing) {
      return Posture.stand;
    }
    return activity.affordance.posture;
  }

  @override
  void update(double dt) {
    final posture = _posture;
    final w = switch (posture) {
      Posture.lie => _tile * 1.9,
      Posture.crouch => _standWidth * 1.15,
      _ => _standWidth,
    };
    final h = switch (posture) {
      Posture.lie => _tile * 0.62,
      Posture.sit => _standHeight * 0.68,
      Posture.crouch => _standHeight * 0.55,
      _ => _standHeight,
    };
    size = Vector2(w, h);

    final moving = resident.activity?.isTraveling ?? false;
    _bob = moving ? _bob + dt * 9 : 0;
    // Dreieckskurve statt Sinus: wirkt eckiger und passt zur Klötzchenoptik.
    final phase = _bob % 2.0;
    final bobOffset = moving ? (phase < 1.0 ? phase : 2.0 - phase) * -1.1 : 0.0;

    // Auf der Bodenreihe stehend, mittig auf der Zelle.
    position = Vector2(
      resident.x * _tile + (_tile - w) / 2,
      (resident.y + 1) * _tile - h + bobOffset,
    );
  }

  @override
  void render(Canvas canvas) {
    final asleep = resident.isAsleep;
    _paint.color =
        Palette.resident(resident.hue, lightness: asleep ? 0.44 : 0.62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(_tile * 0.22),
      ),
      _paint,
    );

    // Kopf: eine hellere Kappe am oberen Ende, in Blickrichtung versetzt.
    if (_posture != Posture.lie) {
      _paint.color = Palette.resident(resident.hue, lightness: 0.76);
      final headSize = size.x * 0.78;
      canvas.drawOval(
        Rect.fromLTWH(
          (size.x - headSize) / 2 + resident.facing * size.x * 0.06,
          -headSize * 0.35,
          headSize,
          headSize,
        ),
        _paint,
      );
    }

    if (asleep) {
      _paint.color = const Color(0x99E8ECF5);
      for (var i = 0; i < 3; i++) {
        final s = 2.2 - i * 0.5;
        canvas.drawRect(
          Rect.fromLTWH(size.x + 2 + i * 3.0, -4.0 - i * 3.5, s, s),
          _paint,
        );
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    // Etwas großzügiger als die Silhouette – Finger sind keine Mauszeiger.
    const pad = 6.0;
    return point.x >= -pad &&
        point.y >= -pad &&
        point.x <= size.x + pad &&
        point.y <= size.y + pad;
  }

  @override
  void onTapUp(TapUpEvent event) {
    event.handled = true;
    game.showThought(resident, sim.thoughtFor(resident.id));
  }
}
