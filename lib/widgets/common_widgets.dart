import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/pantry_item.dart';

/// Logotipo do Smart Dispensa (ícone + nome).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Smart Dispensa',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(size * 0.3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mint.withValues(alpha: 0.45),
                  blurRadius: size * 0.45,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.kitchen_rounded,
                    size: size * 0.52, color: AppColors.petroleum),
                Positioned(
                  right: size * 0.16,
                  top: size * 0.14,
                  child: Icon(Icons.auto_awesome_rounded,
                      size: size * 0.22, color: Colors.white),
                ),
              ],
            ),
          ),
          if (showName) ...[
            SizedBox(height: size * 0.22),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Smart '),
                  TextSpan(
                    text: 'Dispensa',
                    style: TextStyle(color: context.colors.primary),
                  ),
                ],
              ),
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selo dourado "Premium ✨".
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.compact = false, this.label = 'Premium'});

  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.premiumGradient,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        '$label ✨',
        maxLines: 1,
        softWrap: false,
        style: (compact ? context.text.labelSmall : context.text.labelMedium)
            ?.copyWith(color: AppColors.petroleum, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Barra de nível do estoque com cor semântica.
class StockLevelBar extends StatelessWidget {
  const StockLevelBar({super.key, required this.ratio, required this.level});

  final double ratio;
  final StockLevel level;

  static Color colorFor(StockLevel level) => switch (level) {
        StockLevel.out => AppColors.danger,
        StockLevel.low => AppColors.warning,
        StockLevel.ok => AppColors.mint,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(level);
    return Semantics(
      value: '${(ratio * 100).round()}% do estoque ideal',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 8,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: color.withValues(alpha: 0.15)),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.75), color],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vazio amigável.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    this.action,
  });

  final String emoji;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center, style: context.text.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Cabeçalho de seção com ação opcional à direita.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.text.titleLarge),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Botão com gradiente primário e brilho esmeralda.
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.gradient = AppColors.primaryGradient,
    this.glowColor = AppColors.mint,
    this.foreground = AppColors.petroleum,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Gradient gradient;
  final Color glowColor;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTheme.minTouchTarget + 4,
                ),
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: foreground,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: foreground, size: 26),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: context.text.titleMedium?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// FAB central "Escanear Nota Fiscal" com brilho esmeralda pulsante.
class ScanGlowFab extends StatefulWidget {
  const ScanGlowFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<ScanGlowFab> createState() => _ScanGlowFabState();
}

class _ScanGlowFabState extends State<ScanGlowFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: 'Escanear nota fiscal',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = reduceMotion ? 0.5 : _pulse.value;
            return DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mint.withValues(alpha: 0.35 + 0.3 * t),
                    blurRadius: 18 + 14 * t,
                    spreadRadius: 1 + 3 * t,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Material(
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: InkWell(
                onTap: widget.onPressed,
                child: const Icon(
                  Icons.document_scanner_rounded,
                  size: 34,
                  color: AppColors.petroleum,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seletor de quantidade com botões grandes (−/+).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.step = 1,
    this.label,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double step;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Diminuir ${label ?? ''}',
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.text.titleLarge,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Aumentar ${label ?? ''}',
          onPressed: () => onChanged(value + step),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

/// Exibe uma SnackBar padronizada.
void showAppSnack(BuildContext context, String message, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon ?? Icons.check_circle_rounded, color: AppColors.mint),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
