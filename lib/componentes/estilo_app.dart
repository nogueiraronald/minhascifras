import 'dart:ui';
import 'package:flutter/material.dart';

/// Cores e gradientes oficiais da identidade visual (mesma paleta do logo).
class AppCores {
  static const Color indigo = Color(0xFF4F46E5);
  static const Color roxo = Color(0xFF7C3AED);
  static const Color rosa = Color(0xFFEC4899);

  /// Gradiente oficial do logo (Indigo -> Roxo -> Rosa)
  static const LinearGradient gradienteLogo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo, roxo, rosa],
  );

  /// Gradiente horizontal para botões e destaques
  static const LinearGradient gradienteBotao = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF5B4DF5), Color(0xFF7C3AED), Color(0xFFE11D74)],
  );

  /// Gradiente suave translúcido para fundos e cartões
  static LinearGradient gradienteTranslucido(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              indigo.withValues(alpha: 0.18),
              roxo.withValues(alpha: 0.12),
              rosa.withValues(alpha: 0.08),
            ]
          : [
              indigo.withValues(alpha: 0.08),
              roxo.withValues(alpha: 0.06),
              rosa.withValues(alpha: 0.04),
            ],
    );
  }
}

/// Cartão translúcido moderno com efeito glassmorphism (desfoque e transparência)
/// Cartão translúcido moderno com efeito glassmorphism (desfoque e transparência)
/// e barra superior no gradiente do logo. Totalmente responsivo para telas pequenas.
class CartaoDialogoModerno extends StatelessWidget {
  const CartaoDialogoModerno({
    super.key,
    required this.child,
    this.width = 460,
    this.margin,
  });

  final Widget child;
  final double width;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 460;
    final horizontalMargin = isSmallScreen ? 12.0 : 20.0;
    final maxAllowedWidth = screenWidth - (horizontalMargin * 2);
    final effectiveWidth = width > maxAllowedWidth ? maxAllowedWidth : width;
    final horizontalPadding = isSmallScreen ? 16.0 : 24.0;
    final verticalPadding = isSmallScreen ? 18.0 : 22.0;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: effectiveWidth,
          margin: margin ?? EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
            boxShadow: [
              BoxShadow(
                color: AppCores.roxo.withValues(alpha: isDark ? 0.35 : 0.18),
                blurRadius: 36,
                spreadRadius: 2,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : AppCores.roxo.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barra superior elegante no gradiente do logo
                    Container(
                      height: 4,
                      decoration: const BoxDecoration(
                        gradient: AppCores.gradienteLogo,
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          verticalPadding,
                          horizontalPadding,
                          verticalPadding,
                        ),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge elegante com gradiente do logo para ícones de cabeçalho
class BadgeIconeGradiente extends StatelessWidget {
  const BadgeIconeGradiente({
    super.key,
    required this.icon,
    this.size = 46,
    this.iconSize = 24,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppCores.gradienteLogo,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppCores.roxo.withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Botão com gradiente vibrante da paleta do logo e sombra suave.
/// Responsivo e adaptável a telas menores com padding customizável.
class BotaoGradiente extends StatelessWidget {
  const BotaoGradiente({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.padding,
    this.fontSize,
    this.iconSize,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    return Container(
      decoration: BoxDecoration(
        gradient: disabled
            ? LinearGradient(
                colors: [Colors.grey.shade400, Colors.grey.shade500],
              )
            : AppCores.gradienteBotao,
        borderRadius: BorderRadius.circular(12),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: AppCores.roxo.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : onPressed,
          child: Padding(
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else if (icon != null) ...[
                  Icon(icon, size: iconSize ?? 17, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: fontSize ?? 13.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
