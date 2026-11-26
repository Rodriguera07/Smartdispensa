import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../models/item_category.dart';
import '../models/pantry_item.dart';
import '../models/purchase_record.dart';
import '../models/reminder_settings.dart';
import '../models/shopping_item.dart';
import '../models/user_profile.dart';

/// Entrada genérica de reabastecimento (vinda da nota fiscal ou da lista).
class RestockEntry {
  const RestockEntry({
    required this.name,
    required this.category,
    required this.quantity,
    this.unit = 'un',
    this.unitPrice,
  });

  final String name;
  final ItemCategory category;
  final double quantity;
  final String unit;
  final double? unitPrice;
}

/// Exceção de autenticação com mensagem amigável em português.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Camada única de acesso ao Firebase (Auth + Firestore).
///
/// ### Estrutura no Firestore (plano Spark, gratuito)
/// ```text
/// users/{uid}                    → perfil, preferências, cota de scans
/// users/{uid}/pantry/{id}        → estoque da despensa
/// users/{uid}/shopping_list/{id} → lista de compras
/// users/{uid}/purchases/{id}     → histórico (gastos, preços, sugestões)
/// ```
///
/// ### Offline-first
/// A persistência offline do Firestore é ativada em [configureFirestore].
/// As **escritas não são aguardadas** (`unawaited`): o SDK grava no cache
/// local na hora, os `snapshots()` disparam imediatamente e a sincronização
/// acontece sozinha quando a internet volta. Assim o app funciona dentro do
/// supermercado mesmo sem sinal — aguardar o `Future` de uma escrita offline
/// travaria a UI até a conexão voltar.
class FirebaseService {
  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Limite seguro de operações por batch (o Firestore aceita até 500).
  static const int _batchLimit = 450;

