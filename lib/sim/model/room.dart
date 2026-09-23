import 'grid.dart';

enum RoomKind {
  bedroom('Schlafzimmer'),
  kitchen('Küche'),
  living('Wohnzimmer'),
  bath('Bad'),
  hall('Treppenhaus'),
  roof('Dachterrasse'),
  cellar('Keller');

  const RoomKind(this.label);
  final String label;
}

/// Ein Raum im Querschnitt. Räume sind reine Geometrie + Zugehörigkeit;
/// alles Verhalten hängt an den Objekten darin.
class Room {
  Room({
    required this.id,
    required this.name,
    required this.kind,
    required this.bounds,
    required this.level,
    this.apartmentId,
    this.windowColumns = const [],
  });

  final String id;
  final String name;
  final RoomKind kind;
  final GridRect bounds;
  final int level;

  /// `null` für Gemeinschaftsflächen (Flur, Dach, Keller). Für Wohnräume ist
  /// sie Pflicht: Daran hängt, dass niemand ungefragt in einer fremden Wohnung
  /// landet.
  final String? apartmentId;

  /// Gitterspalten mit Fenster – dort leuchtet es abends bzw. läuft Regen.
  final List<int> windowColumns;

  /// Bodenreihe, auf der in diesem Raum gelaufen wird.
  int get floorRow => HouseGeometry.floorRowOf(level);

  bool get isCommunal => apartmentId == null;

  bool containsColumn(int x) => x >= bounds.left && x <= bounds.right;

  GridPos get anchor => GridPos(bounds.center.x, floorRow);

  @override
  String toString() => 'Room($id "$name")';
}

/// Eine Wohnung fasst die Räume einer Etage und ihre Bewohner zusammen.
class Apartment {
  Apartment({
    required this.id,
    required this.label,
    required this.level,
    required this.roomIds,
    required this.residentIds,
  });

  final String id;
  final String label;
  final int level;
  final List<String> roomIds;
  final List<String> residentIds;
}
