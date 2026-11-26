import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/formatters.dart';
import 'item_category.dart';

/// Item da lista de compras.
///
/// Firestore: `users/{uid}/shopping_list/{id}`
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    this.quantity = 1,
    this.unit = 'un',
    this.checked = false,
    this.price,
    this.pantryItemId,
    this.autoAdded = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final ItemCategory category;
  final double quantity;
  final String unit;

  /// Marcado como "já no carrinho".
  final bool checked;

  /// Preço unitário pago (opcional) — alimenta o "Gasto no Mês".
  final double? price;

  /// Item da despensa de origem (quando veio automaticamente do estoque).
  final String? pantryItemId;

  /// `true` quando entrou sozinho na lista porque acabou na despensa.
  final bool autoAdded;

  final DateTime? createdAt;

  String get normalizedName => TextUtils.normalize(name);

  double get lineTotal => (price ?? 0) * quantity;

  ShoppingItem copyWith({
    String? name,
    ItemCategory? category,
    double? quantity,
    String? unit,
    bool? checked,
    double? price,
    bool clearPrice = false,
  }) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      checked: checked ?? this.checked,
      price: clearPrice ? null : (price ?? this.price),
      pantryItemId: pantryItemId,
      autoAdded: autoAdded,
      createdAt: createdAt,
    );
  }

  factory ShoppingItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ShoppingItem(
      id: doc.id,
      name: (d['name'] as String?) ?? 'Item',
      category: ItemCategory.fromName(d['category'] as String?),
      quantity: (d['quantity'] as num?)?.toDouble() ?? 1,
      unit: (d['unit'] as String?) ?? 'un',
      checked: (d['checked'] as bool?) ?? false,
      price: (d['price'] as num?)?.toDouble(),
      pantryItemId: d['pantryItemId'] as String?,
      autoAdded: (d['autoAdded'] as bool?) ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'normalizedName': normalizedName,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'checked': checked,
        'price': price,
        'pantryItemId': pantryItemId,
        'autoAdded': autoAdded,
        // Timestamp do cliente (e não serverTimestamp) para que a ordenação
        // funcione imediatamente também quando o usuário está offline.
        'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      };
}
