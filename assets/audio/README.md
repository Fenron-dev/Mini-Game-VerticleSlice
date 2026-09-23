# Audio

Der Lo-Fi-Loop und die Regen-Schleife werden zur Laufzeit **optional** geladen.
Fehlt eine Datei, schaltet `AmbienceController` den jeweiligen Kanal still ab –
die App läuft weiter (siehe `lib/audio/ambience_controller.dart`).

Erwartete Dateien:

| Datei          | Inhalt                                   |
| -------------- | ---------------------------------------- |
| `lofi.ogg`     | ruhiger Lo-Fi-Loop, nahtlos schleifbar   |
| `rain.ogg`     | Regen am Fenster, nahtlos schleifbar     |

Die Dateien sind bewusst nicht eingecheckt: Das Repo bleibt binärfrei und die
prozeduralen Farbflächen-Assets brauchen keinerlei Downloads.
