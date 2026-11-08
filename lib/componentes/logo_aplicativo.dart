import 'package:flutter/material.dart';

/// Botão de retorno à Página Inicial com as mesmas dimensões e identidade visual do bloco do AppLogo.
class BotaoVoltarInicio extends StatelessWidget {
  const BotaoVoltarInicio({
    super.key,
    required this.onTap,
    this.iconSize = 24,
    this.tooltip = 'Voltar para a Página Inicial',
  });

  final VoidCallback onTap;
  final double iconSize;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxSize = iconSize + 10;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF4F46E5).withValues(alpha: 0.28),
                        const Color(0xFF7C3AED).withValues(alpha: 0.22),
                      ]
                    : [
                        const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF7C3AED)
                    .withValues(alpha: isDark ? 0.45 : 0.3),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.home_rounded,
                size: iconSize,
                color: isDark ? Colors.white : const Color(0xFF4F46E5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo moderno e elegante do aplicativo MinhasCifras.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.compact = false,
    this.iconSize = 24,
    this.onTap,
  });

  final bool compact;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ícone estilizado com gradiente moderno
        Container(
          width: iconSize + 10,
          height: iconSize + 10,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4F46E5), // Indigo
                Color(0xFF7C3AED), // Roxo
                Color(0xFFEC4899), // Rosa
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.music_note_rounded,
              size: iconSize,
              color: Colors.white,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Minhas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      TextSpan(
                        text: 'Cifras',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Suas cifras, seu ritmo.',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: content,
    );
  }
}
