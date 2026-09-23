import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_slice/sim/model/grid.dart';
import 'package:vertical_slice/sim/nav/pathfinder.dart';
import 'package:vertical_slice/sim/nav/travel_estimate.dart';
import 'package:vertical_slice/sim/nav/walk_grid.dart';

void main() {
  late WalkGrid grid;
  late Pathfinder pathfinder;

  setUp(() {
    grid = WalkGrid();
    pathfinder = Pathfinder(grid);
  });

  group('WalkGrid', () {
    test('Bodenreihen aller Ebenen sind begehbar', () {
      for (var level = 0; level < HouseGeometry.levelCount; level++) {
        final row = HouseGeometry.floorRowOf(level);
        expect(grid.isWalkable(HouseGeometry.interiorLeft, row), isTrue,
            reason: 'Ebene $level linke Kante');
        expect(grid.isWalkable(HouseGeometry.stairRight, row), isTrue,
            reason: 'Ebene $level Flur');
      }
    });

    test('Außenwände sind nicht begehbar', () {
      final row = HouseGeometry.floorRowOf(2);
      expect(grid.isWalkable(0, row), isFalse);
      expect(grid.isWalkable(HouseGeometry.gridWidth - 1, row), isFalse);
    });

    test('Der Treppenschacht ist durchgehend', () {
      final top = HouseGeometry.floorRowOf(HouseGeometry.roofLevel);
      final bottom = HouseGeometry.floorRowOf(HouseGeometry.cellarLevel);
      for (var y = top; y <= bottom; y++) {
        expect(grid.isWalkable(HouseGeometry.stairWalkLeft, y), isTrue,
            reason: 'Reihe $y');
      }
    });

    test('Zimmerluft über dem Boden ist nicht begehbar', () {
      expect(grid.isWalkable(5, HouseGeometry.floorRowOf(3) - 2), isFalse);
    });
  });

  group('Pathfinder', () {
    test('findet einen Weg innerhalb einer Etage', () {
      final row = HouseGeometry.floorRowOf(2);
      final path = pathfinder.findPath(GridPos(2, row), GridPos(20, row));
      expect(path, isNotNull);
      expect(path!.last, GridPos(20, row));
      expect(path.length, 18);
    });

    test('findet einen Weg über mehrere Etagen durchs Treppenhaus', () {
      final from = GridPos(3, HouseGeometry.floorRowOf(1));
      final to = GridPos(4, HouseGeometry.floorRowOf(4));
      final path = pathfinder.findPath(from, to);

      expect(path, isNotNull);
      expect(path!.last, to);
      expect(path.any((p) => HouseGeometry.isStairColumn(p.x)), isTrue,
          reason: 'Weg muss durchs Treppenhaus führen');
    });

    test('Keller und Dach sind miteinander verbunden', () {
      final cellar = GridPos(4, HouseGeometry.floorRowOf(0));
      final roof = GridPos(6, HouseGeometry.floorRowOf(5));
      expect(pathfinder.findPath(cellar, roof), isNotNull);
    });

    test('jeder Schritt im Weg ist begehbar und benachbart', () {
      final from = GridPos(2, HouseGeometry.floorRowOf(0));
      final to = GridPos(24, HouseGeometry.floorRowOf(5));
      final path = pathfinder.findPath(from, to)!;

      var previous = from;
      for (final step in path) {
        expect(grid.isWalkableAt(step), isTrue, reason: '$step begehbar');
        expect(previous.manhattanTo(step), 1, reason: '$previous → $step');
        previous = step;
      }
    });

    test('gleicher Start und gleiches Ziel ergibt einen leeren Weg', () {
      final p = GridPos(5, HouseGeometry.floorRowOf(2));
      expect(pathfinder.findPath(p, p), isEmpty);
    });

    test('Ziel in der Wand rastet auf die nächste begehbare Zelle ein', () {
      final path = pathfinder.findPath(
        GridPos(5, HouseGeometry.floorRowOf(2)),
        GridPos(5, HouseGeometry.floorRowOf(2) - 3),
      );
      expect(path, isNotNull);
    });
  });

  group('estimateTravelCost', () {
    test('entspricht auf einer Etage den echten Wegkosten', () {
      final row = HouseGeometry.floorRowOf(2);
      final from = GridPos(2, row);
      final to = GridPos(20, row);
      expect(
        estimateTravelCost(from, to),
        closeTo(pathfinder.travelCost(from, to), 1e-9),
      );
    });

    test('schätzt Etagenwechsel in derselben Größenordnung wie A*', () {
      final from = GridPos(3, HouseGeometry.floorRowOf(1));
      final to = GridPos(6, HouseGeometry.floorRowOf(4));
      final estimate = estimateTravelCost(from, to);
      final actual = pathfinder.travelCost(from, to);
      expect(estimate, closeTo(actual, actual * 0.15));
    });
  });
}
