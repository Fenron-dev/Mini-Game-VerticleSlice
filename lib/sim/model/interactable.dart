import 'affordance.dart';
import 'grid.dart';

enum ObjectKind {
  bed('Bett'),
  sofa('Sofa'),
  armchair('Sessel'),
  table('Tisch'),
  stove('Herd'),
  fridge('Kühlschrank'),
  sink('Spüle'),
  shower('Dusche'),
  toilet('WC'),
  desk('Schreibtisch'),
  bookshelf('Bücherregal'),
  radio('Radio'),
  plant('Zimmerpflanze'),
  washer('Waschmaschine'),
  pinboard('Pinnwand'),
  bench('Bank'),
  catBowl('Katzennapf'),
  boiler('Heizkessel'),
  lamp('Lampe');

  const ObjectKind(this.label);
  final String label;
}

/// Alles, womit ein Bewohner interagieren kann.
///
/// Zustand (kaputt, besetzt, durstig) lebt hier; die *Angebote* kommen aus dem
/// AffordanceCatalog und sind pro Art geteilt und unveränderlich.
class InteractableObject {
  InteractableObject({
    required this.id,
    required this.kind,
    required this.roomId,
    required GridPos cell,
    required this.affordances,
    this.movable = true,
    this.width = 2,
    this.condition = 1.0,
    this.moisture = 1.0,
    this.broken = false,
  }) : _cell = cell;

  final String id;
  final ObjectKind kind;

  /// Aktueller Raum – ändert sich beim Umstellen per Drag.
  String roomId;

  GridPos _cell;
  GridPos get cell => _cell;

  /// Breite in Tiles (Seitenansicht).
  final int width;

  /// Möbel lassen sich verschieben, Installationen (Dusche, WC, Kessel) nicht.
  final bool movable;

  final List<Affordance> affordances;

  /// 1.0 = neuwertig, 0.0 = am Ende. Treibt die Ausfallwahrscheinlichkeit.
  double condition;

  /// Nur für Pflanzen: 1.0 = frisch gegossen.
  double moisture;

  bool broken;

  /// `null` = frei, sonst die Bewohner-ID.
  String? occupantId;

  /// Sim-Zeitstempel (Sekunden), bis zu dem das Objekt gesperrt ist.
  double cooldownUntil = 0.0;

  bool get isOccupied => occupantId != null;
  bool get isPlant => kind == ObjectKind.plant;
  bool get isThirsty => isPlant && moisture < 0.45;

  /// Standposition des Bewohners: linke Kante des Objekts, auf der Bodenreihe.
  GridPos get useCell => GridPos(_cell.x, _cell.y);

  GridRect get footprint =>
      GridRect(_cell.x, _cell.y, _cell.x + width - 1, _cell.y);

  bool available(double simSeconds, {String? forResident}) {
    if (cooldownUntil > simSeconds) return false;
    if (occupantId != null && occupantId != forResident) return false;
    return true;
  }

  /// Kann [a] gerade genutzt werden? Prüft Zustandsbedingungen, nicht Nutzen.
  bool supports(Affordance a, double simSeconds, {String? forResident}) {
    if (!available(simSeconds, forResident: forResident)) return false;
    if (a.requiresWorking && broken) return false;
    if (a.requiresBroken && !broken) return false;
    if (a.requiresThirstyPlant && !isThirsty) return false;
    return true;
  }

  void moveTo(GridPos target, String newRoomId) {
    _cell = target;
    roomId = newRoomId;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'roomId': roomId,
        'cell': _cell.toJson(),
        'condition': condition,
        'moisture': moisture,
        'broken': broken,
        'occupantId': occupantId,
        'cooldownUntil': cooldownUntil,
      };

  /// Rekonstruiert den *Zustand*; Art, Breite und Angebote kommen aus dem
  /// Katalog, damit gespeicherte Stände nach einem Balancing-Update die neuen
  /// Werte bekommen statt eingefrorener alter.
  void applyJson(Map<String, dynamic> j) {
    roomId = j['roomId'] as String;
    _cell = GridPos.fromJson(Map<String, dynamic>.from(j['cell'] as Map));
    condition = (j['condition'] as num).toDouble();
    moisture = (j['moisture'] as num).toDouble();
    broken = j['broken'] as bool;
    occupantId = j['occupantId'] as String?;
    cooldownUntil = (j['cooldownUntil'] as num).toDouble();
  }

  @override
  String toString() => 'Object($id ${kind.name} @$_cell)';
}
