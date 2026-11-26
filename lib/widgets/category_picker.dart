import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../models/item_category.dart';

/// Campo de seleção de categoria com emoji (dropdown acessível).
class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final ItemCategory value;
  final ValueChanged<ItemCategory> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ItemCategory>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: dense ? null : 'Categoria',
        isDense: dense,
        contentPadding: dense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : null,
      ),
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      items: [
        for (final c in ItemCategory.values)
          DropdownMenuItem(
            value: c,
            child: Text('${c.emoji}  ${c.label}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (c) {
        if (c != null) onChanged(c);
      },
    );
  }
}

/// Faixa horizontal de filtros por categoria.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ItemCategory? selected;
  final ValueChanged<ItemCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(context, null, 'Todos'),
          for (final c in ItemCategory.values) _chip(context, c, '${c.emoji} ${c.label}'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, ItemCategory? c, String label) {
    final isSelected = selected == c;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        selectedColor: context.colors.primary.withValues(alpha: 0.22),
        onSelected: (_) => onSelected(c),
      ),
    );
  }
}
