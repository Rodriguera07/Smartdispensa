import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/item_category.dart';
import '../../models/shopping_item.dart';
import '../../viewmodels/shopping_list_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';

/// Lista de Compras Inteligente & Interativa.
class ShoppingListView extends StatelessWidget {
  const ShoppingListView({super.key});

  Future<void> _share(BuildContext context) async {
    final vm = context.read<ShoppingListViewModel>();
    if (vm.items.isEmpty) {
      showAppSnack(context, 'Sua lista está vazia', icon: Icons.info_rounded);
      return;
    }
    // Abre a folha nativa (WhatsApp, e-mail, Telegram...).
    await SharePlus.instance.share(
      ShareParams(
        text: vm.buildShareText(),
        subject: 'Lista de Compras — Smart Dispensa',
      ),
    );
  }

  Future<void> _finish(BuildContext context) async {
    final vm = context.read<ShoppingListViewModel>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Text('🛍️', style: TextStyle(fontSize: 40)),
        title: const Text('Finalizar compra?'),
        content: Text(
          '${vm.checkedCount} itens marcados voltarão para sua despensa e '
          'o gasto de ${Fmt.currency(vm.cartTotal)} entrará no resumo do mês.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ainda não'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    HapticFeedback.mediumImpact();
    final summary = vm.finishShopping();
    showAppSnack(
      context,
      '🎉 ${summary.itemCount} itens de volta à despensa'
      '${summary.total > 0 ? ' • ${Fmt.currency(summary.total)}' : ''}',
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final vm = context.read<ShoppingListViewModel>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar lista?'),
        content: const Text('Todos os itens serão removidos da lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (ok == true) vm.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingListViewModel>();

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lista de Compras',
                                style: context.text.headlineSmall),
                            Text(
                              vm.items.isEmpty
                                  ? 'Nada pendente'
                                  : '${vm.pendingCount} pendentes • '
                                      '${vm.checkedCount} no carrinho',
                              style: context.text.bodyMedium?.copyWith(
                                  color: context.colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Compartilhar no WhatsApp',
                        onPressed: () => _share(context),
                        icon: const Icon(Icons.share_rounded),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Mais opções',
                        onSelected: (v) {
                          if (v == 'clear') _confirmClear(context);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'clear',
                            child: Text('Limpar lista'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: _QuickAddField()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      FilterChip(
                        avatar: const Icon(Icons.signpost_rounded, size: 18),
                        label: const Text('Ordenar por corredor'),
                        selected: vm.sortByAisle,
                        showCheckmark: false,
                        selectedColor:
                            context.colors.primary.withValues(alpha: 0.22),
                        onSelected: (_) => vm.toggleSortByAisle(),
                      ),
                    ],
                  ),
                ),
              ),
              if (vm.suggestions.isNotEmpty)
                const SliverToBoxAdapter(child: _SuggestionsStrip()),
              if (!vm.loaded)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (vm.items.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    emoji: '🛒',
                    title: 'Lista vazia',
                    message: 'Itens que acabarem na despensa aparecem aqui '
                        'automaticamente. Você também pode adicionar acima.',
                  ),
                )
              else if (vm.sortByAisle)
                for (final entry in vm.groupedByAisle.entries) ...[
                  SliverToBoxAdapter(
                    child: _AisleHeader(
                      category: entry.key,
                      count: entry.value.length,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: entry.value.length,
                      itemBuilder: (_, i) => _ShoppingTile(
                        key: ValueKey(entry.value[i].id),
                        item: entry.value[i],
                      ),
                    ),
                  ),
                ]
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverList.builder(
                    itemCount: vm.items.length,
                    itemBuilder: (_, i) => _ShoppingTile(
                      key: ValueKey(vm.items[i].id),
                      item: vm.items[i],
                      showCategory: true,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 220)),
            ],
          ),
          // Barra "Finalizar Compra" acima da navegação inferior.
          Positioned(
            left: 12,
            right: 12,
            bottom: 96,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              offset: vm.checkedCount > 0 ? Offset.zero : const Offset(0, 2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: vm.checkedCount > 0 ? 1 : 0,
                child: IgnorePointer(
                  ignoring: vm.checkedCount == 0,
                  child: GlassCard(
                    radius: AppTheme.radiusL,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${vm.checkedCount} no carrinho',
                                  style: context.text.bodySmall),
                              FittedBox(
                                child: Text(Fmt.currency(vm.cartTotal),
                                    style: context.text.titleLarge),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: GlowButton(
                            label: 'Finalizar Compra',
                            icon: Icons.task_alt_rounded,
                            onPressed: () => _finish(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Adição rápida
// =============================================================================

class _QuickAddField extends StatefulWidget {
  const _QuickAddField();

  @override
  State<_QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends State<_QuickAddField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ShoppingListViewModel>().addItem(
          name: text,
          category: ItemCategory.guess(text),
        );
    HapticFeedback.selectionClick();
    _controller.clear();
    _focus.requestFocus(); // permite adicionar vários seguidos
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: const InputDecoration(
                hintText: 'Adicionar item (ex.: Café)',
                prefixIcon: Icon(Icons.add_shopping_cart_rounded),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Adicionar',
            style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, size: 28),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Sugestões inteligentes
// =============================================================================

class _SuggestionsStrip extends StatelessWidget {
  const _SuggestionsStrip();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingListViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.cyan, size: 20),
              const SizedBox(width: 8),
              Text('Você costuma comprar', style: context.text.titleSmall),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vm.suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = vm.suggestions[i];
              return ActionChip(
                avatar: Text(s.category.emoji),
                label: Text('${s.name} · ${s.timesBought}x'),
                side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.5)),
                tooltip: 'Adicionar ${s.name} à lista',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  vm.addSuggestion(s);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Itens
// =============================================================================

class _AisleHeader extends StatelessWidget {
  const _AisleHeader({required this.category, required this.count});

  final ItemCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(category.label, style: context.text.titleMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count', style: context.text.labelSmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingTile extends StatelessWidget {
  const _ShoppingTile({super.key, required this.item, this.showCategory = false});

  final ShoppingItem item;
  final bool showCategory;

  Future<void> _editPrice(BuildContext context) async {
    final vm = context.read<ShoppingListViewModel>();
    final controller = TextEditingController(
      text: item.price?.toStringAsFixed(2).replaceAll('.', ','),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Preço unitário',
            prefixText: r'R$ ',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 48)),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final price = Fmt.parseMoney(result);
    vm.updateItem(
      price == null ? item.copyWith(clearPrice: true) : item.copyWith(price: price),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ShoppingListViewModel>();
    final muted = context.colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('dismiss-${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        onDismissed: (_) => vm.remove(item),
        child: GlassCard(
          blur: false,
          padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
          onTap: () {
            HapticFeedback.selectionClick();
            vm.toggleChecked(item);
          },
          child: Row(
            children: [
              Transform.scale(
                scale: 1.25,
                child: Checkbox(
                  value: item.checked,
                  semanticLabel: item.name,
                  activeColor: context.colors.primary,
                  onChanged: (_) => vm.toggleChecked(item),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(
                        decoration:
                            item.checked ? TextDecoration.lineThrough : null,
                        color: item.checked ? muted : null,
                      ),
                    ),
                    Text(
                      [
                        '${Fmt.quantity(item.quantity)} ${item.unit}',
                        if (showCategory) '${item.category.emoji} ${item.category.label}',
                        if (item.autoAdded) 'acabou na despensa',
                      ].join(' • '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Diminuir quantidade',
                onPressed: item.quantity > 1
                    ? () => vm.updateItem(item.copyWith(quantity: item.quantity - 1))
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              IconButton(
                tooltip: 'Aumentar quantidade',
                onPressed: () =>
                    vm.updateItem(item.copyWith(quantity: item.quantity + 1)),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => _editPrice(context),
                child: Text(
                  item.price != null ? Fmt.currency(item.price!) : '+ R\$',
                  style: context.text.labelMedium?.copyWith(
                    color: item.price != null
                        ? context.colors.onSurface
                        : context.colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
