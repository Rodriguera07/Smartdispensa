import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/pantry_item.dart';
import '../../viewmodels/pantry_viewmodel.dart';
import '../../viewmodels/shopping_list_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';
import '../paywall/paywall_view.dart';
import '../pantry/pantry_item_sheet.dart';

/// Dashboard "Início": resumo, alertas de estoque e a despensa.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryViewModel>();
    final items = pantry.visibleItems;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _Header()),
          const SliverToBoxAdapter(child: _SummaryRow()),
          const SliverToBoxAdapter(child: _ScanQuotaBanner()),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Minha Despensa',
              trailing: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => PantryItemSheet.show(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Item'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: pantry.setQuery,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Buscar na despensa...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: CategoryFilterBar(
              selected: pantry.categoryFilter,
              onSelected: pantry.setCategoryFilter,
            ),
          ),
          if (!pantry.loaded)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (items.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                emoji: pantry.items.isEmpty ? '🧺' : '🔍',
                title: pantry.items.isEmpty
                    ? 'Sua despensa está vazia'
                    : 'Nada encontrado',
                message: pantry.items.isEmpty
                    ? 'Escaneie uma nota fiscal no botão verde abaixo ou '
                        'adicione itens manualmente.'
                    : 'Tente outro termo ou categoria.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              // `SliverList.builder` constrói só o que está visível na tela.
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, i) => _PantryItemTile(
                  key: ValueKey(items[i].id),
                  item: items[i],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 130)),
        ],
      ),
    );
  }
}

// =============================================================================
// Cabeçalho
// =============================================================================

class _Header extends StatelessWidget {
  const _Header();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<UserViewModel, String>((u) => u.profile.firstName);
    final premium = context.select<SubscriptionViewModel, bool>((s) => s.isPremium);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}${name.isEmpty ? '' : ', $name'} 👋',
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Veja como está sua despensa hoje',
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (premium)
            const PremiumBadge()
          else
            InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: () => PaywallView.open(context),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: PremiumBadge(label: 'Seja Premium'),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Cards de resumo (Glassmorphism)
// =============================================================================

class _SummaryRow extends StatelessWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryViewModel>();

    final cards = [
      _SummaryCard(
        icon: Icons.inventory_2_rounded,
        color: AppColors.mint,
        label: 'Total na Despensa',
        value: '${pantry.inStockCount}',
        caption: 'itens',
      ),
      _SummaryCard(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        label: 'Acabando / Em Falta',
        value: '${pantry.lowStockCount}',
        caption: 'itens',
      ),
      _SummaryCard(
        icon: Icons.payments_rounded,
        color: AppColors.cyan,
        label: 'Gasto no Mês',
        value: Fmt.currency(pantry.monthSpend),
        caption: Fmt.monthYear(DateTime.now()),
      ),
    ];

    // Com fonte muito grande (acessibilidade), empilha os cards.
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: largeText
          ? Column(
              children: [
                for (final c in cards)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
              ],
            )
          : Column(
              children: [
                // Gasto do mês em destaque, largura total.
                _SummaryCard(
                  icon: Icons.payments_rounded,
                  color: AppColors.cyan,
                  label: 'Gasto no Mês',
                  value: Fmt.currency(pantry.monthSpend),
                  caption: Fmt.monthYear(DateTime.now()),
                  wide: true,
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[1]),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  Widget _wideLayout(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelMedium),
              Text(caption, style: context.text.bodySmall),
            ],
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: context.text.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.caption,
    this.wide = false,
  });

  /// Layout horizontal, para o card em largura total.
  final bool wide;
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      semanticLabel: '$label: $value $caption',
      child: ExcludeSemantics(
        child: wide ? _wideLayout(context) : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              style: context.text.labelMedium,
            ),
            Text(caption, maxLines: 1, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Cota de scans (plano Grátis)
// =============================================================================

class _ScanQuotaBanner extends StatelessWidget {
  const _ScanQuotaBanner();

  @override
  Widget build(BuildContext context) {
    final premium = context.select<SubscriptionViewModel, bool>((s) => s.isPremium);
    if (premium) return const SizedBox.shrink();
    final remaining = context.select<UserViewModel, int>(
      (u) => u.scansRemaining(isPremium: false),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        blur: false,
        onTap: () => PaywallView.open(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderColor: AppColors.gold.withValues(alpha: 0.4),
        child: Row(
          children: [
            const Icon(Icons.document_scanner_rounded, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                remaining > 0
                    ? '$remaining de ${AppConstants.freeScansPerMonth} '
                        'escaneamentos grátis restantes este mês'
                    : 'Você usou seus escaneamentos grátis deste mês',
                style: context.text.bodyMedium,
              ),
            ),
            Text(
              'Ilimitado ✨',
              style: context.text.labelMedium?.copyWith(color: AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Item da despensa
// =============================================================================

class _PantryItemTile extends StatelessWidget {
  const _PantryItemTile({super.key, required this.item});

  final PantryItem item;

  Future<void> _useOne(BuildContext context) async {
    HapticFeedback.lightImpact();
    final pantry = context.read<PantryViewModel>();
    final shopping = context.read<ShoppingListViewModel>();
    final user = context.read<UserViewModel>();

    final finished = pantry.useOne(item);
    if (!finished) return;

    if (user.profile.autoSendToList) {
      shopping.addFromPantry(item, auto: true);
      showAppSnack(context, '${item.name} acabou e foi para a lista 🛒',
          icon: Icons.shopping_cart_checkout_rounded);
      return;
    }

    var always = false;
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          icon: Text(item.category.emoji, style: const TextStyle(fontSize: 40)),
          title: Text('${item.name} acabou!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Quer adicionar à sua lista de compras?'),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: always,
                onChanged: (v) => setState(() => always = v ?? false),
                title: const Text('Sempre enviar automaticamente'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Agora não'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );

    if (always) user.setAutoSendToList(true);
    if (send == true) {
      shopping.addFromPantry(item, auto: true);
      if (context.mounted) {
        showAppSnack(context, '${item.name} adicionado à lista 🛒');
      }
    }
  }

  void _addToList(BuildContext context) {
    HapticFeedback.selectionClick();
    final added = context.read<ShoppingListViewModel>().addFromPantry(item);
    showAppSnack(
      context,
      added ? '${item.name} adicionado à lista 🛒' : '${item.name} já está na lista',
      icon: added ? Icons.check_circle_rounded : Icons.info_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = StockLevelBar.colorFor(item.level);
    final statusText = switch (item.level) {
      StockLevel.out => 'Em falta',
      StockLevel.low => 'Acabando',
      StockLevel.ok => 'Em estoque',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        blur: false, // performance em listas
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        onTap: () => PantryItemSheet.show(context, item: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.category.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(item.category.emoji,
                      style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.quantity(item.quantity)} de '
                        '${Fmt.quantity(item.idealQuantity)} ${item.unit}'
                        '${item.lastPrice != null ? ' • ${Fmt.currency(item.lastPrice!)}' : ''}',
                        style: context.text.bodyMedium
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Text(
                    statusText,
                    style: context.text.labelSmall?.copyWith(color: levelColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StockLevelBar(ratio: item.levelRatio, level: item.level),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                    ),
                    onPressed:
                        item.quantity > 0 ? () => _useOne(context) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    label: const Text('Usar (-1)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                    ),
                    onPressed: () => _addToList(context),
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const FittedBox(child: Text('Adicionar à Lista')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
