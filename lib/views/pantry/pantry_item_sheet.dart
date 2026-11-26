import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/item_category.dart';
import '../../models/pantry_item.dart';
import '../../viewmodels/pantry_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/common_widgets.dart';
import '../paywall/paywall_view.dart';
import 'price_history_sheet.dart';

/// Folha para adicionar ou editar um item da despensa (estoque manual
/// ilimitado em todos os planos).
class PantryItemSheet extends StatefulWidget {
  const PantryItemSheet({super.key, this.item});

  final PantryItem? item;

  static Future<void> show(BuildContext context, {PantryItem? item}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PantryItemSheet(item: item),
    );
  }

  @override
  State<PantryItemSheet> createState() => _PantryItemSheetState();
}

class _PantryItemSheetState extends State<PantryItemSheet> {
  static const _units = ['un', 'kg', 'g', 'l', 'ml', 'pct', 'cx'];

  late final TextEditingController _name =
      TextEditingController(text: widget.item?.name);
  late final TextEditingController _price = TextEditingController(
    text: widget.item?.lastPrice?.toStringAsFixed(2).replaceAll('.', ','),
  );
  late ItemCategory _category = widget.item?.category ?? ItemCategory.outros;
  late double _quantity = widget.item?.quantity ?? 1;
  late double _ideal = widget.item?.idealQuantity ?? 2;
  late String _unit =
      _units.contains(widget.item?.unit) ? widget.item!.unit : 'un';

  /// Enquanto o usuário não escolher a categoria, ela é sugerida pelo nome.
  bool _categoryTouched = false;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (_categoryTouched || _isEdit) return;
    final guess = ItemCategory.guess(value);
    if (guess != _category) setState(() => _category = guess);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnack(context, 'Informe o nome do item', icon: Icons.info_rounded);
      return;
    }
    final pantry = context.read<PantryViewModel>();
    final price = Fmt.parseMoney(_price.text);

    final item = PantryItem(
      id: widget.item?.id ?? '',
      name: name,
      category: _category,
      quantity: _quantity,
      idealQuantity: _ideal < 1 ? 1 : _ideal,
      unit: _unit,
      lastPrice: price,
    );

    if (_isEdit) {
      pantry.updateItem(item);
    } else {
      pantry.addItem(item);
    }
    Navigator.pop(context);
    showAppSnack(context, _isEdit ? 'Item atualizado' : '$name adicionado à despensa');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover item?'),
        content: Text('"${widget.item!.name}" sairá da sua despensa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 48),
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<PantryViewModel>().deleteItem(widget.item!);
    Navigator.pop(context);
  }

  void _openPriceHistory() {
    final premium = context.read<SubscriptionViewModel>().isPremium;
    if (!premium) {
      PaywallView.open(context);
      return;
    }
    PriceHistorySheet.show(context, widget.item!.name);
  }

  @override
  Widget build(BuildContext context) {
    final step = _unit == 'kg' || _unit == 'l' ? 0.5 : 1.0;
    final premium = context.select<SubscriptionViewModel, bool>((s) => s.isPremium);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Editar item' : 'Novo item na despensa',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onNameChanged,
              decoration: const InputDecoration(
                labelText: 'Nome do produto',
                hintText: 'Ex.: Arroz 5kg',
              ),
            ),
            const SizedBox(height: 14),
            CategoryDropdown(
              key: ValueKey(_category),
              value: _category,
              onChanged: (c) => setState(() {
                _category = c;
                _categoryTouched = true;
              }),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Preço (opcional)',
                      prefixText: r'R$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unidade'),
                    items: [
                      for (final u in _units)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (u) => setState(() => _unit = u ?? 'un'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _StepperRow(
              label: 'Quantidade em casa',
              child: QuantityStepper(
                label: 'quantidade',
                value: _quantity,
                step: step,
                onChanged: (v) => setState(() => _quantity = v),
              ),
            ),
            const SizedBox(height: 10),
            _StepperRow(
              label: 'Estoque ideal',
              hint: 'Quanto você gosta de ter',
              child: QuantityStepper(
                label: 'estoque ideal',
                value: _ideal,
                min: 1,
                step: step,
                onChanged: (v) => setState(() => _ideal = v),
              ),
            ),
            const SizedBox(height: 24),
            GlowButton(
              label: _isEdit ? 'Salvar alterações' : 'Adicionar à despensa',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
            if (_isEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openPriceHistory,
                icon: const Icon(Icons.show_chart_rounded),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Histórico de preços'),
                    if (!premium) ...[
                      const SizedBox(width: 8),
                      const PremiumBadge(compact: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remover da despensa'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.titleSmall),
              if (hint != null) Text(hint!, style: t.bodySmall),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
