import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../services/shopping_planner.dart';
import '../../viewmodels/reminder_viewmodel.dart';
import '../../viewmodels/shopping_list_viewmodel.dart';
import '../../widgets/common_widgets.dart';

/// Folha "Montar compra do mês": junta o que falta na despensa com a compra
/// do mês passado. O usuário marca/desmarca e envia tudo para a lista.
///
/// É aberta pelo cartão da Lista de Compras e pelo toque no lembrete mensal.
class MonthlyPlanSheet extends StatefulWidget {
  const MonthlyPlanSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const MonthlyPlanSheet(),
    );
  }

  @override
  State<MonthlyPlanSheet> createState() => _MonthlyPlanSheetState();
}

class _MonthlyPlanSheetState extends State<MonthlyPlanSheet> {
  late final MonthlyPlan _plan = context.read<ReminderViewModel>().buildPlan();

  void _toggleAll(List<PlanItem> items, bool value) => setState(() {
        for (final i in items) {
          i.selected = value;
        }
      });

  void _addToList() {
    final selected = _plan.selectedItems.toList();
    final shopping = context.read<ShoppingListViewModel>();
    for (final i in selected) {
      shopping.addItem(
        name: i.name,
        category: i.category,
        quantity: i.quantity,
        unit: i.unit,
        price: i.price,
      );
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    showAppSnack(context, '🛒 ${selected.length} itens adicionados à lista');
  }

  @override
  Widget build(BuildContext context) {
    final count = _plan.selectedItems.length;
    final estimate = _plan.selectedEstimate;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                Text('🛒 Compra do mês', style: context.text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Escolha o que vai para a lista. Já deixamos marcado o que '
                  'parece faltar.',
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                if (_plan.isEmpty)
                  const EmptyState(
                    emoji: '🎉',
                    title: 'Tudo em dia!',
                    message: 'Nada em falta na despensa e nenhuma compra '
                        'recente para repetir.',
                  ),
                if (_plan.needed.isNotEmpty)
                  _Section(
                    title: 'Precisa repor',
                    subtitle: [
                      if (_plan.outCount > 0) '${_plan.outCount} em falta',
                      if (_plan.lowCount > 0) '${_plan.lowCount} acabando',
                    ].join(' • '),
                    items: _plan.needed,
                    onToggleAll: (v) => _toggleAll(_plan.needed, v),
                    onChanged: () => setState(() {}),
                  ),
                if (_plan.repeat.isNotEmpty)
                  _Section(
                    title: 'Repetir a compra do mês passado',
                    subtitle: 'Desmarcados: você ainda tem bastante em casa',
                    items: _plan.repeat,
                    onToggleAll: (v) => _toggleAll(_plan.repeat, v),
                    onChanged: () => setState(() {}),
                  ),
                const _ReminderNudge(),
              ],
            ),
          ),
          if (!_plan.isEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: GlowButton(
                  label: count == 0
                      ? 'Selecione itens'
                      : 'Adicionar $count itens'
                          '${estimate > 0 ? ' • ≈ ${Fmt.currency(estimate)}' : ''}',
                  icon: Icons.playlist_add_check_rounded,
                  onPressed: count == 0 ? null : _addToList,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onToggleAll,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final List<PlanItem> items;
  final ValueChanged<bool> onToggleAll;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final allSelected = items.every((i) => i.selected);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: context.text.bodySmall),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onToggleAll(!allSelected),
                child: Text(allSelected ? 'Desmarcar' : 'Marcar todos'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items) _PlanTile(item: item, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.item, required this.onChanged});

  final PlanItem item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (item.reason) {
      PlanReason.out => ('Em falta', AppColors.danger),
      PlanReason.low => ('Acabando', AppColors.warning),
      PlanReason.repeat => ('Mês passado', AppColors.cyan),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: context.colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: CheckboxListTile(
        value: item.selected,
        onChanged: (v) {
          HapticFeedback.selectionClick();
          item.selected = v ?? false;
          onChanged();
        },
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          '${item.category.emoji}  ${item.name}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: context.text.labelSmall?.copyWith(color: color),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${Fmt.quantity(item.quantity)} ${item.unit}'
                '${item.price != null ? ' • ${Fmt.currency(item.estimate)}' : ''}',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convite para ligar o lembrete, caso ainda esteja desligado.
class _ReminderNudge extends StatelessWidget {
  const _ReminderNudge();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReminderViewModel>();
    final s = vm.settings;
    if (s.anyEnabled || !vm.notificationsSupported) return const SizedBox.shrink();

    return Card(
      color: AppColors.mint.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        side: BorderSide(color: AppColors.mint.withValues(alpha: 0.4)),
      ),
      child: SwitchListTile(
        secondary: const Icon(Icons.notifications_active_rounded,
            color: AppColors.mint),
        title: Text('Lembrar todo dia ${s.startDay}'),
        subtitle: const Text('Aviso com o que falta e a estimativa de gasto'),
        value: false,
        onChanged: (_) async {
          final ok = await vm.update(s.copyWith(startEnabled: true));
          if (!context.mounted) return;
          showAppSnack(
            context,
            ok
                ? 'Lembrete ligado para todo dia ${s.startDay} 🔔'
                : 'Permita as notificações nas configurações do Android',
            icon: ok ? Icons.notifications_active_rounded : Icons.info_rounded,
          );
        },
      ),
    );
  }
}
