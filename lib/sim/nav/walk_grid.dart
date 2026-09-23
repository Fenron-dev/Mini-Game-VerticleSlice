import '../model/grid.dart';

/// Begehbarkeitskarte des Hauses.
///
/// Im Querschnitt ist begehbar: die **Bodenreihe jeder Ebene** (Wohnungen,
/// Keller, Dachterrasse) sowie die **Treppenspalten**, die alle Ebenen
/// vertikal verbinden. Das ist ein echtes 2D-Gitter – A* läuft unverändert
/// darüber – aber eines, das aussieht wie ein aufgeschnittenes Haus.
class WalkGrid {
  WalkGrid()
      : _walkable = List<bool>.filled(
          HouseGeometry.gridWidth * HouseGeometry.gridHeight,
          false,
        ),
        _cost = List<double>.filled(
          HouseGeometry.gridWidth * HouseGeometry.gridHeight,
          1.0,
        ) {
    _build();
  }

  final List<bool> _walkable;
  final List<double> _cost;

  /// Zusätzliche Kosten durch stehende Bewohner o. Ä. – weich, damit Wege sich
  /// entzerren, ohne dass jemand komplett blockiert.
  final Map<int, double> _softCost = {};

  int _idx(int x, int y) => y * HouseGeometry.gridWidth + x;

  void _build() {
    final topRow = HouseGeometry.floorRowOf(HouseGeometry.roofLevel);
    final bottomRow = HouseGeometry.floorRowOf(HouseGeometry.cellarLevel);

    // Bodenreihen aller Ebenen.
    for (var level = 0; level < HouseGeometry.levelCount; level++) {
      final row = HouseGeometry.floorRowOf(level);
      for (var x = HouseGeometry.interiorLeft;
          x <= HouseGeometry.stairRight;
          x++) {
        _walkable[_idx(x, row)] = true;
        _cost[_idx(x, row)] = 1.0;
      }
    }

    // Treppenschacht: durchgehend vertikal vom Dach bis in den Keller.
    for (var y = topRow; y <= bottomRow; y++) {
      for (var x = HouseGeometry.stairWalkLeft;
          x <= HouseGeometry.stairWalkRight;
          x++) {
        _walkable[_idx(x, y)] = true;
        // Treppensteigen ist mühsamer als Gehen – so bleiben Bewohner eher auf
        // ihrer Etage, ohne dass man das irgendwo hart verbieten müsste.
        final onFloorRow =
            HouseGeometry.floorRowOf(HouseGeometry.levelOfRow(y)) == y;
        _cost[_idx(x, y)] = onFloorRow ? 1.0 : 1.8;
      }
    }
  }

  bool inBounds(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x < HouseGeometry.gridWidth &&
      y < HouseGeometry.gridHeight;

  bool isWalkable(int x, int y) => inBounds(x, y) && _walkable[_idx(x, y)];
  bool isWalkableAt(GridPos p) => isWalkable(p.x, p.y);

  double costAt(int x, int y) =>
      _cost[_idx(x, y)] + (_softCost[_idx(x, y)] ?? 0.0);

  /// Belegung durch Bewohner vor einem Pathfinding-Durchgang setzen.
  void setSoftCost(Iterable<GridPos> occupied, {double penalty = 0.6}) {
    _softCost.clear();
    for (final p in occupied) {
      if (!inBounds(p.x, p.y)) continue;
      final i = _idx(p.x, p.y);
      _softCost[i] = (_softCost[i] ?? 0.0) + penalty;
    }
  }

  void clearSoftCost() => _softCost.clear();

  /// Nächstgelegene begehbare Zelle – Rettungsanker, wenn ein Ziel knapp neben
  /// einer begehbaren Zelle liegt.
  GridPos? nearestWalkable(GridPos from, {int maxRadius = 6}) {
    if (isWalkableAt(from)) return from;
    for (var r = 1; r <= maxRadius; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue;
          final p = GridPos(from.x + dx, from.y + dy);
          if (isWalkableAt(p)) return p;
        }
      }
    }
    return null;
  }
}
