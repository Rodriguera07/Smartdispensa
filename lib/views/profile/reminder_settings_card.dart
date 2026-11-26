import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/reminder_settings.dart';
import '../../viewmodels/reminder_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';

/// Configuração dos lembretes de compra do mês (Perfil).
class ReminderSettingsCard extends StatelessWidget {
  const ReminderSettingsCard({super.key});

  Future<void> _apply(BuildContext context, ReminderSettings next) async {
    final ok = await context.read<ReminderViewModel>().update(next);
    if (!ok && context.mounted) {
      showAppSnack(
        context,
        'Permita as notificações do Smart Dispensa nas configurações do Android',
        icon: Icons.notifications_off_rounded,
      );
    }
  }

  Future<void> _pickTime(BuildContext context, ReminderSettings s) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
      helpText: 'Horário do lembrete',
    );
    if (picked != null && context.mounted) {
      await _apply(context, s.copyWith(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReminderViewModel>();
    final s = vm.settings;
    final next = vm.nextReminder;
    final time =
        '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';

    return GlassCard(
      blur: false,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _DayRow(
            icon: Icons.wb_sunny_rounded,
            title: 'Início do mês',
            subtitle: 'Hoje é dia da compra do mês',
            enabled: s.startEnabled,
            day: s.startDay,
            days: ReminderSettings.startDays,
            onToggle: (v) => _apply(context, s.copyWith(startEnabled: v)),
            onDay: (d) => _apply(context, s.copyWith(startDay: d)),
          ),
          const Divider(indent: 16, endIndent: 16),
          _DayRow(
            icon: Icons.nights_stay_rounded,
            title: 'Fim do mês',
            subtitle: 'Prepare a lista da próxima compra',
            enabled: s.endEnabled,
            day: s.endDay,
            days: ReminderSettings.endDays,
            onToggle: (v) => _apply(context, s.copyWith(endEnabled: v)),
            onDay: (d) => _apply(context, s.copyWith(endDay: d)),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            enabled: s.anyEnabled,
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Horário'),
            trailing: Text(time, style: context.text.titleMedium),
            onTap: () => _pickTime(context, s),
          ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      size: 18, color: AppColors.mint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Próximo lembrete: ${Fmt.dayMonth(next)}, $time',
                      style: context.text.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: vm.notificationsSupported
                        ? () async {
                            await vm.sendTest();
                            if (context.mounted) {
                              showAppSnack(context, 'Notificação de teste enviada');
                            }
                          }
                        : null,
                    child: const Text('Testar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.day,
    required this.days,
    required this.onToggle,
    required this.onDay,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final int day;
  final List<int> days;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Icon(icon, color: enabled ? AppColors.mint : context.colors.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.bodyLarge),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          // Seletor do dia (só faz sentido com o lembrete ligado).
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : 0.4,
            child: PopupMenuButton<int>(
              enabled: enabled,
              tooltip: 'Escolher o dia',
              initialValue: day,
              onSelected: onDay,
              itemBuilder: (_) => [
                for (final d in days) PopupMenuItem(value: d, child: Text('Dia $d')),
              ],
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(color: context.colors.outline),
                ),
                child: Text('Dia $day', style: context.text.labelLarge),
              ),
            ),
          ),
          Switch(value: enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
