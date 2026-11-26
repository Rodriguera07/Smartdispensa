import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';

/// Login e Cadastro (E-mail/Senha + Google) com recuperação de senha.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isRegister = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthViewModel>();
    if (_isRegister) {
      await auth.register(_name.text, _email.text, _password.text);
    } else {
      await auth.signIn(_email.text, _password.text);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text);
    final auth = context.read<AuthViewModel>();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enviaremos um link para você criar uma nova senha.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Seu e-mail',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.trim().isEmpty) return;

    final error = await auth.sendPasswordReset(email);
    if (!mounted) return;
    showAppSnack(
      context,
      error ?? 'Pronto! Confira sua caixa de entrada (e o spam).',
      icon: error == null ? Icons.mark_email_read_rounded : Icons.error_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    const AppLogo(size: 84),
                    const SizedBox(height: 8),
                    Text(
                      'Controle sua despensa, economize no mercado.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 28),
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      radius: AppTheme.radiusL,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ModeSwitch(
                              isRegister: _isRegister,
                              onChanged: (v) {
                                auth.clearError();
                                setState(() => _isRegister = v);
                              },
                            ),
                            const SizedBox(height: 20),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              child: _isRegister
                                  ? Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: TextFormField(
                                        controller: _name,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [AutofillHints.name],
                                        decoration: const InputDecoration(
                                          labelText: 'Seu nome',
                                          prefixIcon:
                                              Icon(Icons.person_outline_rounded),
                                        ),
                                        validator: (v) =>
                                            (v == null || v.trim().length < 2)
                                                ? 'Informe seu nome'
                                                : null,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: (v) => (v == null ||
                                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                          .hasMatch(v.trim()))
                                  ? 'Digite um e-mail válido'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Mostrar senha'
                                      : 'Esconder senha',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Mínimo de 6 caracteres'
                                  : null,
                            ),
                            if (!_isRegister)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _forgotPassword,
                                  child: const Text('Esqueci minha senha'),
                                ),
                              )
                            else
                              const SizedBox(height: 16),
                            if (auth.error != null) ...[
                              _ErrorBanner(message: auth.error!),
                              const SizedBox(height: 12),
                            ],
                            GlowButton(
                              label: _isRegister ? 'Criar minha conta' : 'Entrar',
                              icon: _isRegister
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.login_rounded,
                              loading: auth.busy,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('ou', style: context.text.bodySmall),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: auth.busy
                                  ? null
                                  : () => auth.signInWithGoogle(),
                              icon: const _GoogleMark(),
                              label: const Text('Continuar com Google'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Funciona offline • Seus dados ficam seguros na sua conta',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.isRegister, required this.onChanged});

  final bool isRegister;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: false, label: Text('Entrar')),
        ButtonSegment(value: true, label: Text('Criar conta')),
      ],
      selected: {isRegister},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: context.text.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// "G" do Google desenhado em texto (sem asset de marca).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}
