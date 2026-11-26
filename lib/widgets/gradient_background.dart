import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Fundo em gradiente Azul-Petróleo → Verde-Esmeralda (ou claro), com dois
/// "orbes" de luz difusa que dão profundidade ao efeito de vidro.
///
/// Envolvido em [RepaintBoundary]: o fundo é estático e não é repintado
/// quando o conteúdo por cima rola.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: dark
            ? AppColors.darkBackgroundGradient
            : AppColors.lightBackgroundGradient,
      ),
      child: Stack(
        children: [
          RepaintBoundary(
            child: Stack(
              children: [
                _Orb(
                  alignment: const Alignment(-1.3, -1.1),
                  color: AppColors.mint.withValues(alpha: dark ? 0.16 : 0.18),
                  size: 340,
                ),
                _Orb(
                  alignment: const Alignment(1.4, 0.5),
                  color: AppColors.cyan.withValues(alpha: dark ? 0.12 : 0.14),
                  size: 300,
                ),
              ],
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Gradiente radial é muito mais barato que um blur real.
              gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
            ),
          ),
        ),
      ),
    );
  }
}
