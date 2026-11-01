import 'package:flutter/material.dart';

import '../data/chord_library.dart';
import '../models/chord_shape.dart';
import 'chord_diagram.dart';

Future<void> showChordDialog(
    BuildContext context, ChordLibrary library, String chord) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ChordDialog(library: library, chord: chord),
  );
}

class _ChordDialog extends StatefulWidget {
  const _ChordDialog({required this.library, required this.chord});

  final ChordLibrary library;
  final String chord;

  @override
  State<_ChordDialog> createState() => _ChordDialogState();
}

class _ChordDialogState extends State<_ChordDialog> {
  ChordShape? _shape;
  bool _editing = false;
  String? _error;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _shape = widget.library.find(widget.chord);
    _ctrl = TextEditingController(text: _shape?.toText() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final shape = ChordShape.parse(_ctrl.text);
    if (shape == null) {
      setState(() => _error = 'Use 6 valores, ex.: x,3,2,0,1,0');
      return;
    }
    await widget.library.save(widget.chord, shape);
    if (!mounted) return;
    setState(() {
      _shape = shape;
      _editing = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showForm = _editing || _shape == null;
    return AlertDialog(
      title: Text(widget.chord),
      content: showForm
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_shape == null)
                  const Text('Diagrama não encontrado.\nInforme as casas da 6ª à 1ª corda:'),
                const SizedBox(height: 8),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: InputDecoration(hintText: 'x,3,2,0,1,0', errorText: _error),
                ),
              ],
            )
          : Column(mainAxisSize: MainAxisSize.min, children: [ChordDiagram(shape: _shape!)]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        if (showForm)
          FilledButton(onPressed: _save, child: const Text('Salvar'))
        else
          TextButton(onPressed: () => setState(() => _editing = true), child: const Text('Editar')),
      ],
    );
  }
}
