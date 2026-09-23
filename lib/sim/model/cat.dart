import 'grid.dart';

enum CatMood { wander, doze, watch, beg }

/// Die Hauskatze. Kein Bedürfnissystem, nur ein weicher Zufallsspaziergang –
/// sie ist Stimmung, kein Agent mit Zielen.
class Cat {
  Cat({
    required this.name,
    required GridPos start,
    required this.hue,
  })  : x = start.x.toDouble(),
        y = start.y.toDouble();

  final String name;
  final double hue;

  double x;
  double y;
  int facing = 1;

  CatMood mood = CatMood.wander;

  /// Restweg; wird vom CatSystem neu gesetzt, wenn er leer läuft.
  List<GridPos> path = [];

  /// Sim-Sekunden, bis die Katze etwas Neues tut.
  double stateTimer = 0;

  GridPos get cell => GridPos(x.round(), y.round());
  int get level => HouseGeometry.levelOfRow(y.round());

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'facing': facing,
        'mood': mood.name,
        'path': path.map((p) => p.toJson()).toList(),
        'stateTimer': stateTimer,
      };

  void applyJson(Map<String, dynamic> j) {
    x = (j['x'] as num).toDouble();
    y = (j['y'] as num).toDouble();
    facing = j['facing'] as int? ?? 1;
    mood = CatMood.values.byName(j['mood'] as String? ?? 'wander');
    path = (j['path'] as List?)
            ?.map((e) => GridPos.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    stateTimer = (j['stateTimer'] as num?)?.toDouble() ?? 0;
  }
}
