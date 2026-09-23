import 'dart:collection';

import '../model/grid.dart';
import 'walk_grid.dart';

/// A* auf dem [WalkGrid], 4er-Nachbarschaft.
///
/// Das Gitter ist klein (40×48) und dünn besetzt; ein simpler Binärheap reicht
/// vollkommen. Ergebnisse werden gecacht, weil viele Bewohner dieselben Wege
/// laufen (alle zur Treppe) und die Karte sich nur beim Möbelrücken ändert.
class Pathfinder {
  Pathfinder(this.grid);

  final WalkGrid grid;

  final Map<int, List<GridPos>> _cache = {};
  int _cacheEpoch = 0;

  /// Muss aufgerufen werden, wenn sich Begehbarkeit oder Kosten ändern.
  void invalidate() {
    _cache.clear();
    _cacheEpoch++;
  }

  int get epoch => _cacheEpoch;

  /// Weg von [start] nach [goal], **ohne** Startzelle, **mit** Zielzelle.
  /// `null`, wenn kein Weg existiert.
  List<GridPos>? findPath(GridPos start, GridPos goal, {bool useCache = true}) {
    if (start == goal) return const [];
    if (!grid.isWalkableAt(goal)) {
      final alt = grid.nearestWalkable(goal);
      if (alt == null) return null;
      goal = alt;
      if (start == goal) return const [];
    }
    if (!grid.isWalkableAt(start)) {
      final alt = grid.nearestWalkable(start);
      if (alt == null) return null;
      start = alt;
    }

    final key = _key(start, goal);
    if (useCache) {
      final hit = _cache[key];
      if (hit != null) return List<GridPos>.of(hit);
    }

    final result = _astar(start, goal);
    if (useCache && result != null) {
      _cache[key] = List<GridPos>.unmodifiable(result);
    }
    return result;
  }

  /// Die Wegkosten in Kostenpunkten (echtes A*).
  double travelCost(GridPos start, GridPos goal) {
    final path = findPath(start, goal);
    if (path == null) return double.infinity;
    var sum = 0.0;
    for (final p in path) {
      sum += grid.costAt(p.x, p.y);
    }
    return sum;
  }

  int _key(GridPos a, GridPos b) =>
      ((a.y * HouseGeometry.gridWidth + a.x) << 16) ^
      (b.y * HouseGeometry.gridWidth + b.x);

  List<GridPos>? _astar(GridPos start, GridPos goal) {
    const width = HouseGeometry.gridWidth;
    int id(GridPos p) => p.y * width + p.x;

    final open = _MinHeap();
    final gScore = HashMap<int, double>();
    final cameFrom = HashMap<int, GridPos>();
    final closed = HashSet<int>();

    gScore[id(start)] = 0;
    open.push(_Node(start, _heuristic(start, goal)));

    const dirs = [
      GridPos(1, 0),
      GridPos(-1, 0),
      GridPos(0, 1),
      GridPos(0, -1),
    ];

    while (!open.isEmpty) {
      final current = open.pop().pos;
      final cid = id(current);
      if (closed.contains(cid)) continue;
      closed.add(cid);

      if (current == goal) {
        return _reconstruct(cameFrom, current, start);
      }

      final baseG = gScore[cid]!;
      for (final d in dirs) {
        final nx = current.x + d.x;
        final ny = current.y + d.y;
        if (!grid.isWalkable(nx, ny)) continue;
        final neighbour = GridPos(nx, ny);
        final nid = id(neighbour);
        if (closed.contains(nid)) continue;

        final tentative = baseG + grid.costAt(nx, ny);
        final known = gScore[nid];
        if (known != null && tentative >= known) continue;

        gScore[nid] = tentative;
        cameFrom[nid] = current;
        open.push(_Node(neighbour, tentative + _heuristic(neighbour, goal)));
      }
    }
    return null;
  }

  /// Manhattan – zulässig, weil die minimalen Schrittkosten 1.0 betragen.
  double _heuristic(GridPos a, GridPos b) => a.manhattanTo(b).toDouble();

  List<GridPos> _reconstruct(
    Map<int, GridPos> cameFrom,
    GridPos current,
    GridPos start,
  ) {
    const width = HouseGeometry.gridWidth;
    final path = <GridPos>[current];
    var node = current;
    while (node != start) {
      final prev = cameFrom[node.y * width + node.x];
      if (prev == null) break;
      node = prev;
      if (node == start) break;
      path.add(node);
    }
    return path.reversed.toList();
  }
}

class _Node {
  _Node(this.pos, this.f);
  final GridPos pos;
  final double f;
}

/// Kleiner Binärheap – schlanker als eine allgemeine PriorityQueue und hier
/// der einzige heiße Pfad des Pathfindings.
class _MinHeap {
  final List<_Node> _items = [];

  bool get isEmpty => _items.isEmpty;

  void push(_Node n) {
    _items.add(n);
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_items[parent].f <= _items[i].f) break;
      final tmp = _items[parent];
      _items[parent] = _items[i];
      _items[i] = tmp;
      i = parent;
    }
  }

  _Node pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1;
        final r = l + 1;
        var smallest = i;
        if (l < _items.length && _items[l].f < _items[smallest].f) smallest = l;
        if (r < _items.length && _items[r].f < _items[smallest].f) smallest = r;
        if (smallest == i) break;
        final tmp = _items[smallest];
        _items[smallest] = _items[i];
        _items[i] = tmp;
        i = smallest;
      }
    }
    return top;
  }
}
