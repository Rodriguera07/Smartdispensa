import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_dispensa/models/item_category.dart';
import 'package:smart_dispensa/models/pantry_item.dart';
import 'package:smart_dispensa/models/purchase_record.dart';
import 'package:smart_dispensa/models/reminder_settings.dart';
import 'package:smart_dispensa/models/shopping_item.dart';
import 'package:smart_dispensa/services/notification_service.dart';
import 'package:smart_dispensa/services/shopping_planner.dart';

PantryItem _stock(String name, double q, double ideal, {double? price}) =>
    PantryItem(
      id: name,
      name: name,
      category: ItemCategory.guess(name),
      quantity: q,
      idealQuantity: ideal,
      lastPrice: price,
    );

PurchaseRecord _bought(String name, double q, double price, DateTime date) =>
    PurchaseRecord(
      id: '$name$date',
      name: name,
      category: ItemCategory.guess(name),
      quantity: q,
      unitPrice: price,
      date: date,
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('ReminderSettings', () {
    const s = ReminderSettings(startEnabled: true, startDay: 5, hour: 9);

    test('próximo lembrete ainda neste mês', () {
      expect(s.nextOccurrence(5, DateTime(2026, 11, 2, 10)),
          DateTime(2026, 11, 5, 9));
    });

    test('se já passou, vai para o mês seguinte (inclusive virada de ano)', () {
      expect(s.nextOccurrence(5, DateTime(2026, 12, 5, 9, 30)),
          DateTime(2027, 1, 5, 9));
    });

    test('nextReminder escolhe o mais próximo dos ativos', () {
      final both = s.copyWith(endEnabled: true, endDay: 28);
      expect(both.nextReminder(DateTime(2026, 11, 10)), DateTime(2026, 11, 28, 9));
      expect(const ReminderSettings().nextReminder(DateTime(2026, 11, 10)), isNull);
    });

    test('dias fora de 1..28 são corrigidos ao ler do banco', () {
      final r = ReminderSettings.fromMap({'startDay': 31, 'endDay': 0});
      expect(r.startDay, 28);
      expect(r.endDay, 1);
    });
  });

  group('ShoppingPlanner', () {
    final now = DateTime(2026, 11, 5);
    const planner = ShoppingPlanner();

    final plan = planner.build(
      now: now,
      pantry: [
        _stock('Café Pilão', 0, 2, price: 19.90), // em falta
        _stock('Leite Integral', 2, 12, price: 4.99), // acabando
        _stock('Arroz 5kg', 2, 2, price: 25.90), // ok
        _stock('Detergente', 0, 3, price: 2.49), // em falta, mas já na lista
      ],
      shoppingList: const [
        ShoppingItem(id: 'x', name: 'Detergente', category: ItemCategory.limpeza),
      ],
      purchases: [
        _bought('Café Pilão', 2, 19.90, DateTime(2026, 10, 3)),
        _bought('Arroz 5kg', 1, 25.90, DateTime(2026, 10, 3)),
        _bought('Banana Prata', 1.2, 5.99, DateTime(2026, 10, 12)),
        _bought('Banana Prata', 1.0, 6.49, DateTime(2026, 10, 20)),
        _bought('Iogurte', 4, 3.29, DateTime(2026, 9, 1)), // fora do mês passado
      ],
    );

    test('lista o que falta e o que está acabando, sem duplicar a lista', () {
      expect(plan.needed.map((i) => i.name), ['Café Pilão', 'Leite Integral']);
      expect(plan.outCount, 1);
      expect(plan.lowCount, 1);
      // Leite: faltam 10 para chegar ao ideal.
      expect(plan.needed[1].quantity, 10);
    });

    test('repete o mês passado somando quantidades', () {
      final names = plan.repeat.map((i) => i.name).toList();
      expect(names, containsAll(['Arroz 5kg', 'Banana Prata']));
      expect(names, isNot(contains('Café Pilão'))); // já está em "needed"
      expect(names, isNot(contains('Iogurte'))); // fora da janela
      final banana = plan.repeat.firstWhere((i) => i.name == 'Banana Prata');
      expect(banana.quantity, closeTo(2.2, 0.001));
    });

    test('item com estoque ok vem desmarcado', () {
      final arroz = plan.repeat.firstWhere((i) => i.name == 'Arroz 5kg');
      expect(arroz.selected, isFalse);
    });

    test('estimativa soma apenas os selecionados', () {
      // Café 2×19,90 + Leite 10×4,99 + Banana 2,2×6,49 (preço mais recente)
      expect(plan.selectedEstimate, closeTo(39.80 + 49.90 + 2.2 * 6.49, 0.01));
    });

    test('texto da notificação traz contagem e estimativa', () {
      final msg = NotificationService.buildMessage(plan, startOfMonth: true);
      expect(msg.title, contains('compra do mês'));
      expect(msg.body, contains('1 em falta e 1 acabando'));
      expect(msg.body, contains('estimativa R\$'));
    });

    test('despensa em dia gera mensagem positiva', () {
      final empty = planner.build(
        now: now,
        pantry: [_stock('Arroz', 2, 2)],
        purchases: const [],
        shoppingList: const [],
      );
      final msg = NotificationService.buildMessage(empty, startOfMonth: false);
      expect(msg.body, contains('em dia'));
    });
  });
}
