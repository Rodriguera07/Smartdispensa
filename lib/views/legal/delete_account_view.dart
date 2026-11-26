import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/legal/legal_markdown.dart';
import '../../core/legal/legal_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import 'legal_view.dart';

/// Exclusão definitiva da conta e de todos os dados.
///
/// Exigida pelo Google Play para apps com cadastro e garantida pela LGPD
/// (art. 18, VI). Três travas contra exclusão acidental: digitar "EXCLUIR",
/// confirmar a identidade (senha ou Google) e um aviso sobre a assinatura,
/// que **não** é cancelada pela exclusão.
class DeleteAccountView extends StatefulWidget {
  const DeleteAccountView({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DeleteAccountView()),
      );

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<AuthViewModel>().clearError());
  }

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.deleteAccount(
      password: auth.usesPasswordSignIn ? _password.text : null,
    );
    if (!ok) return; // o erro aparece no banner
    // A sessão já acabou: o AuthGate volta para o login sozinho.
    messenger.showSnackBar(const SnackBar(
      content: Text('Sua conta e seus dados foram excluídos.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final premium = context.select<SubscriptionViewModel, bool>((s) => s.isPremium);
    final usesPassword = auth.usesPasswordSignIn;
    final confirmed = _confirm.text.trim().toUpperCase() == 'EXCLUIR' &&
        (!usesPassword || _password.text.length >= 6);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Excluir minha conta')),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const Center(child: Text('⚠️', style: TextStyle(fontSize: 52))),
              const SizedBox(height: 8),
              Text(
                'Esta ação é definitiva',
                textAlign: TextAlign.center,
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Não será possível recuperar a conta nem os dados depois.',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              const GlassCard(
                blur: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bullet('Sua conta de acesso (e-mail / login Google)'),
                    _Bullet('Despensa, lista de compras e histórico de compras'),
                    _Bullet('Histórico de preços, relatórios e preferências'),
                    _Bullet('Lembretes agendados neste aparelho'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Aviso de assinatura: o mais comum é a pessoa achar que excluir
              // a conta cancela a cobrança.
              GlassCard(
                blur: false,
                borderColor: AppColors.gold.withValues(alpha: 0.6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card_off_rounded,
                            color: AppColors.gold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            premium
                                ? 'Você tem uma assinatura ativa'
                                : 'Tem assinatura Premium?',
                            style: context.text.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Excluir a conta NÃO cancela a assinatura. Cancele no '
                      'Google Play antes, para não ser cobrado.',
                      style: context.text.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: LegalRepository.openPlaySubscriptions,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Abrir assinaturas'),
                        ),
                        TextButton(
                          onPressed: () => LegalView.open(context, LegalDoc.cancel),
                          child: const Text('Como cancelar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('Para confirmar, digite EXCLUIR', style: context.text.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _confirm,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'EXCLUIR'),
              ),
              if (usesPassword) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Sua senha',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Mostrar senha' : 'Esconder senha',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  'Na próxima etapa, confirme com a sua conta Google.',
                  style: context.text.bodySmall,
                ),
              ],
              if (auth.error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Text(auth.error!, style: context.text.bodyMedium),
                ),
              ],
              const SizedBox(height: 22),
              GlowButton(
                label: 'Excluir conta definitivamente',
                icon: Icons.delete_forever_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B78), AppColors.danger],
                ),
                glowColor: AppColors.danger,
                foreground: Colors.white,
                loading: auth.busy,
                onPressed: confirmed ? _delete : null,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar, quero manter minha conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.remove_circle_outline_rounded,
              size: 20, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
