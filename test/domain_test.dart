import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_dispensa/core/utils/formatters.dart';
import 'package:smart_dispensa/models/item_category.dart';
import 'package:smart_dispensa/models/pantry_item.dart';
import 'package:smart_dispensa/models/purchase_record.dart';
import 'package:smart_dispensa/viewmodels/reports_viewmodel.dart';

PurchaseRecord _p(String name, double price, DateTime date,
        {ItemCategory c = ItemCategory.mercearia, double qty = 1}) =>
    PurchaseRecord(
      id: name,
      name: name,
      category: c,
      quantity: qty,
      unitPrice: price,
      date: date,
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Formatação', () {
    test('moeda em reais', () {
      expect(Fmt.currency(1299.9).replaceAll(' ', ' '), r'R$ 1.299,90');
    });

    test('parse de valores digitados', () {
      expect(Fmt.parseMoney('12,90'), 12.90);
      expect(Fmt.parseMoney(r'R$ 1.299,90'), 1299.90);
      expect(Fmt.parseMoney('4.5'), 4.5);
      expect(Fmt.parseMoney(''), isNull);
    });

    test('normalização remove acentos e caixa', () {
      expect(TextUtils.normalize('Café Pilão 500g'), 'cafe pilao 500g');
    });
  });

  group('Categorias', () {
    test('classifica produtos comuns', () {
      expect(ItemCategory.guess('Sabonete Dove'), ItemCategory.higiene);
      expect(ItemCategory.guess('Água Sanitária Qboa'), ItemCategory.limpeza);
      expect(ItemCategory.guess('Refrigerante Guaraná 2L'), ItemCategory.bebidas);
      expect(ItemCategory.guess('Queijo Mussarela'), ItemCategory.laticinios);
      expect(ItemCategory.guess('Tomate Italiano'), ItemCategory.hortifruti);
      expect(ItemCategory.guess('Feijão Carioca 1kg'), ItemCategory.mercearia);
      expect(ItemCategory.guess('Xpto'), ItemCategory.outros);
    });
  });

  group('Nível de estoque', () {
    PantryItem item(double q, double ideal) => PantryItem(
          id: '1',
          name: 'Arroz',
          category: ItemCategory.mercearia,
          quantity: q,
          idealQuantity: ideal,
        );

    test('em falta, acabando e ok', () {
      expect(item(0, 4).level, StockLevel.out);
      expect(item(1, 4).level, StockLevel.low);
      expect(item(3, 4).level, StockLevel.ok);
    });
  });

  group('Relatórios', () {
    final now = DateTime(2026, 11, 20);
    final purchases = [
      _p('Café', 19.90, DateTime(2026, 11, 18)),
      _p('Leite', 5.50, DateTime(2026, 11, 17), c: ItemCategory.laticinios, qty: 6),
      _p('Café', 17.90, DateTime(2026, 11, 3)),
      _p('Arroz', 25.00, DateTime(2026, 10, 10)),
    ];

    test('mensal soma o mês corrente e compara com o anterior', () {
      final r = SpendingReport.build(purchases, ReportPeriod.monthly, now: now);
      expect(r.total, closeTo(19.90 + 33.0 + 17.90, 0.001));
      expect(r.previousTotal, 25.0);
      expect(r.byCategory.keys.first, ItemCategory.mercearia);
    });

    test('quinzenal usa a segunda quinzena', () {
      final r = SpendingReport.build(purchases, ReportPeriod.biweekly, now: now);
      expect(r.start, DateTime(2026, 11, 16));
      expect(r.total, closeTo(19.90 + 33.0, 0.001));
    });

    test('detecta variação de preço', () {
      final r = SpendingReport.build(purchases, ReportPeriod.monthly, now: now);
      final cafe = r.priceChanges.single;
      expect(cafe.previous, 17.90);
      expect(cafe.current, 19.90);
      expect(cafe.percent, greaterThan(11));
    });
  });
}
