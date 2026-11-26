import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common_widgets.dart';

/// Folha de login/cadastro por e-mail e senha.
///
/// Fica numa folha (e não na tela principal) para que a tela de entrada
/// caiba inteira, sem rolagem, e o teclado nunca empurre a ilustração.
class EmailAuthSheet extends StatefulWidget {
  const EmailAuthSheet({super.key, required this.startAsRegister});

  final bool startAsRegister;

  static Future<void> show(BuildContext context, {required bool register}) {
    final auth = context.read<AuthViewModel>()..clearError();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EmailAuthSheet(startAsRegister: register),
    ).whenComplete(auth.clearError);
  }

  @override
  State<EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<EmailAuthSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late bool _isRegister = widget.startAsRegister;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _password.addListener(() {
      if (_isRegister) setState(() {}); // atualiza o medidor de força
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(bool register) {
    context.read<AuthViewModel>().clearError();
    _formKey.currentState?.reset();
    setState(() => _isRegister = register);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthViewModel>();
    final navigator = Navigator.of(context);
    final ok = _isRegister
        ? await auth.register(_name.text, _email.text, _password.text)
        : await auth.signIn(_email.text, _password.text);
    // Sucesso: fecha a folha; o AuthGate troca para o app sozinho.
    if (ok && navigator.mounted) navigator.pop();
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final auth = context.read<AuthViewModel>();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_reset_rounded, size: 40),
        title: const Text('Recuperar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digite o e-mail da sua conta. Enviaremos um link para você '
              'criar uma nova senha.',
            ),
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
            child: const Text('Enviar link'),
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Entrar')),
                    ButtonSegment(value: true, label: Text('Criar conta')),
                  ],
                  selected: {_isRegister},
                  onSelectionChanged: (s) => _setMode(s.first),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _isRegister
                          ? 'Leva menos de 1 minuto 🚀'
                          : 'Que bom ter você de volta 👋',
                      style: context.text.bodyLarge?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _isRegister
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Seu nome',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().length < 2)
                                ? 'Informe seu nome'
                                : null,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (v) =>
                      (v == null ||
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
                  autofillHints: [
                    _isRegister
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    helperText: _isRegister ? 'Mínimo de 6 caracteres' : null,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Mostrar senha' : 'Esconder senha',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'A senha precisa de pelo menos 6 caracteres'
                      : null,
                ),
                if (_isRegister && _password.text.isNotEmpty)
                  _PasswordStrength(password: _password.text),
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
                  AuthErrorBanner(message: auth.error!),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});

  final String password;

  /// 0 = fraca, 1 = média, 2 = forte.
  int get _score {
    var points = 0;
    if (password.length >= 8) points++;
    if (password.length >= 12) points++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      points++;
    }
    if (RegExp(r'\d').hasMatch(password)) points++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) points++;
    if (password.length < 6) return 0;
    return points >= 4 ? 2 : (points >= 2 ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final (label, color) = switch (score) {
      0 => ('Senha fraca', AppColors.danger),
      1 => ('Senha média', AppColors.warning),
      _ => ('Senha forte', AppColors.mint),
    };
    return Semantics(
      liveRegion: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: i <= score ? color : color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Text(label, style: context.text.labelSmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Faixa de erro que "balança" quando a mensagem muda (feedback imediato).
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(message),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 5) * (1 - t) * 9, 0),
        child: child,
      ),
      child: Semantics(
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
      ),
    );
  }
}
