import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Cartão com efeito **Glassmorphism**: fundo translúcido, borda fina de 1px
/// (branco 15%) e sombra suave.
///
/// ### Performance
/// `BackdropFilter` é caro: cada instância força uma camada de composição.
/// Por isso existe o parâmetro [blur]:
/// - `true` (padrão) → desfoque real; use em poucos elementos de destaque
///   (cards de resumo, paywall, cabeçalhos);
/// - `false` → "vidro leve" (só translucidez + borda), ideal para **itens de
///   lista**, mantendo a rolagem a 60/120 fps.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = AppTheme.radiusM,
    this.blur = true,
    this.onTap,
    this.borderColor,
    this.borderWidth = 1,
    this.gradient,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final bool blur;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  /// Gradiente opcional sobre o vidro (ex.: destaque de plano selecionado).
  final Gradient? gradient;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final borderRadius = BorderRadius.circular(radius);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null
            ? (dark ? AppColors.glassFillDark : AppColors.glassFillLight)
            : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ??
              (dark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
          width: borderWidth,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (blur) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      );
    }

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Semantics(
          label: semanticLabel,
          button: onTap != null,
          child: ClipRRect(borderRadius: borderRadius, child: content),
        ),
      ),
    );
  }
}
