/// Configuração dos lembretes de compra do mês.
///
/// Dois lembretes independentes, um no **início** e outro no **fim** do mês,
/// porque a maioria das famílias faz a compra grande perto do pagamento
/// (5º dia útil ou dia 30). Os dias vão só até 28 para existirem em todo mês,
/// inclusive fevereiro.
class ReminderSettings {
  const ReminderSettings({
    this.startEnabled = false,
    this.startDay = 5,
    this.endEnabled = false,
    this.endDay = 28,
    this.hour = 9,
    this.minute = 0,
  });

  final bool startEnabled;
  final int startDay;
  final bool endEnabled;
  final int endDay;
  final int hour;
  final int minute;

  /// Dias permitidos em cada lembrete.
  static const startDays = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  static const endDays = [20, 21, 22, 23, 24, 25, 26, 27, 28];

  bool get anyEnabled => startEnabled || endEnabled;

  ReminderSettings copyWith({
    bool? startEnabled,
    int? startDay,
    bool? endEnabled,
    int? endDay,
    int? hour,
    int? minute,
  }) {
    return ReminderSettings(
      startEnabled: startEnabled ?? this.startEnabled,
      startDay: startDay ?? this.startDay,
      endEnabled: endEnabled ?? this.endEnabled,
      endDay: endDay ?? this.endDay,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  factory ReminderSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ReminderSettings();
    int day(Object? v, int fallback) =>
        ((v as num?)?.toInt() ?? fallback).clamp(1, 28);
    return ReminderSettings(
      startEnabled: (m['startEnabled'] as bool?) ?? false,
      startDay: day(m['startDay'], 5),
      endEnabled: (m['endEnabled'] as bool?) ?? false,
      endDay: day(m['endDay'], 28),
      hour: ((m['hour'] as num?)?.toInt() ?? 9).clamp(0, 23),
      minute: ((m['minute'] as num?)?.toInt() ?? 0).clamp(0, 59),
    );
  }

  Map<String, dynamic> toMap() => {
        'startEnabled': startEnabled,
        'startDay': startDay,
        'endEnabled': endEnabled,
        'endDay': endDay,
        'hour': hour,
        'minute': minute,
      };

  /// Próxima data em que o lembrete do dia [day] dispara a partir de [now].
  DateTime nextOccurrence(int day, DateTime now) {
    var candidate = DateTime(now.year, now.month, day, hour, minute);
    if (!candidate.isAfter(now)) {
      candidate = DateTime(now.year, now.month + 1, day, hour, minute);
    }
    return candidate;
  }

  /// O próximo lembrete ativo (ou `null` se nenhum estiver ligado).
  DateTime? nextReminder(DateTime now) {
    final dates = [
      if (startEnabled) nextOccurrence(startDay, now),
      if (endEnabled) nextOccurrence(endDay, now),
    ]..sort();
    return dates.isEmpty ? null : dates.first;
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.startEnabled == startEnabled &&
      other.startDay == startDay &&
      other.endEnabled == endEnabled &&
      other.endDay == endDay &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode =>
      Object.hash(startEnabled, startDay, endEnabled, endDay, hour, minute);
}
