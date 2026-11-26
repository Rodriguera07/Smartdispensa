import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/purchase_record.dart';
import '../../viewmodels/pantry_viewmodel.dart';
import '../../viewmodels/reports_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';
import '../paywall/paywall_view.dart';

/// Relatórios mensais/quinzenais e variação de preços (Premium ✨).
class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  ReportPeriod _period = ReportPeriod.monthly;

  @override
  Widget build(BuildContext context) {
    final premium = context.select<SubscriptionViewModel, bool>((s) => s.isPremium);
    final purchases = context
        .select<PantryViewModel, List<PurchaseRecord>>((p) => p.recentPurchases);
    final report = SpendingReport.build(purchases, _period);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Relatórios', style: context.text.headlineSmall),
                ),
                const PremiumBadge(compact: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ReportPeriod>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ReportPeriod.monthly,
                label: Text('Mensal'),
                icon: Icon(Icons.calendar_month_rounded),
              ),
              ButtonSegment(
                value: ReportPeriod.biweekly,
                label: Text('Quinzenal'),
                icon: Icon(Icons.date_range_rounded),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),
          if (!premium)
            const _LockedReports()
          else ...[
            _TotalCard(report: report),
            const SizedBox(height: 14),
            _CategoryBreakdown(report: report),
            const SizedBox(height: 14),
            _TopItems(report: report),
            const SizedBox(height: 14),
            _PriceChanges(report: report),
          ],
        ],
      ),
    );
  }
}

class _LockedReports extends StatelessWidget {
  const _LockedReports();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: AppTheme.radiusL,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('📊', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            'Descubra para onde vai seu dinheiro',
            textAlign: TextAlign.center,
            style: context.text.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Gastos por categoria, comparação com o período anterior, '
            'produtos que mais pesam no bolso e alertas de aumento de preço.',
            textAlign: TextAlign.center,
            style: context.text.bodyLarge
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          GlowButton(
            label: 'Desbloquear com Premium',
            icon: Icons.lock_open_rounded,
            gradient: AppColors.premiumGradient,
            glowColor: AppColors.gold,
            onPressed: () => PaywallView.open(context),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    final change = report.changeVsPrevious;
    final up = (change ?? 0) > 0;
    return GlassCard(
      radius: AppTheme.radiusL,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${Fmt.dayMonth(report.start)} – ${Fmt.dayMonth(report.end)}',
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              Fmt.currency(report.total),
              style: context.text.displaySmall,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (change != null) ...[
                Icon(
                  up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: up ? AppColors.danger : AppColors.mint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${change.abs().toStringAsFixed(0)}% '
                    '${up ? 'a mais' : 'a menos'} que o período anterior',
                    style: context.text.bodyMedium,
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    '${report.purchaseCount} itens comprados',
                    style: context.text.bodyMedium,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    final entries = report.byCategory.entries.toList();
    final max = entries.isEmpty ? 1.0 : entries.first.value;

    return GlassCard(
      blur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gastos por categoria', style: context.text.titleMedium),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('Sem compras neste período.', style: context.text.bodyMedium)
          else
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${e.key.emoji}  ${e.key.label}',
                            style: context.text.bodyMedium),
                        const Spacer(),
                        Text(Fmt.currency(e.value),
                            style: context.text.labelLarge),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: e.value / max,
                        minHeight: 10,
                        color: e.key.color,
                        backgroundColor: e.key.color.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TopItems extends StatelessWidget {
  const _TopItems({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    if (report.topItems.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      blur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('O que mais pesou no bolso', style: context.text.titleMedium),
          const SizedBox(height: 8),
          for (final (i, e) in report.topItems.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.cyan.withValues(alpha: 0.18),
                child: Text('${i + 1}', style: context.text.labelLarge),
              ),
              title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(Fmt.currency(e.value), style: context.text.labelLarge),
            ),
        ],
      ),
    );
  }
}

class _PriceChanges extends StatelessWidget {
  const _PriceChanges({required this.report});

  final SpendingReport report;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Variação de preços', style: context.text.titleMedium),
          const SizedBox(height: 4),
          Text('Última compra vs anterior', style: context.text.bodySmall),
          const SizedBox(height: 8),
          if (report.priceChanges.isEmpty)
            Text(
              'Compre o mesmo produto mais de uma vez para ver a variação.',
              style: context.text.bodyMedium,
            )
          else
            for (final c in report.priceChanges)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${Fmt.currency(c.previous)} → ${Fmt.currency(c.current)}',
                ),
                trailing: Text(
                  '${c.percent > 0 ? '▲' : '▼'} ${c.percent.abs().toStringAsFixed(1)}%',
                  style: context.text.labelLarge?.copyWith(
                    color: c.percent > 0 ? AppColors.danger : AppColors.mint,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
