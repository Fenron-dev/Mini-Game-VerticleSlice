import 'house_world.dart';
import 'model/need.dart';
import 'model/resident.dart';

/// Erzeugt die kurze, poetische Zeile für die Gedankenblase.
///
/// Kein Statusbericht ("Energie: 34 %"), sondern das, was jemand über seinen
/// Zustand denken würde. Die Auswahl ist deterministisch aus Person, Stunde und
/// Zustand abgeleitet: Zweimal tippen gibt dieselbe Zeile, eine Stunde später
/// eine andere. Das lässt Gedanken wie Gedanken wirken statt wie Würfelwürfe.
abstract final class ThoughtWriter {
  static String forResident(Resident resident, HouseWorld world) {
    final lines = _candidates(resident, world);
    return lines[_seed(resident, world) % lines.length];
  }

  static int _seed(Resident resident, HouseWorld world) {
    // Eigener, stabiler Hash statt String.hashCode – der ist nicht über
    // Plattformen und Programmstarts hinweg garantiert gleich.
    var h = 17;
    for (final c in resident.id.codeUnits) {
      h = (h * 31 + c) & 0x3FFFFFFF;
    }
    h = (h * 31 + world.clock.hour) & 0x3FFFFFFF;
    h = (h * 31 + resident.needs.mostUrgent.index + 1) & 0x3FFFFFFF;
    for (final c in (resident.activity?.affordance.id ?? '-').codeUnits) {
      h = (h * 31 + c) & 0x3FFFFFFF;
    }
    return h;
  }

  static List<String> _candidates(Resident resident, HouseWorld world) {
    if (resident.isAsleep) {
      return const [
        'Irgendwo tropft es. Das ist in Ordnung.',
        'Ein Traum von einem Zug, der nicht abfährt.',
        'Warm. Weiter nichts.',
        'Das Haus atmet mit.',
      ];
    }

    final activity = resident.activity;
    final need = resident.needs.mostUrgent;
    final value = resident.needs[need];
    final lines = <String>[];

    // Was gerade getan wird, färbt den Gedanken am stärksten.
    if (activity != null && activity.isPerforming) {
      lines.addAll(_activityLines(activity.affordance.id));
    } else if (activity != null && activity.isTraveling) {
      lines.addAll(const [
        'Sechs Stufen, dann noch mal sechs.',
        'Unterwegs zu etwas, das gleich wichtig wird.',
        'Das Treppenhaus riecht nach jemand anderem Abendessen.',
      ]);
    }

    // Dann das drängendste Bedürfnis.
    lines.addAll(_needLines(need, value));

    // Und zuletzt die Umgebung.
    if (world.weather == Weather.rain) {
      lines.addAll(const [
        'Der Regen macht das Fenster zu einem anderen Fenster.',
        'Draußen wäscht sich die Straße.',
      ]);
    }
    if (world.clock.daylight < 0.25) {
      lines.addAll(const [
        'Um diese Zeit gehört das Haus einem allein.',
        'Die Lampe unten brennt noch. Gut.',
      ]);
    }
    if (world.clock.eveningWarmth > 0.6) {
      lines.add('Das Licht liegt schräg auf dem Boden und bleibt kurz liegen.');
    }

    if (lines.isEmpty) lines.add('Ein Tag wie ein Glas Wasser.');
    return lines;
  }

  static List<String> _needLines(NeedType need, double value) {
    final urgent = value < 0.3;
    return switch (need) {
      NeedType.energy => urgent
          ? const [
              'Die Augen sind schwerer als der Rest.',
              'Nur kurz hinlegen. Nur ganz kurz.',
            ]
          : const [
              'Noch reicht es für eine Sache.',
              'Später wird das Sofa gewinnen.',
            ],
      NeedType.hunger => urgent
          ? const [
              'Der Kühlschrank ruft, und zwar namentlich.',
              'Vorhin war Brot da. Angeblich.',
            ]
          : const [
              'Man könnte etwas kochen. Man könnte auch nicht.',
              'Ein Apfel wäre jetzt ein guter Freund.',
            ],
      NeedType.hygiene => urgent
          ? const [
              'Warmes Wasser wäre eine gute Idee.',
              'Alles fühlt sich einen Tag zu lang an.',
            ]
          : const ['Später duschen, dann ist der Tag zweigeteilt.'],
      NeedType.social => urgent
          ? const [
              'Die Wände hier sind sehr höflich und sehr still.',
              'Man hört die Nachbarn und kennt sie doch nicht.',
              'Ein Klopfen wäre nicht das Schlechteste.',
            ]
          : const [
              'Irgendwer ist immer über einem und geht hin und her.',
              'Vielleicht später im Flur, vielleicht auch nicht.',
            ],
      NeedType.contentment => urgent
          ? const [
              'Es fehlt nichts und es fehlt trotzdem etwas.',
              'Der Tag hat sich noch nicht entschieden.',
            ]
          : const [
              'So kann es bleiben, eine Weile jedenfalls.',
              'Nichts zu tun, und das ist die Aufgabe.',
            ],
    };
  }

  static List<String> _activityLines(String affordanceId) =>
      switch (affordanceId) {
        'cook' => const [
            'Zwiebeln zuerst. Der Rest ergibt sich.',
            'Der Topf braucht länger als gedacht. Gut so.',
          ],
        'eat_at_table' => const ['Warm essen, im Sitzen. Ein kleiner Feiertag.'],
        'snack' => const [
            'Im Stehen essen zählt nicht als Mahlzeit. Zählt aber.',
          ],
        'read' => const [
            'Dieselbe Seite zum dritten Mal, und trotzdem schön.',
            'Draußen wird es dunkel, drinnen wird es enger und weicher.',
          ],
        'water_plant' => const ['Trink. Wir haben beide keine Eile.'],
        'tend_plant' => const ['Ein neues Blatt, ganz hell und noch ungeübt.'],
        'repair' => const [
            'Nichts ist kaputt, was noch klappert.',
            'Die Schraube war es. Meistens ist es die Schraube.',
          ],
        'work' => const ['Noch dieser eine Absatz, dann ist Abend.'],
        'wash' => const ['Das Wasser nimmt den halben Tag mit.'],
        'listen_radio' => const [
            'Ein Lied, das niemand ausgesucht hat, und genau richtig.',
          ],
        'sit_on_roof' => const [
            'Von hier oben sieht das Haus aus wie ein Regal.',
            'Die Stadt macht Geräusche, die nichts von einem wollen.',
          ],
        'sit_together' || 'talk_at_table' => const [
            'Reden, ohne dass es um etwas geht.',
            'Zwei Tassen, eine davon kalt geworden.',
          ],
        'meet_at_board' => const ['Da hängt ein Zettel, und er meint mich.'],
        'read_board' => const [
            'Jemand sucht seinen Schlüssel. Jemand anders bietet Zucchini an.',
          ],
        'laundry' => const [
            'Der Keller ist im Sommer der beste Raum im Haus.',
          ],
        'lounge' => const ['Sitzen und nichts. Das darf man.'],
        _ => const [],
      };
}
