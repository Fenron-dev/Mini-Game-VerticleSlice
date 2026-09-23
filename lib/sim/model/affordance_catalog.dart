import 'affordance.dart';
import 'interactable.dart';
import 'need.dart';

/// Was welches Möbelstück anbietet. Das ist der Balancing-Knopf des Spiels:
/// Neue Verhaltensweisen entstehen hier als Daten, nicht als Code.
///
/// Raten sind **pro Sim-Stunde**. Ein Wert von 0.5 füllt ein Bedürfnis in zwei
/// Stunden vollständig; negative Raten kosten (Kochen kostet Energie).
abstract final class AffordanceCatalog {
  static const _sleep = Affordance(
    id: 'sleep',
    label: 'schlafen',
    verb: 'schlafe',
    rates: {NeedType.energy: 0.16, NeedType.contentment: 0.02},
    baseDurationMinutes: 420,
    tags: {'sleep', 'quiet', 'solo', 'home'},
    posture: Posture.lie,
    isSleep: true,
    preferredHour: 1.0,
    preferredWindow: 5.0,
  );

  static const _nap = Affordance(
    id: 'nap',
    label: 'ein Nickerchen',
    verb: 'döse',
    rates: {NeedType.energy: 0.30, NeedType.contentment: 0.05},
    baseDurationMinutes: 45,
    tags: {'sleep', 'quiet', 'solo', 'home'},
    posture: Posture.lie,
    cooldownMinutes: 120,
  );

  static const _makeBed = Affordance(
    id: 'make_bed',
    label: 'das Bett machen',
    verb: 'mache das Bett',
    rates: {NeedType.contentment: 0.5, NeedType.energy: -0.05},
    baseDurationMinutes: 6,
    tags: {'clean', 'care', 'morning', 'home'},
    preferredHour: 8.0,
    preferredWindow: 2.5,
    cooldownMinutes: 600,
  );

  static const _cook = Affordance(
    id: 'cook',
    label: 'kochen',
    verb: 'koche',
    rates: {
      NeedType.hunger: 0.55,
      NeedType.energy: -0.10,
      NeedType.contentment: 0.20,
    },
    baseDurationMinutes: 55,
    tags: {'cook', 'eat', 'home', 'shared'},
    wearPerUse: 0.012,
    cooldownMinutes: 150,
    minNeedToStart: {NeedType.energy: 0.22},
  );

  static const _snack = Affordance(
    id: 'snack',
    label: 'etwas aus dem Kühlschrank',
    verb: 'stehe vor dem offenen Kühlschrank',
    rates: {NeedType.hunger: 0.9, NeedType.contentment: -0.04},
    baseDurationMinutes: 12,
    tags: {'snack', 'eat', 'home'},
    wearPerUse: 0.004,
    cooldownMinutes: 90,
  );

  static const _eatAtTable = Affordance(
    id: 'eat_at_table',
    label: 'in Ruhe essen',
    verb: 'esse',
    rates: {NeedType.hunger: 0.7, NeedType.contentment: 0.25},
    baseDurationMinutes: 35,
    tags: {'eat', 'shared', 'home'},
    posture: Posture.sit,
    exclusive: false,
  );

  static const _talkAtTable = Affordance(
    id: 'talk_at_table',
    label: 'am Tisch sitzen und reden',
    verb: 'sitze und rede',
    rates: {NeedType.social: 0.65, NeedType.contentment: 0.3},
    baseDurationMinutes: 40,
    tags: {'social', 'shared', 'home'},
    posture: Posture.sit,
    exclusive: false,
  );

  static const _wash = Affordance(
    id: 'wash',
    label: 'duschen',
    verb: 'dusche',
    rates: {NeedType.hygiene: 1.6, NeedType.energy: 0.08},
    baseDurationMinutes: 18,
    tags: {'clean', 'care', 'solo', 'home'},
    wearPerUse: 0.010,
    preferredHour: 7.5,
    preferredWindow: 6.0,
    // Kurze Sperre, damit die Dusche nicht im Minutentakt belegt wird. Gegen
    // Dauerduschen wirkt die Relevanzschwelle im Scorer, nicht diese Zahl:
    // Eine lange Objektsperre würde in einer Zwei-Personen-Wohnung mit einem
    // Bad den Mitbewohner mitbestrafen.
    cooldownMinutes: 60,
  );

  static const _toilet = Affordance(
    id: 'toilet',
    label: 'das Bad benutzen',
    verb: 'bin kurz weg',
    rates: {NeedType.hygiene: 0.5},
    baseDurationMinutes: 7,
    tags: {'clean', 'solo', 'home'},
    cooldownMinutes: 45,
  );

