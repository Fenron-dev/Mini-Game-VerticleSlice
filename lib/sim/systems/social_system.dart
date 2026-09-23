import 'dart:math' as math;

import '../house_world.dart';
import '../model/interactable.dart';
import '../model/need.dart';
import '../model/note.dart';
import '../model/resident.dart';

/// Nähe, Beziehungen und Nachbarschaftsnotizen.
///
/// Sozialkontakt entsteht hier nicht als Aktion, sondern als **Nebenprodukt von
/// Gleichzeitigkeit**: Zwei Menschen im selben Raum tun einander gut, auch wenn
/// beide gerade etwas anderes machen.
class SocialSystem {
  const SocialSystem();

  static const double proximityRadius = 3.0;
  static const double socialGainPerHour = 0.30;
  static const double bondGainPerHour = 0.02;

  /// Wie nah beide an der Pinnwand sein müssen, damit eine Notiz aufgeht.
  static const double meetRadius = 3.5;

  void update(HouseWorld world, double dtSim) {
    final hours = dtSim / 3600.0;
    _proximity(world, hours);
    _notes(world);
  }

  void _proximity(HouseWorld world, double hours) {
    final residents = world.residents;
    for (var i = 0; i < residents.length; i++) {
      final a = residents[i];
      if (a.isAsleep) continue;
      for (var j = i + 1; j < residents.length; j++) {
        final b = residents[j];
        if (b.isAsleep) continue;

        final dx = a.x - b.x;
        final dy = a.y - b.y;
        if (math.sqrt(dx * dx + dy * dy) > proximityRadius) continue;

        // Wer sich mag, hat mehr davon; wer sich nicht mag, ein bisschen weniger.
        final warmth = 0.6 + 0.4 * a.relationTo(b.id).clamp(-1.0, 1.0);
        final gain = socialGainPerHour * hours * warmth;

        a.needs[NeedType.social] = a.needs[NeedType.social] + gain;
        b.needs[NeedType.social] = b.needs[NeedType.social] + gain;

        a.nudgeRelation(b.id, bondGainPerHour * hours);
        b.nudgeRelation(a.id, bondGainPerHour * hours);
      }
    }
  }

  void _notes(HouseWorld world) {
    final now = world.clock.simSeconds;
    InteractableObject? pinboard;
    for (final o in world.objectsOfKind(ObjectKind.pinboard)) {
      pinboard = o;
      break;
    }

    // Zuerst alle Wünsche zurücksetzen; aktive Notizen setzen sie neu.
    for (final r in world.residents) {
      r.pendingMeetWith = null;
      r.meetUrgency = 0.0;
    }

    for (final note in world.notes) {
      if (!note.isActive(now)) continue;

      final a = world.residentById[note.residentA];
      final b = world.residentById[note.residentB];
      if (a == null || b == null) continue;

      // Der Wunsch wächst über die Laufzeit der Notiz an – sanft, nie zwingend.
      final age =
          (now - note.postedAtSim) / (note.expiresAtSim - note.postedAtSim);
      final urgency = 0.18 + 0.45 * age.clamp(0.0, 1.0);

      a.pendingMeetWith = b.id;
      b.pendingMeetWith = a.id;
      a.meetUrgency = urgency;
      b.meetUrgency = urgency;

      if (pinboard == null) continue;
      if (_nearPinboard(a, pinboard) && _nearPinboard(b, pinboard)) {
        _fulfill(world, note, a, b);
      }
    }

    world.notes.removeWhere(
      (n) => n.fulfilled && now - n.postedAtSim > 6 * 3600,
    );
  }

  bool _nearPinboard(Resident r, InteractableObject pinboard) {
    if (r.isAsleep) return false;
    final dx = r.x - pinboard.useCell.x;
    final dy = r.y - pinboard.useCell.y;
    return math.sqrt(dx * dx + dy * dy) <= meetRadius;
  }

  void _fulfill(
    HouseWorld world,
    NeighborhoodNote note,
    Resident a,
    Resident b,
  ) {
    note.fulfilled = true;
    for (final r in [a, b]) {
      r.needs[NeedType.social] = r.needs[NeedType.social] + 0.35;
      r.needs[NeedType.contentment] = r.needs[NeedType.contentment] + 0.25;
      r.pendingMeetWith = null;
      r.meetUrgency = 0.0;
    }
    a.nudgeRelation(b.id, 0.22);
    b.nudgeRelation(a.id, 0.22);
    world.log(
      '${a.name} und ${b.name} stehen im Flur und kommen ins Reden.',
      residentId: a.id,
    );
  }
}
