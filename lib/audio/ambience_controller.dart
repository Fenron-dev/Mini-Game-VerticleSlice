import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../sim/house_world.dart';

/// Lo-Fi-Loop und Regen am Fenster.
///
/// Der Ton ist **optional**. Fehlt eine Datei – und im Repo fehlen beide, damit
/// es binärfrei bleibt –, schaltet sich der jeweilige Kanal still ab. Ein Spiel
/// über ein ruhiges Haus darf nicht daran scheitern, dass keine Musik da ist.
class AmbienceController {
  AmbienceController({this.enabled = true});

  final bool enabled;

  static const String musicTrack = 'lofi.ogg';
  static const String rainTrack = 'rain.ogg';

  bool _started = false;
  bool _musicPlaying = false;
  bool _rainAvailable = true;
  AudioPlayer? _rain;

  Future<void> start() async {
    if (!enabled || _started) return;
    _started = true;
    try {
      FlameAudio.bgm.initialize();
      await FlameAudio.bgm.play(musicTrack, volume: 0.35);
      _musicPlaying = true;
    } on Object catch (error) {
      // Kein Ton ist kein Fehler – nur eine Information beim Entwickeln.
      debugPrint('Lo-Fi-Loop nicht verfügbar: $error');
    }
  }

  /// Regen ein- und ausblenden, wenn das Wetter umschlägt.
  Future<void> syncWeather(Weather weather) async {
    if (!enabled || !_rainAvailable) return;
    final shouldRain = weather == Weather.rain;
    if (shouldRain == (_rain != null)) return;

    try {
      if (shouldRain) {
        _rain = await FlameAudio.loop(rainTrack, volume: 0.25);
      } else {
        await _rain?.stop();
        await _rain?.dispose();
        _rain = null;
      }
    } on Object catch (error) {
      _rainAvailable = false;
      _rain = null;
      debugPrint('Regenschleife nicht verfügbar: $error');
    }
  }

  Future<void> pause() async {
    if (_musicPlaying) await FlameAudio.bgm.pause();
    await _rain?.pause();
  }

  Future<void> resume() async {
    if (_musicPlaying) await FlameAudio.bgm.resume();
    await _rain?.resume();
  }

  Future<void> dispose() async {
    if (_musicPlaying) await FlameAudio.bgm.stop();
    await _rain?.dispose();
    _musicPlaying = false;
    _rain = null;
  }
}
