import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/legal/legal_markdown.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../legal/legal_view.dart';

/// Login e Cadastro.
///
/// Ordem pensada para todas as idades: primeiro o botão do Google (um toque,
/// sem senha para lembrar), depois e-mail e senha. Campos grandes, rótulos
/// sempre visíveis e mensagens de erro em português claro.
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

  void _toggleMode() {
    context.read<AuthViewModel>().clearError();
    _formKey.currentState?.reset();
    setState(() => _isRegister = !_isRegister);
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

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    const _Hero(),
                    const SizedBox(height: 22),
                    GlassCard(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                      radius: AppTheme.radiusL,
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(
                                  _isRegister ? 'Criar conta grátis' : 'Entrar',
                                  key: ValueKey(_isRegister),
                                  style: context.text.titleLarge,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _GoogleButton(
                                label: _isRegister
                                    ? 'Cadastrar com Google'
                                    : 'Continuar com Google',
                                onPressed: auth.busy
                                    ? null
                                    : () => auth.signInWithGoogle(),
                              ),
                              const SizedBox(height: 18),
                              const _OrDivider(text: 'ou use seu e-mail'),
                              const SizedBox(height: 18),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                child: _isRegister
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                        ),
                                        child: TextFormField(
                                          controller: _name,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.name,
                                          ],
                                          decoration: const InputDecoration(
                                            labelText: 'Seu nome',
                                            prefixIcon: Icon(
                                              Icons.person_outline_rounded,
                                            ),
                                          ),
                                          validator: (v) =>
                                              (v == null || v.trim().length < 2)
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
                                  helperText: _isRegister
                                      ? 'Mínimo de 6 caracteres'
                                      : null,
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? 'Mostrar senha'
                                        : 'Esconder senha',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
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
                                _ErrorBanner(message: auth.error!),
                                const SizedBox(height: 12),
                              ],
                              GlowButton(
                                label: _isRegister
                                    ? 'Criar minha conta'
                                    : 'Entrar',
                                icon: _isRegister
                                    ? Icons.person_add_alt_1_rounded
                                    : Icons.login_rounded,
                                loading: auth.busy,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _isRegister
                                        ? 'Já tem conta?'
                                        : 'Ainda não tem conta?',
                                    style: context.text.bodyMedium,
                                  ),
                                  TextButton(
                                    onPressed: _toggleMode,
                                    child: Text(
                                      _isRegister
                                          ? 'Entrar'
                                          : 'Criar conta grátis',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _ConsentText(),
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

// =============================================================================
// Topo: ilustração + proposta de valor
// =============================================================================

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _FloatingPantry(),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Sua despensa\n'),
              TextSpan(
                text: 'no controle.',
                style: TextStyle(color: context.colors.primary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: context.text.headlineLarge?.copyWith(height: 1.15),
        ),
        const SizedBox(height: 10),
        Text(
          'Escaneie a nota, saiba o que está faltando e economize no mercado.',
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _Benefit(emoji: '📸', text: 'Lê nota fiscal'),
            _Benefit(emoji: '🛒', text: 'Lista automática'),
            _Benefit(emoji: '🔔', text: 'Lembra da compra'),
            _Benefit(emoji: '📶', text: 'Funciona offline'),
          ],
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.glassFillDark : Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(text, style: context.text.labelMedium),
        ],
      ),
    );
  }
}

/// Logo central com produtos "flutuando" ao redor.
class _FloatingPantry extends StatefulWidget {
  const _FloatingPantry();

  @override
  State<_FloatingPantry> createState() => _FloatingPantryState();
}

class _FloatingPantryState extends State<_FloatingPantry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  // (emoji, deslocamento x, deslocamento y, fase da flutuação)
  static const _items = [
    ('🥛', -96.0, -30.0, 0.0),
    ('🍌', 94.0, -38.0, 0.25),
    ('🧾', -62.0, 40.0, 0.6),
    ('🥫', 70.0, 34.0, 0.5),
    ('🧴', -150.0, 18.0, 0.8),
    ('🍎', 146.0, 8.0, 0.35),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    const width = 340.0;
    const height = 150.0;

    return ExcludeSemantics(
      child: RepaintBoundary(
        // Em telas estreitas a ilustração encolhe em vez de ser cortada.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: width,
            height: height,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  for (final (emoji, dx, dy, phase) in _items)
                    Builder(
                      builder: (context) {
                        final t = reduceMotion ? 0.0 : _c.value;
                        final bob = math.sin((t + phase) * 2 * math.pi) * 5;
                        return Transform.translate(
                          offset: Offset(dx, dy + bob),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.isDark
                                  ? const Color(0xFF15304A)
                                  : Colors.white,
                              border: Border.all(color: context.colors.outline),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      },
                    ),
                  const AppLogo(size: 84, showName: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Componentes do formulário
// =============================================================================

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1F1F),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
        minimumSize: const Size.fromHeight(AppTheme.minTouchTarget + 4),
        side: context.isDark
            ? BorderSide.none
            : const BorderSide(color: Color(0xFFDADCE0)),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GoogleMark(),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: context.text.titleMedium?.copyWith(
                color: const Color(0xFF1F1F1F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "G" desenhado em texto (sem usar o arquivo de marca do Google).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF1F3F4),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: context.text.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
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

/// "Ao continuar, você concorda com..." com links para os documentos.
class _ConsentText extends StatelessWidget {
  const _ConsentText();

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodySmall;
    Widget link(String text, LegalDoc doc) => InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => LegalView.open(context, doc),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Text(
          text,
          style: style?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: context.colors.primary,
          ),
        ),
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Ao continuar, você concorda com os ', style: style),
        link('Termos de Uso', LegalDoc.terms),
        Text(' e a ', style: style),
        link('Política de Privacidade', LegalDoc.privacy),
        Text('.', style: style),
      ],
    );
  }
}
