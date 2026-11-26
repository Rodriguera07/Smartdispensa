import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../models/item_category.dart';
import '../models/pantry_item.dart';
import '../models/purchase_record.dart';
import '../services/firebase_service.dart';

/// Estado da despensa + histórico de compras recente.
///
/// Os valores derivados (totais, itens acabando, gasto do mês) são
/// calculados **uma vez por atualização** do Firestore e guardados em cache,
/// em vez de recalculados a cada `build` — importante para manter a
/// rolagem fluida em despensas grandes.
class PantryViewModel extends ChangeNotifier {
  PantryViewModel({required this.uid, required this._firebase}) {
    _pantrySub = _firebase.watchPantry(uid).listen(_onPantry, onError: _onError);
    final since = DateTime.now()
        .subtract(const Duration(days: AppConstants.suggestionWindowDays));
    _purchasesSub = _firebase
        .watchPurchasesSince(uid, since)
        .listen(_onPurchases, onError: _onError);
  }

  final String uid;
  final FirebaseService _firebase;
  late final StreamSubscription<List<PantryItem>> _pantrySub;
  late final StreamSubscription<List<PurchaseRecord>> _purchasesSub;

  bool _loaded = false;
  bool get loaded => _loaded;

  List<PantryItem> _items = const [];
  List<PantryItem> get items => _items;

  List<PurchaseRecord> _recentPurchases = const [];

  /// Compras dos últimos 90 dias (mais recentes primeiro).
  List<PurchaseRecord> get recentPurchases => _recentPurchases;

  // Filtros
  String _query = '';
  String get query => _query;
  ItemCategory? _categoryFilter;
  ItemCategory? get categoryFilter => _categoryFilter;

  // Caches derivados
  List<PantryItem> _visible = const [];
  int _inStockCount = 0;
  int _lowStockCount = 0;
  double _monthSpend = 0;

  List<PantryItem> get visibleItems => _visible;
  int get inStockCount => _inStockCount;
  int get lowStockCount => _lowStockCount;
  double get monthSpend => _monthSpend;

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  void _onPantry(List<PantryItem> items) {
    _items = items;
    _loaded = true;
    _recompute();
  }

  void _onPurchases(List<PurchaseRecord> purchases) {
    _recentPurchases = purchases;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    _monthSpend = purchases
        .where((p) => !p.date.isBefore(monthStart))
        .fold(0.0, (sum, p) => sum + p.total);
    notifyListeners();
  }

  void _onError(Object e) {
    debugPrint('[Pantry] $e');
    _loaded = true;
    notifyListeners();
  }

  void _recompute() {
    _inStockCount = _items.where((i) => i.quantity > 0).length;
    _lowStockCount = _items.where((i) => i.isRunningLow).length;

    final q = TextUtils.normalize(_query);
    final filtered = _items.where((i) {
      if (_categoryFilter != null && i.category != _categoryFilter) return false;
      if (q.isNotEmpty && !i.normalizedName.contains(q)) return false;
      return true;
    }).toList()
      // Itens acabando primeiro (o que mais importa), depois alfabético.
      ..sort((a, b) {
        final byLevel = a.level.index.compareTo(b.level.index);
        return byLevel != 0 ? byLevel : a.normalizedName.compareTo(b.normalizedName);
      });
    _visible = filtered;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    _recompute();
  }

  void setCategoryFilter(ItemCategory? category) {
    _categoryFilter = category;
    _recompute();
  }

  PantryItem? findByName(String name) {
    final key = TextUtils.normalize(name);
    for (final i in _items) {
      if (i.normalizedName == key) return i;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------------

  void addItem(PantryItem item) {
    final existing = findByName(item.name);
    if (existing != null) {
      // Evita duplicatas: soma ao item já existente.
      _firebase.updatePantryItem(
        uid,
        existing.copyWith(
          quantity: existing.quantity + item.quantity,
          idealQuantity: item.idealQuantity > existing.idealQuantity
              ? item.idealQuantity
              : existing.idealQuantity,
          lastPrice: item.lastPrice,
        ),
      );
    } else {
      _firebase.addPantryItem(uid, item);
    }
    // Com preço informado, o cadastro manual também conta como compra
    // (entra no "Gasto no Mês" e no histórico de preços).
    if (item.lastPrice != null && item.lastPrice! > 0 && item.quantity > 0) {
      _firebase.addPurchaseRecord(
        uid,
        PurchaseRecord(
          id: '',
          name: item.name,
          category: item.category,
          quantity: item.quantity,
          unit: item.unit,
          unitPrice: item.lastPrice!,
          date: DateTime.now(),
        ),
      );
    }
  }

  void updateItem(PantryItem item) => _firebase.updatePantryItem(uid, item);

  void deleteItem(PantryItem item) => _firebase.deletePantryItem(uid, item.id);

  /// Botão "Usar (-1)". Retorna `true` quando o item **acabou** com este uso.
  bool useOne(PantryItem item) {
    if (item.quantity <= 0) return false;
    // Itens a granel (ex.: 0,4 kg) zeram em vez de ficarem negativos.
    final step = item.quantity < 1 ? item.quantity : 1.0;
    final remaining = item.quantity - step;
    if (remaining <= 0) {
      _firebase.setPantryQuantity(uid, item.id, 0);
    } else {
      _firebase.changePantryQuantity(uid, item.id, -step);
    }
    // Atualização otimista local para resposta tátil imediata.
    _items = [
      for (final i in _items)
        i.id == item.id ? i.copyWith(quantity: remaining.clamp(0, double.infinity)) : i,
    ];
    _recompute();
    return remaining <= 0;
  }

  @override
  void dispose() {
    _pantrySub.cancel();
    _purchasesSub.cancel();
    super.dispose();
  }
}
