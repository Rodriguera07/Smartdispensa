import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/receipt_item.dart';
import '../../viewmodels/scanner_viewmodel.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';

/// Tela de **Pré-Validação**: o usuário confere e corrige nomes, quantidades,
/// preços e categorias lidos pelo OCR antes de salvar no Firestore.
class ReceiptReviewView extends StatelessWidget {
  const ReceiptReviewView({super.key, required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScannerViewModel>();
    final items = vm.items;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            // +2: cabeçalho e botão "adicionar item".
            itemCount: items.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) return const _ReviewHeader();
              if (i == items.length + 1) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: vm.addEmptyItem,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Adicionar item que faltou'),
                  ),
                );
              }
              final item = items[i - 1];
              return _ReviewItemCard(key: ObjectKey(item), item: item);
            },
          ),
        ),
        _SaveBar(onSave: onSave),
      ],
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScannerViewModel>();
    final detected = vm.detectedTotal;
    final sum = vm.includedTotal;
    final mismatch = detected != null && (detected - sum).abs() > 0.5;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppColors.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    vm.storeName ?? 'Nota fiscal',
                    style: context.text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Confira os itens abaixo. Toque em qualquer campo para corrigir.',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            if (detected != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    mismatch ? Icons.info_rounded : Icons.verified_rounded,
                    size: 20,
                    color: mismatch ? AppColors.warning : AppColors.mint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mismatch
                          ? 'Total da nota: ${Fmt.currency(detected)} • '
                              'Soma dos itens: ${Fmt.currency(sum)}. '
                              'Verifique se falta algum item.'
                          : 'Total confere com a nota: ${Fmt.currency(detected)}',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({super.key, required this.item});

  final ReceiptItem item;

  String _num(double v) =>
      v == 0 ? '' : Fmt.quantity(v);

  String _money(double v) =>
      v == 0 ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ScannerViewModel>();
    // Rebuild somente deste card quando o total dele mudar.
    context.select<ScannerViewModel, Object>(
      (_) => (item.include, item.total, item.category),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: item.include ? 1 : 0.5,
        child: GlassCard(
          blur: false,
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: item.include,
                    semanticLabel: 'Incluir ${item.name}',
                    onChanged: (v) => vm.updateItem(item, include: v ?? true),
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: item.name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Produto',
                        isDense: true,
                      ),
                      onChanged: (v) => vm.updateItem(item, name: v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover item',
                    onPressed: () => vm.removeItem(item),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: _num(item.quantity),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Qtd',
                          suffixText: item.unit,
                          isDense: true,
                        ),
                        onChanged: (v) => vm.updateItem(
                          item,
                          quantity: Fmt.parseMoney(v) ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        initialValue: _money(item.unitPrice),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Preço un.',
                          prefixText: r'R$ ',
                          isDense: true,
                        ),
                        onChanged: (v) => vm.updateItem(
                          item,
                          unitPrice: Fmt.parseMoney(v) ?? 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Total', style: context.text.bodySmall),
                          FittedBox(
                            child: Text(
                              Fmt.currency(item.total),
                              style: context.text.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: CategoryDropdown(
                  dense: true,
                  value: item.category,
                  onChanged: (c) => vm.updateItem(item, category: c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScannerViewModel>();
    return GlassCard(
      radius: AppTheme.radiusL,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${vm.includedCount} itens', style: context.text.bodySmall),
                FittedBox(
                  child: Text(
                    Fmt.currency(vm.includedTotal),
                    style: context.text.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GlowButton(
              label: 'Salvar na despensa',
              icon: Icons.inventory_2_rounded,
              onPressed: vm.includedCount > 0 ? onSave : null,
            ),
          ),
        ],
      ),
    );
  }
}
