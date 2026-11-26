import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';

/// Estado de autenticação + ações de login/cadastro.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._firebase, this._subscriptions, [this._notifications]) {
    _sub = _firebase.authStateChanges().listen(_onAuthChanged);
  }

  final FirebaseService _firebase;
  final SubscriptionService _subscriptions;
  final NotificationService? _notifications;
  late final StreamSubscription<User?> _sub;

  User? _user;
  User? get user => _user;

  /// `false` até o Firebase informar o estado inicial (exibe a Splash).
  bool _initialized = false;
  bool get initialized => _initialized;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  void _onAuthChanged(User? user) {
    final changedUser = user?.uid != _user?.uid;
    _user = user;
    _initialized = true;
    if (user != null && changedUser) {
      // Não bloqueia: funciona offline e sincroniza depois.
      unawaited(_firebase.ensureUserDocument(user).catchError((_) {}));
      unawaited(_subscriptions.init(user.uid));
    }
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _firebase.signInWithEmail(email, password));

  Future<bool> register(String name, String email, String password) => _run(
        () => _firebase.registerWithEmail(
          name: name,
          email: email,
          password: password,
        ),
      );

  Future<bool> signInWithGoogle() => _run(_firebase.signInWithGoogle);

  /// Retorna `null` em caso de sucesso ou a mensagem de erro.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _firebase.sendPasswordReset(email);
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    // Lembretes são do usuário: não podem continuar disparando para outra
    // pessoa que entrar no mesmo aparelho.
    await _notifications?.cancelAll();
    await _subscriptions.logOut();
    await _firebase.signOut();
  }

  /// A conta usa senha (confirmação por senha) ou Google (confirmação Google).
  bool get usesPasswordSignIn => _firebase.usesPasswordSignIn;

  /// Confirma a identidade e exclui a conta com todos os dados.
  /// Retorna `true` em caso de sucesso; a mensagem de erro fica em [error].
  Future<bool> deleteAccount({String? password}) => _run(() async {
        await _firebase.reauthenticate(password: password);
        await _firebase.deleteAccountAndData();
        await _notifications?.cancelAll();
        await _subscriptions.logOut();
      });

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthFailure catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Algo deu errado. Tente novamente.';
      debugPrint('[Auth] $e');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
