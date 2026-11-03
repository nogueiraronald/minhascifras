import 'package:flutter/material.dart';
import 'estilo_app.dart';

/// Diálogo padronizado para entrada de nome (listas, temas, etc.) com
/// a mesma identidade visual do logo (gradiente, transparências e glassmorphism).
Future<String?> askName(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? subtitle,
  IconData? icon,
  String? actionLabel,
}) {
  final controller = TextEditingController(text: initial);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final lowerTitle = title.toLowerCase();
  final isList = lowerTitle.contains('lista') || lowerTitle.contains('setlist');
  final isTheme = lowerTitle.contains('tema') || lowerTitle.contains('estilo');

  final effectiveIcon = icon ??
      (isList
          ? Icons.queue_music_rounded
          : (isTheme ? Icons.folder_rounded : Icons.edit_note_rounded));

  final effectiveSubtitle = subtitle ??
      (isList
          ? 'Digite o nome para a sua lista de repertório:'
          : (isTheme
              ? 'Informe o nome para o estilo ou tema musical:'
              : 'Preencha o campo abaixo para continuar:'));

  final effectiveHint = hint ??
      (isList
          ? 'Ex: Culto de Domingo, Especial Acústico...'
          : (isTheme
              ? 'Ex: Louvor, Baião, MPB, Pop Rock...'
              : 'Digite o nome aqui...'));

  final effectiveActionLabel = actionLabel ??
      (lowerTitle.contains('novo') || lowerTitle.contains('nova')
          ? (isList ? 'Criar Lista' : (isTheme ? 'Criar Tema' : 'Criar'))
          : (lowerTitle.contains('renomear') ? 'Salvar Alterações' : 'Salvar'));

  return showDialog<String>(
    context: context,
    builder: (ctx) => CartaoDialogoModerno(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BadgeIconeGradiente(icon: effectiveIcon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      effectiveSubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: effectiveHint,
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                prefixIcon: Icon(
                  isList
                      ? Icons.playlist_add_rounded
                      : (isTheme
                          ? Icons.label_outline_rounded
                          : Icons.edit_outlined),
                  size: 20,
                  color: AppCores.roxo,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppCores.roxo.withValues(alpha: 0.25),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppCores.roxo.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppCores.roxo,
                    width: 2,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: (_) {
                final val = controller.text.trim();
                if (val.isNotEmpty) Navigator.pop(ctx, val);
              },
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.grey[400] : Colors.grey[700],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              BotaoGradiente(
                icon: Icons.check_rounded,
                label: effectiveActionLabel,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onPressed: () {
                  final val = controller.text.trim();
                  if (val.isNotEmpty) Navigator.pop(ctx, val);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
