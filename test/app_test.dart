import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_slice/game/components/object_component.dart';
import 'package:vertical_slice/game/components/resident_component.dart';
import 'package:vertical_slice/game/components/thought_bubble.dart';
import 'package:vertical_slice/game/vertical_slice_game.dart';
import 'package:vertical_slice/persistence/save_service.dart';
import 'package:vertical_slice/persistence/save_store.dart';
import 'package:vertical_slice/sim/building_factory.dart';
import 'package:vertical_slice/sim/house_world.dart';
import 'package:vertical_slice/sim/model/grid.dart';
import 'package:vertical_slice/sim/simulation.dart';
import 'package:vertical_slice/ui/house_screen.dart';

// Die Simulationstests fassen nie eine Zeichenroutine an. Diese hier bauen das
// Spiel wirklich auf und lassen es Bilder rendern – damit ein Fehler im
// Zeichnen nicht erst auf dem Gerät auffällt.

HouseSimulation _sim({int hour = 19}) => HouseSimulation(
      world: BuildingFactory.createDefault(
        rng: math.Random(3),
        now: DateTime(2024, 6, 7, hour),
      ),
    );

Future<void> _frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<VerticalSliceGame> _pumpGame(
  WidgetTester tester, {
  int hour = 19,
  VoidCallback? onNote,
}) async {
  final game =
      VerticalSliceGame(sim: _sim(hour: hour), onOpenNoteComposer: onNote);
  await tester.pumpWidget(
    MaterialApp(home: GameWidget<VerticalSliceGame>(game: game)),
  );
  await tester.pump();
  await _frames(tester, 1);
  return game;
}

/// Zielgerät ist ein Tablet im Querformat. Die 800×600 der Testumgebung sind
/// kleiner als jedes echte Ziel – der Notizzettel ragt dort unten heraus.
void _useTabletSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpScreen(WidgetTester tester) async {
  _useTabletSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: HouseScreen(
        saveService: SaveService(store: MemorySaveStore()),
        enableAudio: false,
      ),
    ),
  );
  // Ein Spiel mit laufender Schleife wird nie "settled" – deshalb eine feste
  // Zahl Bilder, bis der Spielstand geladen ist.
  await _frames(tester, 12);
}

VerticalSliceGame _gameOf(WidgetTester tester) => tester
    .widget<GameWidget<VerticalSliceGame>>(
        find.byType(GameWidget<VerticalSliceGame>))
    .game!;

void main() {
  group('Spielaufbau', () {
    testWidgets('baut Haus, Möbel und Bewohner auf', (tester) async {
      final game = await _pumpGame(tester);
      expect(game.world.children.whereType<ObjectComponent>().length,
          game.sim.world.objects.length);
      expect(game.world.children.whereType<ResidentComponent>().length, 6);
    });

    testWidgets('rendert viele Bilder ohne Ausnahme', (tester) async {
      await _pumpGame(tester);
      await _frames(tester, 90);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rendert auch nachts und bei Regen', (tester) async {
      final game = await _pumpGame(tester, hour: 2);
      game.sim.world.weather = Weather.rain;
      await _frames(tester, 40);
      expect(tester.takeException(), isNull);
    });

    testWidgets('die Uhr läuft mit den Frames weiter', (tester) async {
      final game = await _pumpGame(tester);
      final before = game.sim.world.clock.simSeconds;
      await _frames(tester, 180);
      expect(game.sim.world.clock.simSeconds, greaterThan(before));
    });
  });

  group('Fokusmodus', () {
    testWidgets('zoomt in einen Raum und wieder heraus', (tester) async {
      final game = await _pumpGame(tester);
      final wide = game.camera.viewfinder.zoom;
      final room = game.sim.world.roomById['r2_living']!;

      game.toggleFocus(room);
      await _frames(tester, 60);
      expect(game.camera.viewfinder.zoom, greaterThan(wide * 1.5));
      expect(game.focusedRoomId, 'r2_living');

      game.toggleFocus(room);
      await _frames(tester, 90);
      expect(game.camera.viewfinder.zoom, closeTo(wide, wide * 0.1));
      expect(game.focusedRoomId, isNull);
    });

    testWidgets('die Kamera bleibt im Haus, auch an den Ecken', (tester) async {
      final game = await _pumpGame(tester);
      for (final roomId in ['roof', 'c_laundry', 'r4_bed', 'r1_bath']) {
        game.toggleFocus(game.sim.world.roomById[roomId]!);
        await _frames(tester, 45);
        final p = game.camera.viewfinder.position;
        expect(p.x, inInclusiveRange(0, HouseGeometry.worldWidth));
        expect(p.y, inInclusiveRange(0, HouseGeometry.worldHeight));
        game.clearFocus();
      }
    });
  });

  group('Berührungen', () {
    testWidgets('Antippen eines Bewohners zeigt eine Gedankenblase',
        (tester) async {
      final game = await _pumpGame(tester);
      final mira = game.sim.world.residentById['mira']!;
      game.showThought(mira, game.sim.thoughtFor('mira'));
      await _frames(tester, 1);

      final bubbles = game.world.children.whereType<ThoughtBubble>();
      expect(bubbles, hasLength(1));
      expect(bubbles.first.text, isNotEmpty);
    });

    testWidgets('es steht immer nur eine Blase im Bild', (tester) async {
      final game = await _pumpGame(tester);
      game.showThought(game.sim.world.residents[0], 'eins');
      await _frames(tester, 1);
      game.showThought(game.sim.world.residents[1], 'zwei');
      await _frames(tester, 1);
      expect(game.world.children.whereType<ThoughtBubble>(), hasLength(1));
    });

    testWidgets('eine Blase verschwindet von selbst', (tester) async {
      final game = await _pumpGame(tester);
      game.showTouch(game.sim.world.objects.first.cell, 'gegossen');
      await _frames(tester, 1);
      expect(game.world.children.whereType<ThoughtBubble>(), hasLength(1));
      await _frames(tester, 200);
      expect(game.world.children.whereType<ThoughtBubble>(), isEmpty);
    });

    testWidgets('die Pinnwand ruft den Notizzettel auf', (tester) async {
      var opened = false;
      final game = await _pumpGame(tester, onNote: () => opened = true);
      game.openNoteComposer();
      expect(opened, isTrue);
    });
  });

  group('Ganzer Bildschirm', () {
    testWidgets('startet und zeigt den Zettelknopf', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('Notiz anheften'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('der Zettel lässt sich öffnen und wieder schließen',
        (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.text('Notiz anheften'));
      await _frames(tester, 2);
      expect(find.text('Nachbarschaftsnotiz'), findsOneWidget);

      await tester.tap(find.text('Zurück'));
      await _frames(tester, 2);
      expect(find.text('Nachbarschaftsnotiz'), findsNothing);
    });

    testWidgets('eine angeheftete Notiz kommt in der Welt an', (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.text('Notiz anheften'));
      await _frames(tester, 2);
      await tester.tap(find.text('Anheften'));
      await _frames(tester, 2);
      expect(_gameOf(tester).sim.world.notes, hasLength(1));
    });
  });
}
