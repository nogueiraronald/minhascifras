import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dados/biblioteca_acordes.dart';
import '../modelos/formato_acorde.dart';
import 'diagrama_acorde.dart';
import 'estilo_app.dart';

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

  // 6 cordas: frets (-1 = x, 0 = solta, >0 = casa)
  late List<int> _editFrets;
  // 6 cordas: fingers (0 = nenhum, 1 = indicador, 2 = médio, 3 = anelar, 4 = mínimo, 5 = polegar)
  late List<int> _editFingers;
  // Casa inicial do diagrama (0 = automática, >0 = casa específica)
  int _selectedBaseFret = 0;

  @override
  void initState() {
    super.initState();
    _shape = widget.library.find(widget.chord);
    _initEditValues();
  }

  void _initEditValues() {
    if (_shape != null) {
      _editFrets = List<int>.from(_shape!.frets);
      _editFingers = _shape!.fingers != null
          ? List<int>.from(_shape!.fingers!)
          : List<int>.filled(6, 0);
      _selectedBaseFret = _shape!.baseFretOverride ?? 0;
    } else {
      _editFrets = [-1, -1, 0, 2, 3, 2]; // padrão razoável se não existir
      _editFingers = [0, 0, 0, 1, 3, 2];
      _selectedBaseFret = 0;
      _editing = true;
    }
  }

  ChordShape get _previewShape => ChordShape(
        _editFrets,
        _editFingers,
        _selectedBaseFret > 0 ? _selectedBaseFret : null,
      );

  Future<void> _save() async {
    final shape = ChordShape(
      _editFrets,
      _editFingers,
      _selectedBaseFret > 0 ? _selectedBaseFret : null,
    );
    await widget.library.save(widget.chord, shape);
    if (!mounted) return;
    setState(() {
      _shape = shape;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Acorde "${widget.chord}" salvo com sucesso!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showForm = _editing || _shape == null;

    return CartaoDialogoModerno(
      width: clampDouble(MediaQuery.sizeOf(context).width * 0.92, 340, 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppCores.gradienteLogo,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppCores.roxo.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.chord,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showForm ? 'Editar Cordas e Dedos' : 'Dicionário de Acordes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showForm
                          ? 'Ajuste as casas e dedos no braço'
                          : 'Diagrama para violão e guitarra',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showForm) ...[
                    // MODO VISUALIZAÇÃO: Diagrama com indicação clara dos dedos, casas e cordas
                    Center(child: ChordDiagram(shape: _shape!)),
                  ] else ...[
                    // MODO EDIÇÃO: Diagrama em tempo real + Seletor de Casa Inicial + Tabela clara das 6 cordas
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: ChordDiagram(
                          shape: _previewShape,
                          size: const Size(160, 205),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Seletor da Casa Inicial do Diagrama (Pestana / Início do Braço)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppCores.roxo
                            .withValues(alpha: isDark ? 0.12 : 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppCores.roxo.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tag_rounded,
                              size: 20, color: AppCores.roxo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Casa inicial do diagrama:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                Text(
                                  'Ex: 4ª casa para pestanas como G#m ou C#m.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedBaseFret,
                              isDense: true,
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text(
                                    'Automática (${_previewShape.baseFret}ª)',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppCores.roxo,
                                        fontSize: 13),
                                  ),
                                ),
                                for (int f = 1; f <= 15; f++)
                                  DropdownMenuItem(
                                    value: f,
                                    child: Text('$fª casa',
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedBaseFret = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Configure cada corda (da 6ª mais grave à 1ª mais aguda):',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Lista das 6 cordas com Casa e Dedo
                    for (var i = 0; i < 6; i++) _buildStringRow(i),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppCores.roxo
                            .withValues(alpha: isDark ? 0.08 : 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppCores.roxo.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        '💡 Legenda dos dedos: 1 = Indicador • 2 = Médio • 3 = Anelar • 4 = Mínimo • T = Polegar\n'
                        'Para cordas que não devem ser tocadas, escolha "X (Abafada)".',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  if (_editing && _shape != null) {
                    setState(() {
                      _editing = false;
                      _initEditValues();
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
                child: Text(
                  _editing && _shape != null ? 'Cancelar' : 'Fechar',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (showForm)
                BotaoGradiente(
                  onPressed: _save,
                  icon: Icons.check_rounded,
                  label: 'Salvar Acorde',
                )
              else
                BotaoGradiente(
                  onPressed: () => setState(() => _editing = true),
                  icon: Icons.tune_rounded,
                  label: 'Editar Cordas e Dedos',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStringRow(int stringIndex) {
    final stringName = ChordShape.stringNames[stringIndex];
    final currentFret = _editFrets[stringIndex];
    final currentFinger = _editFingers[stringIndex];
    final isNarrow = MediaQuery.sizeOf(context).width < 540;

    // Seletor de Casa (Fret)
    final fretSelector = Row(
      children: [
        const Text('Casa: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: currentFret,
              isDense: true,
              isExpanded: true,
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _editFrets[stringIndex] = val;
                  if (val <= 0 && _editFingers[stringIndex] > 0) {
                    _editFingers[stringIndex] = 0;
                  }
                });
              },
              items: [
                const DropdownMenuItem(value: -1, child: Text('X (Abafada)', style: TextStyle(color: Colors.red, fontSize: 12))),
                const DropdownMenuItem(value: 0, child: Text('0 (Solta)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                for (int f = 1; f <= 15; f++)
                  DropdownMenuItem(value: f, child: Text('Casa $f', style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
        ),
      ],
    );

    // Seletor de Dedo
    final fingerSelector = Row(
      children: [
        const Text('Dedo: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: currentFinger,
              isDense: true,
              isExpanded: true,
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _editFingers[stringIndex] = val;
                });
              },
              items: const [
                DropdownMenuItem(value: 0, child: Text('- (Sem dedo)', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 1, child: Text('1 (Indicador)', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12))),
                DropdownMenuItem(value: 2, child: Text('2 (Médio)', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12))),
                DropdownMenuItem(value: 3, child: Text('3 (Anelar)', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12))),
                DropdownMenuItem(value: 4, child: Text('4 (Mínimo)', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12))),
                DropdownMenuItem(value: 5, child: Text('T (Polegar)', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        stringName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentFret == -1 ? 'Não tocar (X)' : (currentFret == 0 ? 'Corda solta' : 'Casa $currentFret'),
                      style: TextStyle(
                        fontSize: 11,
                        color: currentFret == -1 ? Colors.red : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: fretSelector),
                    const SizedBox(width: 8),
                    Expanded(child: fingerSelector),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    stringName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(child: fretSelector),
                const SizedBox(width: 12),
                Expanded(child: fingerSelector),
              ],
            ),
    );
  }
}