  static const _washHands = Affordance(
    id: 'wash_hands',
    label: 'sich frisch machen',
    verb: 'wasche mir die Hände',
    rates: {NeedType.hygiene: 0.9},
    baseDurationMinutes: 5,
    tags: {'clean', 'home'},
    cooldownMinutes: 60,
  );

  static const _doDishes = Affordance(
    id: 'do_dishes',
    label: 'abwaschen',
    verb: 'wasche ab',
    rates: {
      NeedType.contentment: 0.35,
      NeedType.hygiene: 0.2,
      NeedType.energy: -0.08,
    },
    baseDurationMinutes: 20,
    tags: {'clean', 'care', 'home'},
    cooldownMinutes: 300,
  );

  static const _read = Affordance(
    id: 'read',
    label: 'lesen',
    verb: 'lese',
    rates: {NeedType.contentment: 0.45, NeedType.energy: -0.02},
    baseDurationMinutes: 60,
    tags: {'leisure', 'quiet', 'solo', 'home'},
    posture: Posture.sit,
  );

  static const _lounge = Affordance(
    id: 'lounge',
    label: 'nichts tun',
    verb: 'sitze einfach da',
    rates: {NeedType.contentment: 0.3, NeedType.energy: 0.09},
    baseDurationMinutes: 45,
    tags: {'leisure', 'quiet', 'home'},
    posture: Posture.sit,
    exclusive: false,
  );

  static const _sitTogether = Affordance(
    id: 'sit_together',
    label: 'zusammen sitzen',
    verb: 'sitze mit jemandem zusammen',
    rates: {NeedType.social: 0.7, NeedType.contentment: 0.35},
    baseDurationMinutes: 50,
    tags: {'social', 'shared', 'leisure', 'home'},
    posture: Posture.sit,
    exclusive: false,
  );

  static const _work = Affordance(
    id: 'work',
    label: 'arbeiten',
    verb: 'arbeite',
    rates: {
      NeedType.contentment: 0.18,
      NeedType.energy: -0.14,
      NeedType.social: -0.05,
    },
    baseDurationMinutes: 150,
    tags: {'work', 'solo', 'quiet', 'home'},
    posture: Posture.sit,
    preferredHour: 10.5,
    preferredWindow: 4.5,
    minNeedToStart: {NeedType.energy: 0.3, NeedType.hunger: 0.25},
  );

  static const _listenRadio = Affordance(
    id: 'listen_radio',
    label: 'Radio hören',
    verb: 'höre Radio',
    rates: {NeedType.contentment: 0.4, NeedType.social: 0.12},
    baseDurationMinutes: 40,
    tags: {'leisure', 'home'},
    exclusive: false,
    wearPerUse: 0.015,
  );

  static const _waterPlant = Affordance(
    id: 'water_plant',
    label: 'die Pflanze gießen',
    verb: 'gieße',
    rates: {NeedType.contentment: 0.9},
    baseDurationMinutes: 6,
    tags: {'plant', 'care', 'home'},
    posture: Posture.crouch,
    requiresThirstyPlant: true,
    requiresWorking: false,
  );

  static const _tendPlant = Affordance(
    id: 'tend_plant',
    label: 'Blätter abstauben',
    verb: 'streiche über die Blätter',
    rates: {NeedType.contentment: 0.55},
    baseDurationMinutes: 10,
    tags: {'plant', 'care', 'quiet', 'home'},
    posture: Posture.crouch,
    requiresWorking: false,
    cooldownMinutes: 480,
  );

  static const _repair = Affordance(
    id: 'repair',
    label: 'reparieren',
    verb: 'schraube daran herum',
    rates: {NeedType.contentment: 0.6, NeedType.energy: -0.15},
    baseDurationMinutes: 35,
    tags: {'repair', 'broken', 'care'},
    posture: Posture.crouch,
    requiresWorking: false,
    requiresBroken: true,
    minNeedToStart: {NeedType.energy: 0.25},
  );

  static const _laundry = Affordance(
    id: 'laundry',
    label: 'Wäsche waschen',
    verb: 'sortiere Wäsche',
    rates: {
      NeedType.hygiene: 0.7,
      NeedType.contentment: 0.25,
      NeedType.energy: -0.1,
    },
    baseDurationMinutes: 40,
    tags: {'clean', 'care'},
    wearPerUse: 0.02,
    cooldownMinutes: 480,
  );

  static const _readBoard = Affordance(
    id: 'read_board',
    label: 'an der Pinnwand stehen',
    verb: 'lese, was am Brett hängt',
    rates: {NeedType.social: 0.35, NeedType.contentment: 0.2},
    baseDurationMinutes: 8,
    tags: {'social', 'shared'},
    exclusive: false,
    cooldownMinutes: 180,
  );

