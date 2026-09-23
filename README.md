# Vertical Slice

*Ein Haus im Querschnitt.* Vier Etagen Mietshaus, Wände weggeschnitten, dazu
Dach und Keller. Sechs Bewohner leben ihren Tag – aufstehen, Kaffee, Arbeit,
Pflanze gießen. Du bist der wohlwollende Hausgeist.

Kein Geld, keine Karriere, keine Punkte. Nur Leben, das passiert.

Flutter + Flame, für Android und iPad. Offline, ohne Konto, ohne Netzwerk.
Alle Assets sind zunächst prozedurale Farbflächen.

---

## Builds – nur über GitHub

Es wird **nichts lokal gebaut**. Jeder Push löst `.github/workflows/build.yml`
aus:

| Job | Läuft auf | Ergebnis |
| --- | --- | --- |
| Analyse und Tests | Ubuntu | `flutter analyze`, `flutter test` |
| Android-APK | Ubuntu | Artefakt `vertical-slice-android` (Release-APK) |

Die fertigen Dateien liegen im jeweiligen Lauf unter **Actions → Lauf →
Artifacts** und werden nach 14 Tagen gelöscht. Einen Lauf von Hand startest du
über **Actions → Build → Run workflow**.

Der Ordner `android/` ist absichtlich nicht im Repo; die Pipeline erzeugt ihn
mit `flutter create`. Das hält das Repo klein und frei von generiertem Code.

**iOS ist vorerst ausgesetzt**, weil es einen macOS-Runner braucht. Für später
liegt unter `ci/ios/Podfile` bereits ein Podfile mit dem nötigen Mindestziel
iOS 14 (die Audio-Bibliothek verlangt mehr als Flutters Vorgabe 12.0).

---

## Architektur

Drei Schichten, strikt in eine Richtung gekoppelt:

```
  ui/            Flutter-Overlays: Uhr, Zeitraffer, Notizzettel
      │  liest, ruft Absichten auf
      ▼
  game/          Flame: zeichnet, nimmt Eingaben entgegen
      │  liest, ruft Absichten auf
      ▼
  sim/           Reines Dart: Zustand, Regeln, Tick-Loop
```

**Die Simulation kennt weder Flutter-Widgets noch Flame.** Sie lässt sich in
einem gewöhnlichen Test tagelang laufen – genau das tun die Tests auch. Die
Darstellung hält keinen eigenen Spielzustand; sie liest jeden Frame ab und
schickt Eingaben als Absichten zurück (`waterPlant`, `moveObject`, `postNote`).

```
lib/
  core/sim_clock.dart          Uhr, Zeitraffer, Tageslicht
  sim/
    model/                     Datenmodelle (siehe unten)
    ai/action_scorer.dart      Utility-Bewertung – das Herz
    ai/activity.dart           laufende Handlung
    nav/                       Begehbarkeit, A*, O(1)-Wegschätzung
    systems/                   sieben Systeme, feste Reihenfolge
    house_world.dart           der gesamte Zustand
    building_factory.dart      die Ausgangsaufstellung
    simulation.dart            Tick-Loop und sanfte Eingriffe
    thought_writer.dart        Gedankenblasen
  persistence/                 Spielstand + Nachberechnung
  game/                        Flame-Komponenten, Palette
  ui/                          HUD, Notizzettel, Bildschirm
  audio/                       optionaler Lo-Fi-Loop
```

---

## Datenmodelle

### `NeedSet` – fünf Bedürfnisse

`energy`, `hunger`, `hygiene`, `social`, `contentment`.

Konvention: **alle Werte laufen 0 (dringend) bis 1 (gestillt)** – auch Hunger,
wo 1 „satt“ heißt. Dringlichkeit ist damit immer eine Funktion von `1 - wert`.
Die Antwortkurve ist konvex, mit Notfallzuschlag unter 0.18: Ein halb volles
Bedürfnis ist entspannt, ein fast leeres überstimmt jede Gemütlichkeit.

Zufriedenheit verfällt kaum von selbst – sie *driftet* zum Mittelwert der
übrigen Bedürfnisse und lässt sich deshalb nicht direkt farmen.

### `Trait` / `TraitProfile` – Charakter

Zehn Eigenschaften, je Bewohner drei: Frühaufsteher, Nachteule, Ordnungsliebe,
Geselligkeit, Zurückgezogen, Grüner Daumen, Handwerklich, Genießer, Rastlos,
Stubenhocker.

Traits sind **rein deklarativ** – Multiplikatoren auf Bedürfnisgewichte,
Verfallsraten, Tag-Affinitäten, Trägheit, Abwechslungsdrang, Wegkosten und den
Tagesrhythmus. Nirgends steht `if (trait == earlyBird)`.

### `InteractableObject` + `Affordance`

Ein Objekt hält *Zustand* (Ort, Abnutzung, kaputt, Feuchtigkeit, Belegung,
Sperrzeit). Die *Angebote* kommen aus dem `AffordanceCatalog` – „Bett:
+Energie“ als reine Daten: Raten pro Sim-Stunde, Dauer, Tags, exklusiv,
Bedingungen, Tageszeitfenster, Abklingzeit, Verschleiß. Neues Verhalten
entsteht dort als Daten, nicht als Code.

### `Room`, `Apartment`, `HouseGeometry`

40 × 48 Tiles: Keller, vier Wohnetagen, Dachterrasse, Treppenhaus rechts. Jede
Wohnung hat Schlafzimmer, Küche, Wohnzimmer und Bad; Flur, Dach und Keller sind
gemeinschaftlich. `Room.apartmentId` entscheidet, wer wohin darf.

