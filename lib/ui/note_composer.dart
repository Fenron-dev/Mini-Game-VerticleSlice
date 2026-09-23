import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../sim/model/resident.dart';
import '../sim/simulation.dart';

/// Der Zettel für die Pinnwand im Treppenhaus.
///
/// Die einzige Interaktion, die zwei Menschen zusammenbringt – und sie tut es
/// als Einladung, nicht als Befehl: Sie macht gemeinsames Herumstehen im Flur
/// attraktiver. Wer müde ist, geht trotzdem erst ins Bett.
class NoteComposer extends StatefulWidget {
  const NoteComposer({
    super.key,
    required this.simulation,
    required this.onClose,
  });

  final HouseSimulation simulation;
  final VoidCallback onClose;

  @override
  State<NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends State<NoteComposer> {
  /// Vorformulierte Zeilen. Freitext wäre ein Eingabefeld mehr, das niemand
  /// braucht – die Notiz ist eine Geste, kein Brief.
  static const List<String> _texts = [
    'Wer hat Lust auf Kaffee im Flur?',
    'Ich habe zu viele Tomaten. Klingeln!',
    'Suche jemanden, der beim Regal hilft.',
    'Der Kessel klingt komisch. Wer kennt sich aus?',
    'Heute Abend Musik auf dem Dach, leise.',
    'Danke, wer auch immer gegossen hat.',
  ];

  String? _a;
  String? _b;
  String _text = _texts.first;

  List<Resident> get _residents => widget.simulation.world.residents;

  @override
  void initState() {
    super.initState();
    if (_residents.length >= 2) {
      _a = _residents[0].id;
      _b = _residents[1].id;
    }
  }

  bool get _valid => _a != null && _b != null && _a != _b;

  void _post() {
    if (!_valid) return;
    widget.simulation.postNote(residentA: _a!, residentB: _b!, text: _text);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xAA0E0C14),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEFE4CE),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 22),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nachbarschaftsnotiz',
                  style: TextStyle(
                    color: Color(0xFF2E2820),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ein Zettel am Brett. Mehr nicht – der Rest ist ihre Sache.',
                  style: TextStyle(
                    color: Color(0x992E2820),
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 18),
                _residentRow(
                  label: 'Für',
                  selected: _a,
                  disabled: _b,
                  onSelect: (id) => setState(() => _a = id),
                ),
                const SizedBox(height: 12),
                _residentRow(
                  label: 'und',
                  selected: _b,
                  disabled: _a,
                  onSelect: (id) => setState(() => _b = id),
                ),
                const SizedBox(height: 18),
                for (final t in _texts)
                  GestureDetector(
                    onTap: () => setState(() => _text = t),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            _text == t
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 15,
                            color: const Color(0xFF7A6A4E),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t,
                              style: const TextStyle(
                                color: Color(0xFF2E2820),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onClose,
                      child: const Text(
                        'Zurück',
                        style: TextStyle(color: Color(0xFF6B5F4A)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _valid ? _post : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7A6A4E),
                      ),
                      child: const Text('Anheften'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _residentRow({
    required String label,
    required String? selected,
    required String? disabled,
    required ValueChanged<String> onSelect,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: const TextStyle(color: Color(0x992E2820), fontSize: 12),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final resident in _residents)
                _ResidentChip(
                  resident: resident,
                  selected: selected == resident.id,
                  enabled: disabled != resident.id,
                  onTap: () => onSelect(resident.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResidentChip extends StatelessWidget {
  const _ResidentChip({
    required this.resident,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Resident resident;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = Palette.resident(resident.hue, lightness: 0.5);
    return Opacity(
      opacity: enabled ? 1.0 : 0.32,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colour : const Color(0x14000000),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colour, width: selected ? 0 : 1.2),
          ),
          child: Text(
            resident.name,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF2E2820),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
