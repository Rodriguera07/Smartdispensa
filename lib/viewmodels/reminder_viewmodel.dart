import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/reminder_settings.dart';
import '../services/notification_service.dart';
import '../services/shopping_planner.dart';
import 'pantry_viewmodel.dart';
import 'shopping_list_viewmodel.dart';
import 'user_viewmodel.dart';

/// Mantém os lembretes da compra do mês sincronizados com a despensa.
///
/// Sempre que o estoque, a lista ou as preferências mudam, o plano é
/// recalculado e as notificações são **reagendadas** (com atraso de alguns
/// segundos para agrupar mudanças em sequência). Assim o texto da notificação
/// sempre reflete o estado mais recente salvo no aparelho.
class ReminderViewModel extends ChangeNotifier {
  ReminderViewModel({
    required this._user,
    required this._pantry,
    required this._shopping,
    required this._notifications,
  }) {
    _user.addListener(_onChange);
    _pantry.addListener(_onChange);
    _shopping.addListener(_onChange);
    _onChange();
  }

  final UserViewModel _user;
  final PantryViewModel _pantry;
  final ShoppingListViewModel _shopping;
  final NotificationService _notifications;
  static const _planner = ShoppingPlanner();

  Timer? _debounce;
  ReminderSettings? _lastScheduledSettings;
  String? _lastScheduledSignature;

  ReminderSettings get settings => _user.profile.reminders;
  bool get notificationsSupported => _notifications.supported;

  /// Plano atual (também usado pela folha "Montar compra do mês").
  MonthlyPlan buildPlan() => _planner.build(
        pantry: _pantry.items,
        purchases: _pantry.recentPurchases,
        shoppingList: _shopping.items,
      );

  DateTime? get nextReminder => settings.nextReminder(DateTime.now());

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _reschedule);
    notifyListeners();
  }

  Future<void> _reschedule() async {
    if (!_pantry.loaded) return;
    final s = settings;
    final plan = buildPlan();
    // Evita reagendar à toa se nada relevante mudou.
    final signature = NotificationService.buildMessage(plan, startOfMonth: true)
        .body;
    if (s == _lastScheduledSettings && signature == _lastScheduledSignature) {
      return;
    }
    _lastScheduledSettings = s;
    _lastScheduledSignature = signature;
    await _notifications.scheduleMonthlyReminders(s, plan);
  }

  /// Atualiza as preferências. Ao ligar um lembrete, pede a permissão.
  /// Retorna `false` se o usuário negar a permissão de notificações.
  Future<bool> update(ReminderSettings next) async {
    if (next.anyEnabled && !settings.anyEnabled) {
      final granted = await _notifications.requestPermission();
      if (!granted) return false;
    }
    _user.setReminders(next);
    return true;
  }

  Future<void> sendTest() async {
    await _notifications.requestPermission();
    await _notifications.showTest(buildPlan());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _user.removeListener(_onChange);
    _pantry.removeListener(_onChange);
    _shopping.removeListener(_onChange);
    super.dispose();
  }
}
