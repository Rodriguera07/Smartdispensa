import '../core/utils/formatters.dart';
import '../models/item_category.dart';
import '../models/pantry_item.dart';
import '../models/purchase_record.dart';
import '../models/shopping_item.dart';

/// Por que um item aparece no plano da compra do mês.
enum PlanReason {
  /// Zerado na despensa.
  out,

  /// Abaixo de 25% do estoque ideal.
  low,

  /// Comprado no mês passado (sugestão "repetir a compra").
  repeat,
}

class PlanItem {
  PlanItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.reason,
    this.unit = 'un',
    this.price,
    this.selected = true,
  });

  final String name;
  final ItemCategory category;
  final double quantity;
  final String unit;
  final double? price;
  final PlanReason reason;

  /// Marcado para ir à lista (o usuário pode desmarcar na folha).
  bool selected;

  double get estimate => (price ?? 0) * quantity;
  String get key => TextUtils.normalize(name);
}

/// Resultado do planejamento.
class MonthlyPlan {
  const MonthlyPlan({required this.needed, required this.repeat});

  /// Itens em falta ou acabando na despensa.
  final List<PlanItem> needed;

  /// Itens da compra do mês passado que ainda não estão em `needed`.
  final List<PlanItem> repeat;

  int get outCount => needed.where((i) => i.reason == PlanReason.out).length;
  int get lowCount => needed.where((i) => i.reason == PlanReason.low).length;

  Iterable<PlanItem> get all => [...needed, ...repeat];
  Iterable<PlanItem> get selectedItems => all.where((i) => i.selected);

  double get selectedEstimate =>
      selectedItems.fold(0.0, (s, i) => s + i.estimate);

  bool get isEmpty => needed.isEmpty && repeat.isEmpty;
}

/// Monta a "compra do mês" a partir do estoque e do histórico.
///
/// Lógica pura (sem Flutter/Firebase), usada tanto pela folha
/// "Montar compra do mês" quanto pelo texto da notificação.
class ShoppingPlanner {
  const ShoppingPlanner();

  MonthlyPlan build({
    required List<PantryItem> pantry,
    required List<PurchaseRecord> purchases,
    required List<ShoppingItem> shoppingList,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final inList = shoppingList.map((i) => i.normalizedName).toSet();

    // 1) O que falta / está acabando.
    final needed = <PlanItem>[];
    for (final p in pantry) {
      if (!p.isRunningLow || inList.contains(p.normalizedName)) continue;
      final missing = p.idealQuantity - p.quantity;
      needed.add(PlanItem(
        name: p.name,
        category: p.category,
        quantity: missing >= 1 ? missing.ceilToDouble() : 1,
        unit: p.unit,
        price: p.lastPrice,
        reason: p.quantity <= 0 ? PlanReason.out : PlanReason.low,
      ));
    }
    needed.sort((a, b) {
      final r = a.reason.index.compareTo(b.reason.index);
      return r != 0 ? r : a.category.index.compareTo(b.category.index);
    });

    // 2) Repetir a compra do mês passado.
    final prevStart = DateTime(today.year, today.month - 1);
    final prevEnd = DateTime(today.year, today.month);
    var window = purchases
        .where((p) => !p.date.isBefore(prevStart) && p.date.isBefore(prevEnd))
        .toList();
    // Sem histórico no mês anterior? Usa os últimos 30 dias.
    if (window.isEmpty) {
      final since = today.subtract(const Duration(days: 30));
      window = purchases.where((p) => !p.date.isBefore(since)).toList();
    }

    final taken = {...inList, ...needed.map((i) => i.key)};
    final stockByKey = {for (final p in pantry) p.normalizedName: p};
    final aggregated = <String, PlanItem>{};

    // Do mais recente para o mais antigo: o 1º preço visto é o último pago.
    window.sort((a, b) => b.date.compareTo(a.date));
    for (final p in window) {
      final key = p.normalizedName;
      if (taken.contains(key)) continue;
      final prev = aggregated[key];
      if (prev == null) {
        final stock = stockByKey[key];
        aggregated[key] = PlanItem(
          name: p.name,
          category: p.category,
          quantity: p.quantity,
          unit: p.unit,
          price: p.unitPrice > 0 ? p.unitPrice : null,
          reason: PlanReason.repeat,
          // Ainda tem bastante em casa? Sugere, mas desmarcado.
          selected: stock == null || stock.isRunningLow,
        );
      } else {
        aggregated[key] = PlanItem(
          name: prev.name,
          category: prev.category,
          quantity: prev.quantity + p.quantity,
          unit: prev.unit,
          price: prev.price ?? (p.unitPrice > 0 ? p.unitPrice : null),
          reason: PlanReason.repeat,
          selected: prev.selected,
        );
      }
    }

    final repeat = aggregated.values.toList()
      ..sort((a, b) => a.category.index.compareTo(b.category.index));

    return MonthlyPlan(needed: needed, repeat: repeat);
  }
}
