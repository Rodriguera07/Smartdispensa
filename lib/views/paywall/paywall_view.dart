import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/legal/legal_markdown.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/subscription_service.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../legal/legal_view.dart';

/// Paywall "Smart Dispensa Premium ✨".
class PaywallView extends StatefulWidget {
  const PaywallView({super.key, this.reason});

  /// Motivo contextual (ex.: cota de scans esgotada).
  final String? reason;

  static Future<void> open(BuildContext context, {String? reason}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PaywallView(reason: reason),
      ),
    );
  }

  @override
  State<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<PaywallView> {
  @override
  void initState() {
    super.initState();
    // Busca preços localizados no Google Play (não bloqueia a tela).
    // Após o primeiro frame, para não notificar listeners durante o build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SubscriptionViewModel>().loadOfferings();
    });
  }

  Future<void> _subscribe() async {
    final vm = context.read<SubscriptionViewModel>();
    HapticFeedback.mediumImpact();
    final outcome = await vm.purchaseSelected();
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        Navigator.of(context).pop();
        showAppSnack(context, 'Bem-vindo ao Premium ✨ Aproveite!',
            icon: Icons.workspace_premium_rounded);
      case PurchaseOutcome.cancelled:
        break;
      case PurchaseOutcome.failed:
        showAppSnack(context, 'Não foi possível concluir a assinatura. '
            'Nenhum valor foi cobrado.', icon: Icons.error_rounded);
      case PurchaseOutcome.unavailable:
        showAppSnack(context, 'Assinaturas indisponíveis no momento. '
            'Verifique sua conexão e a conta Google Play.',
            icon: Icons.cloud_off_rounded);
    }
  }

  Future<void> _restore() async {
    final ok = await context.read<SubscriptionViewModel>().restore();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      showAppSnack(context, 'Assinatura restaurada ✨');
    } else {
      showAppSnack(context, 'Nenhuma assinatura ativa encontrada nesta conta.',
          icon: Icons.info_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SubscriptionViewModel>();
    final trial = vm.trialDays;
    final selected = vm.selected;
    final periodText = switch (selected) {
      PlanType.monthly => 'por mês',
      PlanType.quarterly => 'por trimestre',
      PlanType.annual => 'por ano',
    };

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 28),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    const _Hero(),
                    if (widget.reason != null) ...[
                      const SizedBox(height: 16),
                      GlassCard(
                        blur: false,
                        borderColor: AppColors.gold.withValues(alpha: 0.5),
                        child: Row(
                          children: [
                            const Icon(Icons.info_rounded, color: AppColors.gold),
                            const SizedBox(width: 12),
                            Expanded(child: Text(widget.reason!)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _ComparisonTable(),
                    const SizedBox(height: 24),
                    Text('Escolha seu plano', style: context.text.titleLarge),
                    const SizedBox(height: 12),
                    for (final plan in PlanType.values)
                      _PlanCard(plan: plan, key: ValueKey(plan)),
                    if (!vm.storeAvailable) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Preços de referência. Os valores finais são exibidos '
                        'pelo Google Play no momento da assinatura.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              // Rodapé fixo com CTA e transparência de cobrança.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    GlowButton(
                      label: trial > 0
                          ? 'Começar $trial Dias Grátis'
                          : 'Assinar agora',
                      icon: Icons.workspace_premium_rounded,
                      loading: vm.purchasing,
                      gradient: AppColors.premiumGradient,
                      glowColor: AppColors.gold,
                      onPressed: _subscribe,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      trial > 0
                          ? '$trial dias grátis, depois ${vm.priceLabel(selected)} '
                              '$periodText. Renovação automática pelo Google '
                              'Play. Cancele quando quiser, sem custo, antes '
                              'do fim do teste.'
                          : '${vm.priceLabel(selected)} $periodText. Renovação '
                              'automática pelo Google Play. Cancele quando quiser.',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall,
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: vm.purchasing ? null : _restore,
                          child: const Text('Restaurar compras'),
                        ),
                        TextButton(
                          onPressed: () => LegalView.open(context, LegalDoc.terms),
                          child: const Text('Termos'),
                        ),
                        TextButton(
                          onPressed: () =>
                              LegalView.open(context, LegalDoc.privacy),
                          child: const Text('Privacidade'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.premiumGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.5),
                blurRadius: 36,
              ),
            ],
          ),
          child: const Icon(Icons.workspace_premium_rounded,
              size: 46, color: AppColors.petroleum),
        ),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Smart Dispensa '),
            TextSpan(
              text: 'Premium ✨',
              style: TextStyle(
                foreground: Paint()
                  ..shader = AppColors.premiumGradient
                      .createShader(const Rect.fromLTWH(0, 0, 160, 30)),
              ),
            ),
          ]),
          textAlign: TextAlign.center,
          style: context.text.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Economize de verdade: scanner ilimitado, histórico de preços e '
          'relatórios para saber para onde vai seu dinheiro.',
          textAlign: TextAlign.center,
          style: context.text.bodyLarge
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  static const _rows = <(String, String?, String?)>[
    // (recurso, grátis, premium) — null = não incluso, '✓' = incluso
    ('Escaneamento de notas', '${AppConstants.freeScansPerMonth}/mês', 'Ilimitado'),
    ('Estoque manual', 'Ilimitado', 'Ilimitado'),
    ('Lista de compras inteligente', '✓', '✓'),
    ('Histórico de variação de preços', null, '✓'),
    ('Relatórios mensais e quinzenais', null, '✓'),
    ('Sem anúncios', null, '✓'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget cell(String? v, {bool premium = false}) {
      if (v == null) {
        return Icon(Icons.close_rounded,
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
            semanticLabel: 'Não incluso');
      }
      if (v == '✓') {
        return Icon(Icons.check_circle_rounded,
            color: premium ? AppColors.gold : AppColors.mint,
            semanticLabel: 'Incluso');
      }
      return Text(
        v,
        textAlign: TextAlign.center,
        style: context.text.labelMedium?.copyWith(
          color: premium ? AppColors.gold : null,
        ),
      );
    }

    return GlassCard(
      radius: AppTheme.radiusL,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.1),
          2: FlexColumnWidth(1.2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            const SizedBox.shrink(),
            Text('Grátis',
                textAlign: TextAlign.center, style: context.text.titleSmall),
            const Center(
              child: FittedBox(child: PremiumBadge(compact: true)),
            ),
          ]),
          for (final r in _rows)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(r.$1, style: context.text.bodyMedium),
              ),
              Center(child: cell(r.$2)),
              Center(child: cell(r.$3, premium: true)),
            ]),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({super.key, required this.plan});

  final PlanType plan;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SubscriptionViewModel>();
    final selected = vm.selected == plan;
    final savings = vm.savingsPercent(plan);

    final (title, tag, subtitle) = switch (plan) {
      PlanType.monthly => (
          'Mensal',
          null,
          'Flexibilidade total, cancele quando quiser',
        ),
      PlanType.quarterly => (
          'Trimestral',
          'Mais Popular 🔥',
          'Equivale a ${vm.perMonthLabel(plan)}/mês — economize ${savings.floor()}%',
        ),
      PlanType.annual => (
          'Anual',
          'Melhor Oferta 👑',
          'Equivale a ${vm.perMonthLabel(plan)}/mês — economize ~${savings.round()}%',
        ),
    };
    final periodSuffix = switch (plan) {
      PlanType.monthly => '/mês',
      PlanType.quarterly => '/trimestre',
      PlanType.annual => '/ano',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusM + 2),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.mint.withValues(alpha: 0.35),
                      blurRadius: 22,
                    ),
                  ]
                : const [],
          ),
          child: GlassCard(
            blur: false,
            onTap: () {
              HapticFeedback.selectionClick();
              vm.select(plan);
            },
            borderWidth: selected ? 2 : 1,
            borderColor: selected ? AppColors.mint : null,
            gradient: selected
                ? LinearGradient(colors: [
                    AppColors.mint.withValues(alpha: 0.16),
                    AppColors.cyan.withValues(alpha: 0.08),
                  ])
                : null,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? AppColors.mint
                      : context.colors.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title, style: context.text.titleMedium),
                          if (tag != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: plan == PlanType.annual
                                    ? AppColors.premiumGradient
                                    : AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tag,
                                style: context.text.labelSmall?.copyWith(
                                  color: AppColors.petroleum,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(vm.priceLabel(plan), style: context.text.titleMedium),
                    Text(periodSuffix, style: context.text.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
