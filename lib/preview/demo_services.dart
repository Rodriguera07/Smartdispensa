// Serviços de DEMONSTRAÇÃO, em memória, sem Firebase, ML Kit ou Google Play.
//
// Servem para visualizar o app no navegador ou num emulador sem configurar
// nada. Não são usados pelo app de produção (lib/main.dart).

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../core/utils/formatters.dart';
import '../models/item_category.dart';
import '../models/pantry_item.dart';
import '../models/purchase_record.dart';
import '../models/receipt_item.dart';
import '../models/reminder_settings.dart';
import '../models/shopping_item.dart';
import '../models/user_profile.dart';
import '../services/firebase_service.dart';
import '../services/ocr_service.dart';
import '../services/receipt_parser.dart';
import '../services/subscription_service.dart';

/// Valor observável que entrega o estado atual a cada novo ouvinte,
/// como o `snapshots()` do Firestore.
class _Live<T> {
  _Live(this._value);

  T _value;
  final _controller = StreamController<T>.broadcast();

  T get value => _value;
  set value(T v) {
    _value = v;
    _controller.add(v);
  }

  Stream<T> get stream => Stream<T>.multi((c) {
        c.add(_value);
        final sub = _controller.stream.listen(c.add);
        c.onCancel = sub.cancel;
      });
}

/// Usuário fictício (implementa só o que o app lê).
class DemoUser implements User {
  @override
  String get uid => 'demo-user';
  @override
  String? get displayName => 'Ana Souza';
  @override
  String? get email => 'ana@exemplo.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Firestore + Auth em memória com dados de exemplo.
class DemoFirebaseService implements FirebaseService {
  DemoFirebaseService({bool signedIn = true})
      : _user = _Live<User?>(signedIn ? DemoUser() : null) {
    _seed();
  }

  final _Live<User?> _user;
  final _profile = _Live(const UserProfile(
    uid: 'demo-user',
    name: 'Ana Souza',
    email: 'ana@exemplo.com',
    scanPeriod: null,
    scanCount: 0,
  ));
  final _pantry = _Live<List<PantryItem>>(const []);
  final _shopping = _Live<List<ShoppingItem>>(const []);
  final _purchases = _Live<List<PurchaseRecord>>(const []);
  int _seq = 0;

  String _id() => 'id${_seq++}';

  // ---------------------------------------------------------------------------
  // Dados de exemplo
  // ---------------------------------------------------------------------------

