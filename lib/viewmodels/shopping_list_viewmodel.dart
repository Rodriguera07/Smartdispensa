import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../models/item_category.dart';
import '../models/pantry_item.dart';
import '../models/purchase_record.dart';
import '../models/shopping_item.dart';
import '../services/firebase_service.dart';
import 'pantry_viewmodel.dart';

/// Sugestão inteligente baseada no histórico.
class ShoppingSuggestion {
  const ShoppingSuggestion({
    required this.name,
    required this.category,
    required this.timesBought,
    this.lastPrice,
  });

  final String name;
  final ItemCategory category;
  final int timesBought;
  final double? lastPrice;
}

/// Resumo exibido ao finalizar a compra.
class ShoppingSummary {
  const ShoppingSummary(this.itemCount, this.total);
  final int itemCount;
  final double total;
}

/// Estado da Lista de Compras Inteligente.
class ShoppingListViewModel extends ChangeNotifier {
  ShoppingListViewModel({
    required this.uid,
    required this._firebase,
    required this._pantry,
  }) {
    _sub = _firebase.watchShoppingList(uid).listen(_onItems, onError: (e) {
      debugPrint('[Shopping] $e');
      _loaded = true;
      notifyListeners();
    });
    // As sugestões dependem do histórico, que vive no PantryViewModel.
    _pantry.addListener(_recomputeSuggestions);
  }

  final String uid;
  final FirebaseService _firebase;
  final PantryViewModel _pantry;
  late final StreamSubscription<List<ShoppingItem>> _sub;

  bool _loaded = false;
  bool get loaded => _loaded;

  List<ShoppingItem> _items = const [];
  List<ShoppingItem> get items => _items;

  bool _sortByAisle = true;
  bool get sortByAisle => _sortByAisle;

  // Caches derivados
  Map<ItemCategory, List<ShoppingItem>> _grouped = const {};
  List<ShoppingSuggestion> _suggestions = const [];
  int _checkedCount = 0;
  double _cartTotal = 0;

  /// Itens agrupados por corredor, na ordem do supermercado.
  Map<ItemCategory, List<ShoppingItem>> get groupedByAisle => _grouped;
  List<ShoppingSuggestion> get suggestions => _suggestions;
  int get checkedCount => _checkedCount;
  int get pendingCount => _items.length - _checkedCount;
  double get cartTotal => _cartTotal;

  void _onItems(List<ShoppingItem> items) {
    _items = items;
    _loaded = true;
    _recompute();
    _recomputeSuggestions();
  }

  void _recompute() {
    final map = <ItemCategory, List<ShoppingItem>>{};
    for (final c in ItemCategory.values) {
      final list = _items.where((i) => i.category == c).toList()
        // Itens já no carrinho descem para o fim do corredor.
        ..sort((a, b) => (a.checked ? 1 : 0).compareTo(b.checked ? 1 : 0));
      if (list.isNotEmpty) map[c] = list;
    }
    _grouped = map;
    _checkedCount = _items.where((i) => i.checked).length;
    _cartTotal =
        _items.where((i) => i.checked).fold(0.0, (s, i) => s + i.lineTotal);
    notifyListeners();
  }

