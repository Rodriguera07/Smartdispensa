import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';
import '../paywall/paywall_view.dart';
import 'reminder_settings_card.dart';

/// Perfil, preferências e assinatura.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
            'Seus dados continuam salvos e voltam quando você entrar de novo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthViewModel>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserViewModel>();
    final subs = context.watch<SubscriptionViewModel>();
    final theme = context.watch<ThemeViewModel>();
    final profile = user.profile;
    final email = profile.email ?? context.read<AuthViewModel>().user?.email ?? '';
    final displayName = (profile.name?.isNotEmpty ?? false) ? profile.name! : 'Olá!';
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
        children: [
          GlassCard(
            radius: AppTheme.radiusL,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.mint.withValues(alpha: 0.2),
                  child: Text(initials, style: context.text.titleLarge),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: context.text.titleLarge),
                      Text(email,
                          style: context.text.bodyMedium?.copyWith(
                              color: context.colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Status da assinatura
          GlassCard(
            onTap: subs.isPremium ? null : () => PaywallView.open(context),
            borderColor: AppColors.gold.withValues(alpha: 0.5),
            gradient: LinearGradient(colors: [
              AppColors.gold.withValues(alpha: 0.14),
              AppColors.gold.withValues(alpha: 0.04),
            ]),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.gold, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subs.isPremium ? 'Você é Premium ✨' : 'Plano Grátis',
                        style: context.text.titleMedium,
                      ),
                      Text(
                        subs.isPremium
                            ? 'Scanner ilimitado, relatórios e histórico de preços'
                            : '${user.scansRemaining(isPremium: false)} de '
                                '${AppConstants.freeScansPerMonth} scans restantes • '
                                'Teste o Premium ${AppConstants.trialDays} dias grátis',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!subs.isPremium) const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SectionHeader(title: 'Preferências'),
          GlassCard(
            blur: false,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_rounded),
                  title: const Text('Tema escuro'),
                  subtitle: const Text('Visual premium, mais confortável à noite'),
                  value: theme.isDark,
                  onChanged: user.setDarkMode,
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.shopping_cart_checkout_rounded),
                  title: const Text('Enviar à lista automaticamente'),
                  subtitle: const Text(
                      'Quando um item acabar, vai direto para a lista de compras'),
                  value: profile.autoSendToList,
                  onChanged: user.setAutoSendToList,
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Lembretes de compras'),
          const ReminderSettingsCard(),
          const SectionHeader(title: 'Conta'),
          GlassCard(
            blur: false,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Restaurar compras'),
                  onTap: () async {
                    final ok = await subs.restore();
                    if (context.mounted) {
                      showAppSnack(
                        context,
                        ok
                            ? 'Assinatura restaurada ✨'
                            : 'Nenhuma assinatura ativa encontrada.',
                        icon: ok ? Icons.check_circle_rounded : Icons.info_rounded,
                      );
                    }
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                const ListTile(
                  leading: Icon(Icons.manage_accounts_rounded),
                  title: Text('Gerenciar assinatura'),
                  subtitle: Text('Google Play › Pagamentos e assinaturas'),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                  title: const Text('Sair'),
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${AppConstants.appName} • feito com 💚 para sua casa',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
