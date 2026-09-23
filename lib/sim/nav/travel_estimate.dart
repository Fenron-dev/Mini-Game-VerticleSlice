import '../model/grid.dart';

/// Schnelle Wegkostenschätzung ohne A*.
///
/// Der Scorer vergleicht pro Entscheidung dutzende Kandidaten; ein vollständiges
/// A* je Kandidat wäre Verschwendung. Weil die Topologie feststeht (eine
/// Bodenreihe pro Ebene, ein Treppenschacht), ist diese geschlossene Formel
/// nicht nur schnell, sondern für gültige Ziele nahezu exakt – der echte Weg
/// wird erst für die tatsächlich gewählte Aktion berechnet.
double estimateTravelCost(GridPos from, GridPos to) {
  final levelA = HouseGeometry.levelOfRow(from.y);
  final levelB = HouseGeometry.levelOfRow(to.y);

  if (levelA == levelB) {
    return (from.x - to.x).abs().toDouble();
  }

  const stairX = HouseGeometry.stairWalkLeft;
  final horizontal = (from.x - stairX).abs() + (to.x - stairX).abs();
  // Treppentiles kosten 1.8 (siehe WalkGrid).
  final vertical = (from.y - to.y).abs() * 1.8;
  return horizontal + vertical;
}
