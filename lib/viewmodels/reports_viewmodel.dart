import '../models/item_category.dart';
import '../models/purchase_record.dart';

enum ReportPeriod { monthly, biweekly }

/// Variação de preço de um produto entre as duas últimas compras.
class PriceChange {
  const PriceChange(this.name, this.previous, this.current);
  final String name;
  final double previous;
  final double current;
  double get percent => previous == 0 ? 0 : (current - previous) / previous * 100;
}

/// Relatório de gastos de um período (cálculo puro, sem estado).
class SpendingReport {
  SpendingReport._({
    required this.start,
    required this.end,
    required this.total,
    required this.previousTotal,
    required this.byCategory,
    required this.topItems,
    required this.priceChanges,
    required this.purchaseCount,
  });

  final DateTime start;
  final DateTime end;
  final double total;
  final double previousTotal;
  final Map<ItemCategory, double> byCategory;
  final List<MapEntry<String, double>> topItems;
  final List<PriceChange> priceChanges;
  final int purchaseCount;

  /// Variação do total em relação ao período anterior (%).
  double? get changeVsPrevious =>
      previousTotal <= 0 ? null : (total - previousTotal) / previousTotal * 100;

  /// Monta o relatório do período corrente.
  ///
  /// - Mensal: do dia 1 até o fim do mês.
  /// - Quinzenal: 1–15 ou 16–fim do mês, conforme a data de hoje.
  factory SpendingReport.build(
    List<PurchaseRecord> purchases,
    ReportPeriod period, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    late DateTime start, end, prevStart;

    if (period == ReportPeriod.monthly) {
      start = DateTime(today.year, today.month);
      end = DateTime(today.year, today.month + 1);
      prevStart = DateTime(today.year, today.month - 1);
    } else if (today.day <= 15) {
      start = DateTime(today.year, today.month);
      end = DateTime(today.year, today.month, 16);
      prevStart = DateTime(today.year, today.month - 1, 16);
    } else {
      start = DateTime(today.year, today.month, 16);
      end = DateTime(today.year, today.month + 1);
      prevStart = DateTime(today.year, today.month);
    }

    bool inRange(DateTime d, DateTime a, DateTime b) =>
        !d.isBefore(a) && d.isBefore(b);

    final current = purchases.where((p) => inRange(p.date, start, end)).toList();
    final previous =
        purchases.where((p) => inRange(p.date, prevStart, start)).toList();

    final byCategory = <ItemCategory, double>{};
    final byItem = <String, double>{};
    for (final p in current) {
      byCategory[p.category] = (byCategory[p.category] ?? 0) + p.total;
      byItem[p.name] = (byItem[p.name] ?? 0) + p.total;
    }

    final sortedCategories = Map.fromEntries(
      byCategory.entries.where((e) => e.value > 0).toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
    final topItems = byItem.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Variação de preços: última vs penúltima compra (lista já vem do mais
    // recente para o mais antigo).
    final seen = <String, PurchaseRecord>{};
    final changes = <PriceChange>[];
    final done = <String>{};
    for (final p in purchases.where((p) => p.unitPrice > 0)) {
      final key = p.normalizedName;
      if (done.contains(key)) continue;
      final latest = seen[key];
      if (latest == null) {
        seen[key] = p;
      } else if ((latest.unitPrice - p.unitPrice).abs() >= 0.01) {
        changes.add(PriceChange(latest.name, p.unitPrice, latest.unitPrice));
        done.add(key);
      }
    }
    changes.sort((a, b) => b.percent.abs().compareTo(a.percent.abs()));

    return SpendingReport._(
      start: start,
      end: end.subtract(const Duration(days: 1)),
      total: current.fold(0.0, (s, p) => s + p.total),
      previousTotal: previous.fold(0.0, (s, p) => s + p.total),
      byCategory: sortedCategories,
      topItems: topItems.take(5).toList(),
      priceChanges: changes.take(6).toList(),
      purchaseCount: current.length,
    );
  }
}