  void _seed() {
    _profile.value = UserProfile(
      uid: 'demo-user',
      name: 'Ana Souza',
      email: 'ana@exemplo.com',
      scanPeriod: monthKey(DateTime.now()),
      scanCount: 1,
      reminders: const ReminderSettings(startEnabled: true, startDay: 5),
    );

    PantryItem p(String name, ItemCategory c, double q, double ideal,
            {String unit = 'un', double? price}) =>
        PantryItem(
          id: _id(),
          name: name,
          category: c,
          quantity: q,
          idealQuantity: ideal,
          unit: unit,
          lastPrice: price,
        );

    _pantry.value = [
      p('Arroz Tio João 5KG', ItemCategory.mercearia, 2, 2, price: 25.90),
      p('Feijão Carioca 1KG', ItemCategory.mercearia, 1, 4, price: 8.49),
      p('Café Pilão 500G', ItemCategory.mercearia, 0, 2, price: 19.90),
      p('Leite Integral Italac 1L', ItemCategory.laticinios, 3, 12, price: 4.99),
      p('Queijo Mussarela', ItemCategory.laticinios, 0.3, 0.5, unit: 'kg', price: 42.90),
      p('Banana Prata', ItemCategory.hortifruti, 1.2, 1.5, unit: 'kg', price: 5.99),
      p('Tomate Italiano', ItemCategory.hortifruti, 0, 1, unit: 'kg', price: 7.98),
      p('Detergente Ypê 500ML', ItemCategory.limpeza, 4, 4, price: 2.49),
      p('Sabão em Pó Omo 1,6KG', ItemCategory.limpeza, 1, 2, price: 32.90),
      p('Papel Higiênico Neve 12un', ItemCategory.higiene, 1, 2, price: 21.90),
      p('Creme Dental Colgate', ItemCategory.higiene, 2, 3, price: 4.79),
      p('Suco Del Valle Uva 1L', ItemCategory.bebidas, 2, 4, price: 8.90),
    ];

    ShoppingItem s(String name, ItemCategory c, double q,
            {bool checked = false, double? price, bool auto = false, String unit = 'un'}) =>
        ShoppingItem(
          id: _id(),
          name: name,
          category: c,
          quantity: q,
          unit: unit,
          checked: checked,
          price: price,
          autoAdded: auto,
          createdAt: DateTime.now(),
        );

    _shopping.value = [
      s('Café Pilão 500G', ItemCategory.mercearia, 2, price: 19.90, auto: true),
      s('Tomate Italiano', ItemCategory.hortifruti, 1, unit: 'kg', auto: true),
      s('Pão de Forma Integral', ItemCategory.padaria, 1, checked: true, price: 9.49),
      s('Iogurte Natural', ItemCategory.laticinios, 4, checked: true, price: 3.29),
      s('Peito de Frango', ItemCategory.carnes, 1, unit: 'kg', price: 18.90),
      s('Água Sanitária Qboa', ItemCategory.limpeza, 1),
      s('Shampoo Seda', ItemCategory.higiene, 1, checked: true, price: 14.90),
    ];

    final now = DateTime.now();
    DateTime ago(int d) => now.subtract(Duration(days: d));
    PurchaseRecord r(String name, ItemCategory c, double q, double price, int daysAgo) =>
        PurchaseRecord(
          id: _id(),
          name: name,
          category: c,
          quantity: q,
          unitPrice: price,
          date: ago(daysAgo),
          source: PurchaseSource.receipt,
          store: 'Supermercado Bom Preço',
        );

    // Dias dentro do mês corrente para o "Gasto no Mês" ficar realista.
    final d = now.day;
    int inMonth(int n) => n < d ? n : d - 1;

    _purchases.value = [
      r('Café Pilão 500G', ItemCategory.mercearia, 2, 19.90, inMonth(2)),
      r('Leite Integral Italac 1L', ItemCategory.laticinios, 12, 4.99, inMonth(2)),
      r('Arroz Tio João 5KG', ItemCategory.mercearia, 1, 25.90, inMonth(2)),
      r('Banana Prata', ItemCategory.hortifruti, 1.5, 5.99, inMonth(2)),
      r('Sabão em Pó Omo 1,6KG', ItemCategory.limpeza, 1, 32.90, inMonth(9)),
      r('Feijão Carioca 1KG', ItemCategory.mercearia, 2, 8.49, inMonth(9)),
      r('Queijo Mussarela', ItemCategory.laticinios, 0.5, 42.90, inMonth(9)),
      r('Papel Higiênico Neve 12un', ItemCategory.higiene, 1, 21.90, inMonth(9)),
      r('Suco Del Valle Uva 1L', ItemCategory.bebidas, 4, 8.90, inMonth(9)),
      r('Biscoito Maizena', ItemCategory.mercearia, 3, 4.29, inMonth(9)),
      r('Café Pilão 500G', ItemCategory.mercearia, 2, 17.90, 35),
      r('Leite Integral Italac 1L', ItemCategory.laticinios, 12, 4.59, 35),
      r('Biscoito Maizena', ItemCategory.mercearia, 3, 3.99, 35),
      r('Feijão Carioca 1KG', ItemCategory.mercearia, 2, 8.99, 40),
      r('Banana Prata', ItemCategory.hortifruti, 1.2, 6.49, 40),
      r('Arroz Tio João 5KG', ItemCategory.mercearia, 1, 24.50, 50),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  @override
  Stream<User?> authStateChanges() => _user.stream;
  @override
  User? get currentUser => _user.value;

  Future<void> _signIn() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _user.value = DemoUser();
  }

  @override
  Future<void> signInWithEmail(String email, String password) => _signIn();
  @override
  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) =>
      _signIn();
  @override
  Future<void> signInWithGoogle() => _signIn();
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signOut() async => _user.value = null;
  @override
  Future<void> ensureUserDocument(User user, {String? name}) async {}