### `Resident`

Hält Zustand, keine Entscheidungslogik: Bedürfnisse, Traits, Position,
laufende Aktivität, Beziehungen, Kurzzeitgedächtnis, offener Treffwunsch.

### `ActionScorer` – die Entscheidung

Ein Bewohner plant nicht. Er bewertet in jedem Entscheidungsmoment alles, was
das Haus anbietet, und nimmt das Beste:

| Anteil | Wirkung |
| --- | --- |
| Bedürfnisnutzen | erwarteter Gewinn × Dringlichkeit × Trait-Gewicht, gedeckelt auf das Fehlende, geteilt durch die Zeitkosten |
| Weg | wurzelförmig – kurze Wege bleiben unterscheidbar, weite sind eine Hürde, keine Mauer |
| Gesellschaft | Anwesende in Reichweite, skaliert mit dem eigenen Bedarf an Nähe |
| Notiz | offene Nachbarschaftsnotiz |
| Objektzustand | durstige Pflanzen und Defekte rufen von sich aus |
| Tageszeit | die richtige Stunde zieht stark, die falsche stößt nur sanft ab – außer beim Schlaf |
| Charakter, Abwechslung, Trägheit | Vorlieben |
| Privatsphäre | fremde Wohnungen sind zu, außer man ist eingeladen |

Entscheidend ist die Trennung zwischen **Anlass** und **Vorliebe**: Nur
Bedürfnisgewinn, Notiz, Objektzustand und Gesellschaft begründen eine Handlung.
Vorlieben werden mit dieser Relevanz skaliert – sie dürfen umsortieren, aber
keinen Grund erfinden.

---

## Tick-Loop

```dart
void _step(double dt) {
  clock.advanceSim(dt);
  objectSystem.update(world, dt);      // Pflanzen trocknen, Geräte verschleißen
  needsSystem.update(world, dt);       // Bedürfnisse verfallen
  decisionSystem.update(world, dt);    // wer nichts tut, überlegt
  executionSystem.update(world, dt);   // laufen, dann tun
  socialSystem.update(world, dt);      // Nähe, Beziehungen, Notizen
  catSystem.update(world, dt);         // Nebel zieht durchs Haus
  atmosphereSystem.update(world, dt);  // Wetter und Licht
}
```

Feste Schrittweite von 1/30 Sim-Sekunde, entkoppelt von der Bildrate; bei 16×
werden acht kleine Schritte pro Bild gerechnet statt eines großen.
Entscheidungen sind selten und billig – nur wenn eine Aktivität endet oder ein
Bedürfnis kritisch wird, läuft das Scoring.

**Zeitkopplung:** Bei 1× läuft die Sim-Zeit mit der Wanduhr; beim ersten Start
wird sie auf die lokale Uhrzeit gestellt. Zeitraffer (1×/4×/16×) lässt sie
vorlaufen; sie springt nie zurück.

**Nachberechnung:** Dieselbe Schleife rechnet die Pause nach – mit einer
Sim-Minute Schrittweite, ohne Darstellung, offline immer 1×, gedeckelt auf
48 Stunden. Es gibt keine zweite Offline-Formel, die abdriften könnte.
Gespeichert wird Zustand, nicht Definition; Spielstände überleben so
Balancing-Updates.

---

## Interaktion

| Geste | Wirkung |
| --- | --- |
| Ziehen eines Möbels | stellt es um – und ändert Gewohnheiten, weil Wege zählen |
| Tippen auf ein Objekt | repariert Kaputtes, gießt Durstiges |
| Tippen auf einen Bewohner | Gedankenblase mit einer kurzen, poetischen Zeile |
| Doppeltippen auf einen Raum | Fokusmodus hinein – und wieder heraus |
| Notiz anheften | bringt zwei Bewohner im Flur zusammen – als Einladung, nicht als Befehl |

---

## Tests

```
needs_test.dart          Verfall, Antwortkurve, Traits
pathfinding_test.dart    Begehbarkeit, A* über Etagen, Wegschätzung
action_scorer_test.dart  Rangfolge, Objektzustand, Charakter, Privatsphäre
simulation_test.dart     Wochenlauf mit Invarianten, Möbel, Notizen
persistence_test.dart    Momentaufnahme, Nachberechnung, kaputte Stände
app_test.dart            echter Spielaufbau, Rendern, Fokusmodus, Overlays
```

Die Invarianten über eine Sim-Woche (niemand verwahrlost, alle schlafen
täglich, keine Doppelbelegung, das Haus wird vertikal genutzt) haben beim Bauen
echte Fehler gefunden: Wohnungen ohne Bett oder Bad, Dauerduschen aus
Ordnungsliebe, Dauerschlaf nach einem verpassten Weckzeitpunkt, ein leeres
Treppenhaus wegen zu teurer Wege und eine Dusche, die eine Woche kaputt blieb,
weil Reparieren nur Zufriedenheit brachte. Für jeden gibt es einen
Regressionstest.

---

## Nächste Schritte

- Pixel-Art-Sprites anstelle der Farbflächen (nur `palette.dart` und die
  `render`-Methoden)
- iOS-Build wieder aufnehmen (macOS-Runner, später signiert per Secret)
- mehr Angebote im Katalog – Balkon, Fahrradkeller, Post im Flur
- ein Debug-Overlay für die `ScoreBreakdown`
