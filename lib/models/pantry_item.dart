import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import 'item_category.dart';

/// Nível de estoque de um item, usado para cores e alertas.
enum StockLevel { out, low, ok }

/// Item da despensa do usuário.
///
/// Firestore: `users/{uid}/pantry/{id}`
class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.idealQuantity,
    this.unit = 'un',
    this.lastPrice,
    this.updatedAt,
  });

  final String id;
  final String name;
  final ItemCategory category;

  /// Quantidade atual (double para suportar itens a granel: 0,345 kg).
  final double quantity;

  /// Quantidade que o usuário gosta de manter em casa. Base da barra de nível.
  final double idealQuantity;

  final String unit;
  final double? lastPrice;
  final DateTime? updatedAt;

  /// Chave de comparação (sem acento/caixa) para mesclar itens iguais.
  String get normalizedName => TextUtils.normalize(name);

  /// Proporção 0..1 em relação ao estoque ideal.
  double get levelRatio {
    if (idealQuantity <= 0) return quantity > 0 ? 1 : 0;
    return (quantity / idealQuantity).clamp(0.0, 1.0);
  }

  StockLevel get level {
    if (quantity <= 0) return StockLevel.out;
    if (levelRatio <= AppConstants.lowStockRatio) return StockLevel.low;
    return StockLevel.ok;
  }

  bool get isRunningLow => level != StockLevel.ok;

  PantryItem copyWith({
    String? name,
    ItemCategory? category,
    double? quantity,
    double? idealQuantity,
    String? unit,
    double? lastPrice,
  }) {
    return PantryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      idealQuantity: idealQuantity ?? this.idealQuantity,
      unit: unit ?? this.unit,
      lastPrice: lastPrice ?? this.lastPrice,
      updatedAt: updatedAt,
    );
  }

  factory PantryItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PantryItem(
      id: doc.id,
      name: (d['name'] as String?) ?? 'Item',
      category: ItemCategory.fromName(d['category'] as String?),
      quantity: (d['quantity'] as num?)?.toDouble() ?? 0,
      idealQuantity: (d['idealQuantity'] as num?)?.toDouble() ?? 1,
      unit: (d['unit'] as String?) ?? 'un',
      lastPrice: (d['lastPrice'] as num?)?.toDouble(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'normalizedName': normalizedName,
        'category': category.name,
        'quantity': quantity,
        'idealQuantity': idealQuantity,
        'unit': unit,
        if (lastPrice != null) 'lastPrice': lastPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
