import 'package:material_ui/material_ui.dart';

/// Controla o modo de tema do app (escuro premium por padrão).
///
/// Fica na raiz da árvore porque o `MaterialApp` precisa dele antes mesmo
/// do login. A preferência é sincronizada com o perfil no Firestore pelo
/// [UserViewModel].
class ThemeViewModel extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void setDark(bool dark) {
    final next = dark ? ThemeMode.dark : ThemeMode.light;
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
  }
}