  /// Deve ser chamado uma única vez, logo após `Firebase.initializeApp()`.
  static void configureFirestore() {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // ===========================================================================
  // AUTENTICAÇÃO
  // ===========================================================================

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) =>
      _guard(() => _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          ));

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await cred.user?.updateDisplayName(name.trim());
        await ensureUserDocument(cred.user!, name: name.trim());
      });

  /// Login com Google via fluxo nativo do Firebase Auth
  /// (`signInWithProvider`) — não exige pacotes extras.
  /// Requer a impressão digital SHA-1/SHA-256 cadastrada no Console Firebase.
  Future<void> signInWithGoogle() => _guard(() async {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({'prompt': 'select_account'});
        final cred = await _auth.signInWithProvider(provider);
        if (cred.user != null) await ensureUserDocument(cred.user!);
      });

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authMessage(e.code));
    }
  }

  static String _authMessage(String code) => switch (code) {
        'invalid-email' => 'E-mail inválido. Confira e tente novamente.',
        'user-disabled' => 'Esta conta foi desativada.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'E-mail ou senha incorretos.',
        'email-already-in-use' => 'Já existe uma conta com este e-mail.',
        'weak-password' => 'Senha fraca. Use pelo menos 6 caracteres.',
        'too-many-requests' =>
          'Muitas tentativas. Aguarde um pouco e tente de novo.',
        'network-request-failed' =>
          'Sem conexão. Verifique sua internet para entrar.',
        'web-context-canceled' ||
        'canceled' ||
        'popup-closed-by-user' =>
          'Login cancelado.',
        _ => 'Não foi possível concluir. Tente novamente. ($code)',
      };

  // ===========================================================================
  // PERFIL
  // ===========================================================================

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _pantry(String uid) =>
      _userDoc(uid).collection('pantry');

  CollectionReference<Map<String, dynamic>> _shopping(String uid) =>
      _userDoc(uid).collection('shopping_list');

  CollectionReference<Map<String, dynamic>> _purchases(String uid) =>
      _userDoc(uid).collection('purchases');

  Future<void> ensureUserDocument(User user, {String? name}) {
    return _userDoc(user.uid).set({
      'name': name ?? user.displayName,
      'email': user.email,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<UserProfile> watchProfile(String uid) =>
      _userDoc(uid).snapshots().map(UserProfile.fromDoc);

  void updatePreferences(
    String uid, {
    bool? autoSendToList,
    bool? darkMode,
    ReminderSettings? reminders,
  }) {
    _fire(_userDoc(uid).set({
      'autoSendToList': ?autoSendToList,
      'darkMode': ?darkMode,
      'reminders': ?reminders?.toMap(),
    }, SetOptions(merge: true)));
  }

  /// Registra o uso de um escaneamento no mês corrente (cota do plano Grátis).
  void registerScan(String uid, UserProfile profile) {
    final period = monthKey(DateTime.now());
    final samePeriod = profile.scanPeriod == period;
    _fire(_userDoc(uid).set({
      'scanPeriod': period,
      'scanCount': samePeriod ? FieldValue.increment(1) : 1,
    }, SetOptions(merge: true)));
  }

  // ===========================================================================
  // DESPENSA
  // ===========================================================================

  Stream<List<PantryItem>> watchPantry(String uid) =>
      _pantry(uid).snapshots().map(
            (s) => s.docs.map(PantryItem.fromDoc).toList(growable: false),
          );

  void addPantryItem(String uid, PantryItem item) =>
      _fire(_pantry(uid).add(item.toMap()));

  void updatePantryItem(String uid, PantryItem item) =>
      _fire(_pantry(uid).doc(item.id).set(item.toMap(), SetOptions(merge: true)));

  void deletePantryItem(String uid, String id) =>
      _fire(_pantry(uid).doc(id).delete());

  /// Ajusta a quantidade de forma atômica (seguro contra uso simultâneo
  /// em dois aparelhos da mesma família).
  void changePantryQuantity(String uid, String id, double delta) {
    _fire(_pantry(uid).doc(id).update({
      'quantity': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  void setPantryQuantity(String uid, String id, double value) {
    _fire(_pantry(uid).doc(id).update({
      'quantity': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  // ===========================================================================
  // LISTA DE COMPRAS
  // ===========================================================================

  Stream<List<ShoppingItem>> watchShoppingList(String uid) => _shopping(uid)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(ShoppingItem.fromDoc).toList(growable: false));

  void addShoppingItem(String uid, ShoppingItem item) =>
      _fire(_shopping(uid).add(item.toMap()));

  void updateShoppingItem(String uid, ShoppingItem item) => _fire(
      _shopping(uid).doc(item.id).set(item.toMap(), SetOptions(merge: true)));

  void deleteShoppingItem(String uid, String id) =>
      _fire(_shopping(uid).doc(id).delete());

  void clearShoppingItems(String uid, Iterable<String> ids) {
    _runBatched(ids.map((id) => (WriteBatch b) => b.delete(_shopping(uid).doc(id))));
  }

  // ===========================================================================
  // HISTÓRICO DE COMPRAS
  // ===========================================================================

  /// Compras a partir de [since] (mais recentes primeiro).
  Stream<List<PurchaseRecord>> watchPurchasesSince(String uid, DateTime since) =>
      _purchases(uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('date', descending: true)
          .snapshots()
          .map((s) => s.docs.map(PurchaseRecord.fromDoc).toList(growable: false));

  void addPurchaseRecord(String uid, PurchaseRecord record) =>
      _fire(_purchases(uid).add(record.toMap()));

  /// Histórico de preço de um produto específico (Premium).
  Future<List<PurchaseRecord>> fetchPriceHistory(String uid, String normalizedName) async {
    final snap = await _purchases(uid)
        .where('normalizedName', isEqualTo: normalizedName)
        .limit(60)
        .get();
    final list = snap.docs.map(PurchaseRecord.fromDoc).where((p) => p.unitPrice > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ===========================================================================
  // OPERAÇÃO COMPOSTA: REABASTECER DESPENSA + REGISTRAR COMPRA
  // ===========================================================================

  /// Usado ao **salvar uma nota fiscal** e ao **finalizar uma compra**:
  ///
  /// 1. Soma a quantidade a itens existentes na despensa (casando pelo nome
  ///    normalizado) ou cria itens novos;
  /// 2. Registra cada item no histórico de compras (alimenta o "Gasto no Mês",
  ///    as sugestões e o histórico de preços);
  /// 3. Remove da lista de compras os itens indicados.
  ///
  /// Tudo em batches atômicos, funcionando offline.
  void restockAndRecord({
    required String uid,
    required List<RestockEntry> entries,
    required List<PantryItem> currentPantry,
    required PurchaseSource source,
    String? store,
    Iterable<String> removeFromShoppingList = const [],
  }) {
    final byName = {for (final p in currentPantry) p.normalizedName: p};
    final now = DateTime.now();
    final ops = <void Function(WriteBatch)>[];

    // Mescla entradas repetidas na mesma nota (ex.: 2 linhas de "Leite").
    final merged = <String, RestockEntry>{};
    for (final e in entries) {
      final key = TextUtils.normalize(e.name);
      final prev = merged[key];
      merged[key] = prev == null
          ? e
          : RestockEntry(
              name: prev.name,
              category: prev.category,
              unit: prev.unit,
              quantity: prev.quantity + e.quantity,
              unitPrice: e.unitPrice ?? prev.unitPrice,
            );
    }

    for (final entry in merged.entries) {
      final e = entry.value;
      final existing = byName[entry.key];

      if (existing != null) {
        final newQty = existing.quantity.clamp(0, double.infinity) + e.quantity;
        ops.add((b) => b.update(_pantry(uid).doc(existing.id), {
              'quantity': newQty,
              // O "estoque ideal" acompanha o maior volume já comprado.
              if (newQty > existing.idealQuantity) 'idealQuantity': newQty,
              if (e.unitPrice != null && e.unitPrice! > 0) 'lastPrice': e.unitPrice,
              'updatedAt': FieldValue.serverTimestamp(),
            }));
      } else {
        final item = PantryItem(
          id: '',
          name: e.name,
          category: e.category,
          quantity: e.quantity,
          idealQuantity: e.quantity < 1 ? 1 : e.quantity,
          unit: e.unit,
          lastPrice: e.unitPrice,
        );
        ops.add((b) => b.set(_pantry(uid).doc(), item.toMap()));
      }

      final record = PurchaseRecord(
        id: '',
        name: e.name,
        category: e.category,
        quantity: e.quantity,
        unit: e.unit,
        unitPrice: e.unitPrice ?? 0,
        date: now,
        source: source,
        store: store,
      );
      ops.add((b) => b.set(_purchases(uid).doc(), record.toMap()));
    }

    for (final id in removeFromShoppingList) {
      ops.add((b) => b.delete(_shopping(uid).doc(id)));
    }

    _runBatched(ops);
  }

  // ===========================================================================
  // Infra
  // ===========================================================================

  void _runBatched(Iterable<void Function(WriteBatch)> ops) {
    var batch = _db.batch();
    var count = 0;
    for (final op in ops) {
      op(batch);
      if (++count == _batchLimit) {
        _fire(batch.commit());
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) _fire(batch.commit());
  }

  /// Dispara a escrita sem bloquear a UI (ver nota "Offline-first").
  void _fire(Future<void> write) {
    unawaited(write.catchError((Object e, StackTrace s) {
      debugPrint('[FirebaseService] Falha ao sincronizar: $e');
    }));
  }
}
