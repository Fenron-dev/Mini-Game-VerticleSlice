import 'dart:math' as math;

/// Ganzzahlige Gitterkoordinate. Ursprung oben links, y wächst nach unten.
class GridPos {
  const GridPos(this.x, this.y);

  final int x;
  final int y;

  GridPos copyWith({int? x, int? y}) => GridPos(x ?? this.x, y ?? this.y);

  int manhattanTo(GridPos other) =>
      (x - other.x).abs() + (y - other.y).abs();

  double distanceTo(GridPos other) {
    final dx = (x - other.x).toDouble();
    final dy = (y - other.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.x == x && other.y == y;

  @override
  int get hashCode => x * 73856093 ^ y * 19349663;

  @override
  String toString() => '($x,$y)';

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  static GridPos fromJson(Map<String, dynamic> j) =>
      GridPos(j['x'] as int, j['y'] as int);
}

/// Achsenparalleles Rechteck in Gitterkoordinaten; alle Kanten **inklusiv**
/// (Tiles, nicht Kanten).
class GridRect {
  const GridRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;
  int get height => bottom - top + 1;

  bool contains(GridPos p) =>
      p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;

  GridPos get center => GridPos((left + right) ~/ 2, (top + bottom) ~/ 2);

  Iterable<GridPos> get cells sync* {
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        yield GridPos(x, y);
      }
    }
  }

  @override
  String toString() => 'GridRect($left,$top → $right,$bottom)';
}

/// Maße des Hausquerschnitts. Ein Tile entspricht [tileSize] Weltpixeln.
///
/// Der Querschnitt ist eine Seitenansicht: Bewohner laufen pro Etage auf
/// **einer** Bodenreihe, das Treppenhaus verbindet die Etagen vertikal. Das
/// Gitter bleibt ein echtes 2D-Gitter (A* läuft darüber), ist aber dünn besetzt
/// – genau so, wie ein aufgeschnittenes Haus eben aussieht.
class HouseGeometry {
  const HouseGeometry();

  static const double tileSize = 16.0;

  /// Spalten: 0 = Außenwand links, 39 = Außenwand rechts.
  ///
  /// Die Breite ist bewusst großzügig: Räume sollen **Lücken** haben. Ein Haus,
  /// in dem jedes Tile möbliert ist, sieht nicht nur eng aus – es macht auch
  /// das Umstellen per Drag unmöglich, weil es keinen freien Platz gibt.
  static const int gridWidth = 40;

  /// 6 Ebenen à [levelHeight] Reihen: Keller, 4 Etagen, Dach.
  static const int levelCount = 6;
  static const int levelHeight = 8;
  static const int gridHeight = levelCount * levelHeight; // 48

  /// Innenraum der Wohnungen.
  static const int interiorLeft = 1;
  static const int interiorRight = 34;

  /// Treppenhaus / Flur.
  static const int stairLeft = 35;
  static const int stairRight = 38;

  /// Die beiden tatsächlich begehbaren Treppenspalten.
  static const int stairWalkLeft = 36;
  static const int stairWalkRight = 37;

  /// Ebenenindizes von unten nach oben: 0 = Keller … 5 = Dach.
  static const int cellarLevel = 0;
  static const int roofLevel = 5;
  static const List<int> apartmentLevels = [1, 2, 3, 4];

  /// Oberste Gitterreihe einer Ebene.
  static int topRowOf(int level) => (roofLevel - level) * levelHeight;

  /// Bodenreihe einer Ebene – hier stehen Bewohner und Möbel.
  static int floorRowOf(int level) => topRowOf(level) + levelHeight - 1;

  /// Ebene, zu der eine Gitterreihe gehört.
  static int levelOfRow(int row) => roofLevel - (row ~/ levelHeight);

  static bool isStairColumn(int x) => x >= stairWalkLeft && x <= stairWalkRight;

  static double get worldWidth => gridWidth * tileSize;
  static double get worldHeight => gridHeight * tileSize;
}