  static const _meetAtBoard = Affordance(
    id: 'meet_at_board',
    label: 'sich im Flur treffen',
    verb: 'bleibe im Flur stehen',
    rates: {NeedType.social: 1.0, NeedType.contentment: 0.5},
    baseDurationMinutes: 25,
    tags: {'social', 'shared', 'note'},
    exclusive: false,
  );

  static const _sitOnRoof = Affordance(
    id: 'sit_on_roof',
    label: 'aufs Dach setzen',
    verb: 'sehe über die Dächer',
    // Etwas Sozialkontakt: Nebeneinander schweigen zählt auch.
    rates: {
      NeedType.contentment: 0.65,
      NeedType.energy: 0.05,
      NeedType.social: 0.15,
    },
    baseDurationMinutes: 40,
    tags: {'leisure', 'quiet', 'shared'},
    posture: Posture.sit,
    exclusive: false,
  );

  static const _feedCat = Affordance(
    id: 'feed_cat',
    label: 'die Katze füttern',
    verb: 'fülle den Napf',
    rates: {NeedType.contentment: 0.7, NeedType.social: 0.25},
    baseDurationMinutes: 8,
    tags: {'care', 'shared'},
    posture: Posture.crouch,
    requiresWorking: false,
    cooldownMinutes: 240,
  );

  static const _checkBoiler = Affordance(
    id: 'check_boiler',
    label: 'nach dem Kessel sehen',
    verb: 'lausche dem Kessel',
    rates: {NeedType.contentment: 0.3},
    baseDurationMinutes: 12,
    tags: {'repair', 'care', 'solo'},
    requiresWorking: false,
    cooldownMinutes: 600,
  );

  /// Angebote pro Objektart. Reihenfolge egal – der Scorer sortiert.
  static final Map<ObjectKind, List<Affordance>> byKind = {
    ObjectKind.bed: const [_sleep, _nap, _makeBed],
    ObjectKind.stove: const [_cook, _repair],
    ObjectKind.fridge: const [_snack, _repair],
    ObjectKind.table: const [_eatAtTable, _talkAtTable],
    ObjectKind.sofa: const [_lounge, _sitTogether, _read],
    ObjectKind.armchair: const [_read, _lounge],
    ObjectKind.shower: const [_wash, _repair],
    ObjectKind.toilet: const [_toilet, _repair],
    ObjectKind.sink: const [_washHands, _doDishes, _repair],
    ObjectKind.desk: const [_work, _read],
    ObjectKind.bookshelf: const [_read],
    ObjectKind.radio: const [_listenRadio, _repair],
    ObjectKind.plant: const [_waterPlant, _tendPlant],
    ObjectKind.washer: const [_laundry, _repair],
    ObjectKind.pinboard: const [_readBoard, _meetAtBoard],
    ObjectKind.bench: const [_sitOnRoof],
    ObjectKind.catBowl: const [_feedCat],
    ObjectKind.boiler: const [_checkBoiler, _repair],
    ObjectKind.lamp: const [],
  };

  static List<Affordance> forKind(ObjectKind kind) => byKind[kind] ?? const [];

  /// Standardbreite in Tiles pro Art.
  static int widthOf(ObjectKind kind) => switch (kind) {
        ObjectKind.bed => 3,
        ObjectKind.sofa => 3,
        ObjectKind.table => 3,
        ObjectKind.bookshelf => 2,
        ObjectKind.desk => 2,
        ObjectKind.washer => 2,
        ObjectKind.shower => 2,
        ObjectKind.boiler => 2,
        ObjectKind.bench => 2,
        ObjectKind.stove => 2,
        ObjectKind.fridge => 2,
        ObjectKind.armchair => 2,
        ObjectKind.pinboard => 2,
        _ => 1,
      };

  /// Fest installiert = nicht per Drag verschiebbar.
  static bool movableOf(ObjectKind kind) => switch (kind) {
        ObjectKind.shower ||
        ObjectKind.toilet ||
        ObjectKind.sink ||
        ObjectKind.boiler ||
        ObjectKind.washer ||
        ObjectKind.pinboard =>
          false,
        _ => true,
      };

  /// Wie anfällig eine Art überhaupt für Defekte ist (0 = geht nie kaputt).
  static double fragilityOf(ObjectKind kind) => switch (kind) {
        ObjectKind.washer => 1.0,
        ObjectKind.boiler => 0.9,
        ObjectKind.stove => 0.6,
        ObjectKind.radio => 0.6,
        ObjectKind.fridge => 0.45,
        ObjectKind.shower => 0.35,
        ObjectKind.toilet => 0.3,
        ObjectKind.sink => 0.25,
        _ => 0.0,
      };
}