  @override
  bool get usesPasswordSignIn => true;

  @override
  Future<void> reauthenticate({String? password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> deleteAccountAndData() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _pantry.value = const [];
    _shopping.value = const [];
    _purchases.value = const [];
    _user.value = null;
  }

  // ---------------------------------------------------------------------------
  // Perfil
  // ---------------------------------------------------------------------------

  @override
  Stream<UserProfile> watchProfile(String uid) => _profile.stream;

  @override
  void updatePreferences(
    String uid, {
    bool? autoSendToList,
    bool? darkMode,
    ReminderSettings? reminders,
  }) {
    _profile.value = _profile.value.copyWith(
      autoSendToList: autoSendToList,
      darkMode: darkMode,
      reminders: reminders,
    );
  }

  @override
  void registerScan(String uid, UserProfile profile) {
    final p = _profile.value;
    final period = monthKey(DateTime.now());
    _profile.value = p.copyWith(
      scanPeriod: period,
      scanCount: p.scanPeriod == period ? p.scanCount + 1 : 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Despensa
  // ---------------------------------------------------------------------------

  @override
  Stream<List<PantryItem>> watchPantry(String uid) => _pantry.stream;

  PantryItem _withId(PantryItem i, String id) => PantryItem(
        id: id,
        name: i.name,
        category: i.category,
        quantity: i.quantity,
        idealQuantity: i.idealQuantity,
        unit: i.unit,
        lastPrice: i.lastPrice,
      );

  @override
  void addPantryItem(String uid, PantryItem item) =>
      _pantry.value = [..._pantry.value, _withId(item, _id())];

  @override
  void updatePantryItem(String uid, PantryItem item) => _pantry.value = [
        for (final i in _pantry.value) i.id == item.id ? item : i,
      ];

  @override
  void deletePantryItem(String uid, String id) =>
      _pantry.value = _pantry.value.where((i) => i.id != id).toList();

  @override
  void changePantryQuantity(String uid, String id, double delta) =>
      _pantry.value = [
        for (final i in _pantry.value)
          i.id == id ? i.copyWith(quantity: i.quantity + delta) : i,
      ];

  @override
  void setPantryQuantity(String uid, String id, double value) =>
      _pantry.value = [
        for (final i in _pantry.value) i.id == id ? i.copyWith(quantity: value) : i,
      ];

  // ---------------------------------------------------------------------------
  // Lista de compras
  // ---------------------------------------------------------------------------

  @override
  Stream<List<ShoppingItem>> watchShoppingList(String uid) => _shopping.stream;

  @override
  void addShoppingItem(String uid, ShoppingItem item) => _shopping.value = [
        ..._shopping.value,
        ShoppingItem(
          id: _id(),
          name: item.name,
          category: item.category,
          quantity: item.quantity,
          unit: item.unit,
          price: item.price,
          pantryItemId: item.pantryItemId,
          autoAdded: item.autoAdded,
          createdAt: DateTime.now(),
        ),
      ];

  @override
  void updateShoppingItem(String uid, ShoppingItem item) => _shopping.value = [
        for (final i in _shopping.value) i.id == item.id ? item : i,
      ];

  @override
  void deleteShoppingItem(String uid, String id) =>
      _shopping.value = _shopping.value.where((i) => i.id != id).toList();

  @override
  void clearShoppingItems(String uid, Iterable<String> ids) {
    final remove = ids.toSet();
    _shopping.value =
        _shopping.value.where((i) => !remove.contains(i.id)).toList();
  }

  // ---------------------------------------------------------------------------
  // Histórico
  // ---------------------------------------------------------------------------

  @override
  Stream<List<PurchaseRecord>> watchPurchasesSince(String uid, DateTime since) =>
      _purchases.stream;

  @override
  void addPurchaseRecord(String uid, PurchaseRecord record) =>
      _purchases.value = [record, ..._purchases.value];

  @override
  Future<List<PurchaseRecord>> fetchPriceHistory(
      String uid, String normalizedName) async {
    return _purchases.value
        .where((p) => p.normalizedName == normalizedName && p.unitPrice > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  void restockAndRecord({
    required String uid,
    required List<RestockEntry> entries,
    required List<PantryItem> currentPantry,
    required PurchaseSource source,
    String? store,
    Iterable<String> removeFromShoppingList = const [],
  }) {
    final pantry = [..._pantry.value];
    final records = <PurchaseRecord>[];
    for (final e in entries) {
      final key = TextUtils.normalize(e.name);
      final idx = pantry.indexWhere((p) => p.normalizedName == key);
      if (idx >= 0) {
        final old = pantry[idx];
        final q = old.quantity + e.quantity;
        pantry[idx] = old.copyWith(
          quantity: q,
          idealQuantity: q > old.idealQuantity ? q : old.idealQuantity,
          lastPrice: e.unitPrice,
        );
      } else {
        pantry.add(PantryItem(
          id: _id(),
          name: e.name,
          category: e.category,
          quantity: e.quantity,
          idealQuantity: e.quantity < 1 ? 1 : e.quantity,
          unit: e.unit,
          lastPrice: e.unitPrice,
        ));
      }
      records.add(PurchaseRecord(
        id: _id(),
        name: e.name,
        category: e.category,
        quantity: e.quantity,
        unit: e.unit,
        unitPrice: e.unitPrice ?? 0,
        date: DateTime.now(),
        source: source,
        store: store,
      ));
    }
    _pantry.value = pantry;
    _purchases.value = [...records, ..._purchases.value];
    clearShoppingItems(uid, removeFromShoppingList);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// OCR de demonstração: simula a foto e passa um cupom de exemplo pelo
/// **parser real** ([ReceiptParser]).
class DemoOcrService extends OcrService {
  static const sampleReceipt = [
    'SUPERMERCADO BOM PRECO LTDA',
    'CNPJ: 12.345.678/0001-90',
    'ITEM COD DESCRICAO QTD UN VL UNIT VL TOTAL',
    '001 7891000100103 LEITE INTEGRAL ITALAC 1L 6 UN X 4,99 29,94',
    '002 7896006711112 ARROZ TIO JOAO 5KG UN 1 X 25,90 F1 25,90',
    '003 7891910000197 CAFE PILAO TRADICIONAL 500G 2 UN X 19,90 39,80',
    '004 2000001 BANANA PRATA KG 1,245 X 5,99 7,46',
    '005 7891024134702 DETERGENTE YPE 500ML 3UNx2,49 7,47',
    '006 7894900011517 REFRIGERANTE COCA COLA 2L 2 UN X 9,49 18,98',
    '007 7891150064710 SABONETE DOVE 90G 4 UN X 3,29 13,16',
    'VALOR TOTAL R\$ 142,71',
  ];

  @override
  Future<XFile?> pickImage({required bool fromCamera}) async =>
      XFile('demo-nota.jpg');

  @override
  Future<ReceiptScanResult> scanReceipt(String imagePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    return const ReceiptParser().parse(sampleReceipt);
  }

  @override
  Future<void> dispose() async {}
}

/// Assinaturas de demonstração: a "compra" é simulada.
class DemoSubscriptionService extends SubscriptionService {
  DemoSubscriptionService({bool premium = false}) {
    isPremium.value = premium;
  }

  @override
  Future<void> init(String firebaseUid) async {}

  @override
  Future<PurchaseOutcome> purchase(dynamic package) async =>
      PurchaseOutcome.success;

  @override
  Future<bool> restore() async => isPremium.value;

  @override
  Future<void> logOut() async {}
}
