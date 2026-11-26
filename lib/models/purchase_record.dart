import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/formatters.dart';
import 'item_category.dart';

/// Origem de uma compra registrada.
enum PurchaseSource { receipt, shoppingList, manual }

/// Registro histórico de compra de um produto.
///
/// É a base de três funcionalidades:
/// - **Gasto no Mês** (soma de `total` no período);
/// - **Sugestão Inteligente** (itens recorrentes);
/// - **Histórico de variação de preços** (Premium).
///
/// Firestore: `users/{uid}/purchases/{id}`
class PurchaseRecord {
  const PurchaseRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.date,
    this.unit = 'un',
    this.source = PurchaseSource.manual,
    this.store,
  });

  final String id;
  final String name;
  final ItemCategory category;
  final double quantity;
  final String unit;
  final double unitPrice;
  final DateTime date;
  final PurchaseSource source;

  /// Nome do mercado, quando detectado na nota.
  final String? store;

  double get total => unitPrice * quantity;
  String get normalizedName => TextUtils.normalize(name);

  factory PurchaseRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PurchaseRecord(
      id: doc.id,
      name: (d['name'] as String?) ?? 'Item',
      category: ItemCategory.fromName(d['category'] as String?),
      quantity: (d['quantity'] as num?)?.toDouble() ?? 1,
      unit: (d['unit'] as String?) ?? 'un',
      unitPrice: (d['unitPrice'] as num?)?.toDouble() ?? 0,
      // Escritas offline ainda não têm timestamp do servidor: usamos "agora".
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: PurchaseSource.values.firstWhere(
        (s) => s.name == d['source'],
        orElse: () => PurchaseSource.manual,
      ),
      store: d['store'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'normalizedName': normalizedName,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'total': total,
        'date': Timestamp.fromDate(date),
        'source': source.name,
        if (store != null) 'store': store,
      };
}
