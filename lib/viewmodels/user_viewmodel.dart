import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/user_profile.dart';
import '../services/firebase_service.dart';
import 'theme_viewmodel.dart';

/// Perfil, preferências e cota de escaneamentos do usuário logado.
class UserViewModel extends ChangeNotifier {
  UserViewModel({
    required this.uid,
    required this._firebase,
    required this._theme,
    String? fallbackName,
  }) : _profile = UserProfile(uid: uid, name: fallbackName) {
    _sub = _firebase.watchProfile(uid).listen(_onProfile, onError: (_) {});
  }

  final String uid;
  final FirebaseService _firebase;
  final ThemeViewModel _theme;
  late final StreamSubscription<UserProfile> _sub;

  UserProfile _profile;
  UserProfile get profile => _profile;

  void _onProfile(UserProfile p) {
    // Mantém o nome do Auth enquanto o documento ainda não foi criado.
    _profile = p.name == null && _profile.name != null
        ? UserProfile(
            uid: p.uid,
            name: _profile.name,
            email: p.email,
            autoSendToList: p.autoSendToList,
            darkMode: p.darkMode,
            scanPeriod: p.scanPeriod,
            scanCount: p.scanCount,
          )
        : p;
    _theme.setDark(_profile.darkMode);
    notifyListeners();
  }

  int get scansUsed => _profile.scansUsedThisMonth();

  int scansRemaining({required bool isPremium}) => isPremium
      ? 999
      : (AppConstants.freeScansPerMonth - scansUsed)
          .clamp(0, AppConstants.freeScansPerMonth);

  bool canScan({required bool isPremium}) =>
      isPremium || scansRemaining(isPremium: false) > 0;

  void registerScan() => _firebase.registerScan(uid, _profile);

  void setDarkMode(bool value) {
    _theme.setDark(value);
    _firebase.updatePreferences(uid, darkMode: value);
  }

  void setAutoSendToList(bool value) =>
      _firebase.updatePreferences(uid, autoSendToList: value);

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
