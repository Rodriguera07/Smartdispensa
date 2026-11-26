import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/gradient_background.dart';

/// Splash com o logotipo surgindo suavemente.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 104),
                const SizedBox(height: 12),
                Text(
                  'Sua despensa, inteligente.',
                  style: context.text.bodyLarge
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
