import 'dart:async';

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/house_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Erst starten, dann einrichten.
  //
  // Ausrichtung und Vollbild hängen an Plattformkanälen, die nicht überall
  // existieren und nicht jederzeit erlaubt sind. Würde `main` darauf warten,
  // hinge der ganze Start an einem Aufruf, der nur Komfort liefert: Bei einem
  // Fehlschlag sähe man eine leere Fläche statt eines Hauses. Also nebenher,
  // mit Zeitlimit.
  unawaited(_prepareDevice());

  runApp(const VerticalSliceApp());
}

Future<void> _prepareDevice() async {
  // Ein Haus im Querschnitt wirkt im Querformat am besten; auf dem iPad sind
  // beide Landschaftsrichtungen erlaubt.
  await _attempt(
    'Ausrichtung',
    () => SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]),
  );
  await _attempt('Vollbild', Flame.device.fullScreen);
}

/// Führt [action] aus und gibt nach [limit] auf – ohne je zu werfen.
Future<void> _attempt(
  String label,
  Future<void> Function() action, {
  Duration limit = const Duration(seconds: 3),
}) async {
  try {
    await action().timeout(limit);
  } on Object catch (error) {
    debugPrint('$label nicht verfügbar: $error');
  }
}

class VerticalSliceApp extends StatelessWidget {
  const VerticalSliceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vertical Slice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1B2033),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE0B87C),
          brightness: Brightness.dark,
        ),
      ),
      home: const HouseScreen(),
    );
  }
}
