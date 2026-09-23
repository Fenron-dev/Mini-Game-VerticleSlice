import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Ablage des Spielstands. Abstrakt, damit die Simulation in reinen
/// Dart-Tests ohne Dateisystem gespeichert und geladen werden kann.
abstract class SaveStore {
  Future<String?> read();
  Future<void> write(String contents);
  Future<void> clear();
}

/// Spielstand als JSON-Datei im App-Verzeichnis. Offline, ohne Konto,
/// ohne Netzwerk – das Haus gehört dem Gerät.
class FileSaveStore implements SaveStore {
  FileSaveStore({this.fileName = 'vertical_slice_save.json'});

  final String fileName;
  File? _cached;

  /// Kein Speicher verfügbar? Dann läuft das Haus eben nur, solange die App
  /// offen ist. Ein Spiel ohne Punktestand darf an einem fehlenden Verzeichnis
  /// nicht scheitern – lieber vergesslich als kaputt.
  bool _writable = true;

  Future<File> _file() async {
    final existing = _cached;
    if (existing != null) return existing;
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _cached = File('${dir.path}/$fileName');
  }

  @override
  Future<String?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      return contents.isEmpty ? null : contents;
    } on Object catch (error) {
      _disable('Lesen', error);
      return null;
    }
  }

  @override
  Future<void> write(String contents) async {
    if (!_writable) return;
    try {
      final file = await _file();
      // Erst daneben schreiben, dann umbenennen: Ein Absturz mitten im
      // Speichern darf keinen halben Spielstand hinterlassen.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(contents, flush: true);
      await temp.rename(file.path);
    } on Object catch (error) {
      _disable('Speichern', error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } on Object catch (error) {
      _disable('Löschen', error);
    }
  }

  void _disable(String what, Object error) {
    if (_writable) {
      debugPrint('Spielstand: $what nicht möglich, läuft ohne Persistenz '
          'weiter ($error)');
    }
    _writable = false;
  }
}

/// Speicher im Arbeitsspeicher – für Tests.
class MemorySaveStore implements SaveStore {
  String? _contents;

  @override
  Future<String?> read() async => _contents;

  @override
  Future<void> write(String contents) async => _contents = contents;

  @override
  Future<void> clear() async => _contents = null;
}
