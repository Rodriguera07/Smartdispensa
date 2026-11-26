import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/formatters.dart';
import '../models/reminder_settings.dart';
import 'shopping_planner.dart';

/// Notificações **locais** (agendadas no próprio aparelho).
///
/// Custo zero e funcionam offline: não precisam de servidor nem do Firebase
/// Cloud Messaging. O texto do lembrete é **reagendado sempre que a despensa
/// muda**, então a notificação já chega com os números atuais ("3 em falta,
/// 4 acabando, estimativa R$ 182,40").
class NotificationService {
  static const _startId = 101;
  static const _endId = 102;
  static const _testId = 199;

  /// Payload que abre a folha "Montar compra do mês".
  static const actionMonthlyPlan = 'monthly_plan';

  static const _channel = AndroidNotificationDetails(
    'shopping_reminders',
    'Lembretes de compras',
    channelDescription: 'Aviso do dia da compra do mês com o que está faltando',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF00D09C),
    category: AndroidNotificationCategory.reminder,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Ação pendente vinda de um toque na notificação (consumida pela UI).
  final ValueNotifier<String?> pendingAction = ValueNotifier(null);

  bool _ready = false;

  /// Notificações agendadas só existem no app Android (não na prévia web).
  bool get supported => !kIsWeb;

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tz_data.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      debugPrint('[Notifications] Fuso horário padrão (São Paulo): $e');
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (r) => pendingAction.value = r.payload,
      );
      // App aberto a partir de uma notificação (estava fechado).
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        pendingAction.value = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e) {
      debugPrint('[Notifications] Falha ao iniciar: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Pede a permissão de notificações (Android 13+). Retorna se foi concedida.
  Future<bool> requestPermission() async {
    if (!supported) return true;
    await init();
    try {
      return await _android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Conteúdo
  // ---------------------------------------------------------------------------

  /// Texto da notificação com base no plano atual.
  static ({String title, String body}) buildMessage(
    MonthlyPlan plan, {
    required bool startOfMonth,
  }) {
    final title = startOfMonth
        ? '🛒 Hoje é dia da compra do mês!'
        : '📅 Fim do mês: prepare a próxima compra';

    final parts = <String>[
      if (plan.outCount > 0) '${plan.outCount} em falta',
      if (plan.lowCount > 0) '${plan.lowCount} acabando',
    ];
    final estimate = plan.selectedEstimate;

    final String body;
    if (parts.isEmpty && plan.repeat.isEmpty) {
      body = 'Sua despensa está em dia 🎉 Toque para conferir.';
    } else {
      final what = parts.isEmpty
          ? 'Repita a compra do mês passado com 1 toque'
          : 'Na despensa: ${parts.join(' e ')}';
      final cost = estimate > 0 ? ' • estimativa ${Fmt.currency(estimate)}' : '';
      body = '$what$cost. Toque para montar sua lista.';
    }
    return (title: title, body: body);
  }

  // ---------------------------------------------------------------------------
  // Agendamento
  // ---------------------------------------------------------------------------

  /// (Re)agenda os lembretes mensais. Lembretes desligados são cancelados.
  Future<void> scheduleMonthlyReminders(
    ReminderSettings settings,
    MonthlyPlan plan,
  ) async {
    if (!supported) return;
    await init();
    if (!_ready) return;

    Future<void> scheduleOne(int id, bool enabled, int day, bool start) async {
      await _plugin.cancel(id: id);
      if (!enabled) return;
      final msg = buildMessage(plan, startOfMonth: start);
      final next = settings.nextOccurrence(day, DateTime.now());
      await _plugin.zonedSchedule(
        id: id,
        title: msg.title,
        body: msg.body,
        scheduledDate: tz.TZDateTime(
            tz.local, next.year, next.month, next.day, next.hour, next.minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.channelId,
            _channel.channelName,
            channelDescription: _channel.channelDescription,
            importance: _channel.importance,
            priority: _channel.priority,
            color: _channel.color,
            category: _channel.category,
            styleInformation: BigTextStyleInformation(msg.body),
          ),
        ),
        // Inexato: não exige a permissão especial de "alarmes exatos".
        // Atraso de alguns minutos não importa para um lembrete de compras.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Repete todo mês no mesmo dia e horário.
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        payload: actionMonthlyPlan,
      );
    }

    try {
      await scheduleOne(_startId, settings.startEnabled, settings.startDay, true);
      await scheduleOne(_endId, settings.endEnabled, settings.endDay, false);
    } catch (e) {
      debugPrint('[Notifications] Falha ao agendar: $e');
    }
  }

  /// Mostra agora uma notificação de exemplo (botão "Testar" no Perfil).
  Future<void> showTest(MonthlyPlan plan) async {
    if (!supported) return;
    await init();
    final msg = buildMessage(plan, startOfMonth: true);
    try {
      await _plugin.show(
        id: _testId,
        title: msg.title,
        body: msg.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.channelId,
            _channel.channelName,
            channelDescription: _channel.channelDescription,
            importance: _channel.importance,
            priority: _channel.priority,
            color: _channel.color,
            styleInformation: BigTextStyleInformation(msg.body),
          ),
        ),
        payload: actionMonthlyPlan,
      );
    } catch (e) {
      debugPrint('[Notifications] Falha no teste: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!supported || !_ready) return;
    await _plugin.cancelAll();
  }
}