  /// Itens recorrentes (comprados em ≥ 2 dias diferentes nos últimos 90 dias)
  /// que não estão na lista e cujo estoque está baixo ou zerado.
  void _recomputeSuggestions() {
    final inList = _items.map((i) => i.normalizedName).toSet();
    final purchaseDays = <String, Set<int>>{};
    final latest = <String, PurchaseRecord>{};

    for (final p in _pantry.recentPurchases) {
      final key = p.normalizedName;
      final day = DateTime(p.date.year, p.date.month, p.date.day)
          .millisecondsSinceEpoch;
      (purchaseDays[key] ??= <int>{}).add(day);
      latest.putIfAbsent(key, () => p); // lista já vem do mais recente
    }

    final result = <ShoppingSuggestion>[];
    purchaseDays.forEach((key, days) {
      if (days.length < AppConstants.minPurchasesForSuggestion) return;
      if (inList.contains(key)) return;
      final stock = _pantry.findByName(latest[key]!.name);
      if (stock != null && !stock.isRunningLow) return;
      final last = latest[key]!;
      result.add(ShoppingSuggestion(
        name: last.name,
        category: last.category,
        timesBought: days.length,
        lastPrice: last.unitPrice > 0 ? last.unitPrice : null,
      ));
    });
    result.sort((a, b) => b.timesBought.compareTo(a.timesBought));
    _suggestions = result.take(8).toList(growable: false);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------------

  void toggleSortByAisle() {
    _sortByAisle = !_sortByAisle;
    notifyListeners();
  }

  bool contains(String name) {
    final key = TextUtils.normalize(name);
    return _items.any((i) => i.normalizedName == key);
  }

  void addItem({
    required String name,
    required ItemCategory category,
    double quantity = 1,
    String unit = 'un',
    double? price,
  }) {
    if (name.trim().isEmpty) return;
    final key = TextUtils.normalize(name);
    final existing = _items.where((i) => i.normalizedName == key).firstOrNull;
    if (existing != null) {
      _firebase.updateShoppingItem(
        uid,
        existing.copyWith(quantity: existing.quantity + quantity),
      );
      return;
    }
    _firebase.addShoppingItem(
      uid,
      ShoppingItem(
        id: '',
        name: name.trim(),
        category: category,
        quantity: quantity,
        unit: unit,
        price: price,
      ),
    );
  }

  /// Envia um item da despensa para a lista (sem duplicar).
  /// Retorna `false` se ele já estava na lista.
  bool addFromPantry(PantryItem item, {bool auto = false}) {
    if (contains(item.name)) return false;
    final missing = item.idealQuantity - item.quantity;
    _firebase.addShoppingItem(
      uid,
      ShoppingItem(
        id: '',
        name: item.name,
        category: item.category,
        quantity: missing >= 1 ? missing.ceilToDouble() : 1,
        unit: item.unit,
        price: item.lastPrice,
        pantryItemId: item.id,
        autoAdded: auto,
      ),
    );
    return true;
  }

  void addSuggestion(ShoppingSuggestion s) => addItem(
        name: s.name,
        category: s.category,
        price: s.lastPrice,
      );

  void toggleChecked(ShoppingItem item) {
    _items = [
      for (final i in _items)
        i.id == item.id ? i.copyWith(checked: !i.checked) : i,
    ];
    _recompute(); // resposta visual instantânea
    _firebase.updateShoppingItem(uid, item.copyWith(checked: !item.checked));
  }

  void updateItem(ShoppingItem item) => _firebase.updateShoppingItem(uid, item);

  void remove(ShoppingItem item) => _firebase.deleteShoppingItem(uid, item.id);

  void clearAll() => _firebase.clearShoppingItems(uid, _items.map((i) => i.id));

  /// **Finalizar Compra**: itens marcados voltam ao estoque, entram no
  /// histórico (gasto do mês) e saem da lista.
  ShoppingSummary finishShopping() {
    final checked = _items.where((i) => i.checked).toList();
    if (checked.isEmpty) return const ShoppingSummary(0, 0);

    _firebase.restockAndRecord(
      uid: uid,
      entries: [
        for (final i in checked)
          RestockEntry(
            name: i.name,
            category: i.category,
            quantity: i.quantity,
            unit: i.unit,
            unitPrice: i.price,
          ),
      ],
      currentPantry: _pantry.items,
      source: PurchaseSource.shoppingList,
      removeFromShoppingList: checked.map((i) => i.id),
    );

    final total = checked.fold(0.0, (s, i) => s + i.lineTotal);
    return ShoppingSummary(checked.length, total);
  }

  /// Texto formatado com emojis por corredor, pronto para o WhatsApp
  /// (usa *negrito* do WhatsApp nos títulos).
  String buildShareText() {
    final buffer = StringBuffer()
      ..writeln('🛒 *Lista de Compras — Smart Dispensa*')
      ..writeln('📅 ${Fmt.date(DateTime.now())}')
      ..writeln();

    final pending = _items.where((i) => !i.checked).toList();
    for (final category in ItemCategory.values) {
      final list = pending.where((i) => i.category == category).toList();
      if (list.isEmpty) continue;
      buffer.writeln('${category.emoji} *${category.label}*');
      for (final i in list) {
        final qty = '${Fmt.quantity(i.quantity)} ${i.unit}';
        buffer.writeln('  ▫️ ${i.name} ($qty)');
      }
      buffer.writeln();
    }

    if (pending.isEmpty) buffer.writeln('✅ Tudo comprado!');
    buffer
      ..writeln('Total de itens: ${pending.length}')
      ..write('_Enviado pelo app Smart Dispensa_ 🌿');
    return buffer.toString();
  }

  @override
  void dispose() {
    _sub.cancel();
    _pantry.removeListener(_recomputeSuggestions);
    super.dispose();
  }
}
