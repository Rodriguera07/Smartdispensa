import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/legal/legal_markdown.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/gradient_background.dart';
import '../legal/legal_view.dart';
import 'email_auth_sheet.dart';
import 'login_hero.dart';

/// Tela de entrada: **uma tela só, sem rolagem**.
///
/// - Topo: marca + mini-demonstração viva (nota → despensa) que se escala
///   para caber em qualquer altura de celular.
/// - Base: três ações claras: Google (1 toque), e-mail (abre uma folha) e
///   criar conta.
///
/// Só em casos extremos (aparelho deitado ou altura < 520 dp) a tela vira
/// rolável, para nada ficar inacessível.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  /// Controla a entrada escalonada dos blocos.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final Animation<double> _topIn = _interval(0.00, 0.45);
  late final Animation<double> _heroIn = _interval(0.12, 0.65);
  late final Animation<double> _panelIn = _interval(0.35, 1.00);

  bool _sheetOpen = false;

  Animation<double> _interval(double a, double b) => CurvedAnimation(
    parent: _intro,
    curve: Interval(a, b, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _openEmail({required bool register}) async {
    HapticFeedback.selectionClick();
    setState(() => _sheetOpen = true);
    await EmailAuthSheet.show(context, register: register);
    if (mounted) setState(() => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GradientBackground(
        child: Stack(
          children: [
            // Grade em perspectiva (estética "futurista").
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _GridPainter(
                      dark ? AppColors.mint : AppColors.mintDark,
                      dark ? 0.16 : 0.12,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  final compact = c.maxHeight < 520;

                  final column = Column(
                    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Reveal(animation: _topIn, child: const _TopBar()),
                      if (compact)
                        SizedBox(
                          height: 380,
                          child: _Reveal(
                            animation: _heroIn,
                            child: const _HeroGroup(),
                          ),
                        )
                      else
                        Expanded(
                          child: _Reveal(
                            animation: _heroIn,
                            child: const _HeroGroup(),
                          ),
                        ),
                      _Reveal(
                        animation: _panelIn,
                        child: _ActionPanel(
                          showError: !_sheetOpen,
                          onEmail: () => _openEmail(register: false),
                          onRegister: () => _openEmail(register: true),
                        ),
                      ),
                    ],
                  );

                  final padded = Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: column,
                  );
                  return compact
                      ? SingleChildScrollView(child: padded)
                      : padded;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Blocos
// =============================================================================

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLogo(size: 36, showName: false),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Smart '),
                    TextSpan(
                      text: 'Dispensa',
                      style: TextStyle(color: context.colors.primary),
                    ),
                  ],
                ),
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // O selo encolhe (e some por último) em telas muito estreitas.
        Flexible(
          flex: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.glassFillDark : Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: context.colors.outline),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('✨ Grátis', style: context.text.labelMedium),
            ),
          ),
        ),
      ],
    );
  }
}

/// Título + demonstração + dica, escalados juntos para caber no espaço livre.
class _HeroGroup extends StatelessWidget {
  const _HeroGroup();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Escaneie. Organize.\n'),
                    TextSpan(
                      text: 'Economize.',
                      style: TextStyle(color: context.colors.primary),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Leia suas notas fiscais e saiba o que falta na despensa.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              const LoginHero(),
              const SizedBox(height: 4),
              Text(
                '👆 Arraste ou toque no exemplo',
                style: context.text.labelSmall,
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.showError,
    required this.onEmail,
    required this.onRegister,
  });

  /// `false` enquanto a folha de e-mail está aberta (ela mostra o próprio erro).
  final bool showError;
  final VoidCallback onEmail;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final dark = context.isDark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showError && auth.error != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AuthErrorBanner(message: auth.error!),
                )
              : const SizedBox(width: double.infinity),
        ),
        _Pressable(
          child: _GoogleButton(
            // Spinner só quando o login Google está rodando aqui na tela.
            loading: auth.busy && showError,
            onPressed: auth.busy ? null : () => auth.signInWithGoogle(),
          ),
        ),
        const SizedBox(height: 10),
        _Pressable(
          child: OutlinedButton.icon(
            onPressed: auth.busy ? null : onEmail,
            style: OutlinedButton.styleFrom(
              backgroundColor: dark
                  ? AppColors.glassFillDark
                  : const Color(0xB3FFFFFF),
            ),
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Entrar com e-mail'),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Novo por aqui?', style: context.text.bodyMedium),
            TextButton(
              onPressed: auth.busy ? null : onRegister,
              child: const Text('Criar conta grátis'),
            ),
          ],
        ),
        const _ConsentText(),
      ],
    );
  }
}

// =============================================================================
// Componentes
// =============================================================================

/// Entrada: sobe e aparece.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// Dá resposta visual (leve "afundar") a qualquer botão, sem tomar o toque.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child});

  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [
          BoxShadow(
            color: AppColors.mint.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.65),
          minimumSize: const Size.fromHeight(AppTheme.minTouchTarget + 4),
          elevation: 0,
          // No tema claro, uma borda fina separa o botão branco do fundo.
          side: context.isDark
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFD5DCE2)),
        ),
        child: loading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _GoogleMark(),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Continuar com Google',
                      style: context.text.titleMedium?.copyWith(
                        color: const Color(0xFF1F1F1F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
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

// =============================================================================
// Fundo
// =============================================================================

/// Piso em grade com perspectiva, no estilo "synthwave" discreto.
class _GridPainter extends CustomPainter {
  const _GridPainter(this.color, this.opacity);

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.52;
    final vanish = Offset(size.width / 2, horizon);
    final floor = Rect.fromLTRB(0, horizon, size.width, size.height);

    // Esmaece da linha do horizonte (invisível) para a base (visível).
    final fade = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: opacity),
      ],
    ).createShader(floor);

    final paint = Paint()
      ..shader = fade
      ..strokeWidth = 1;

    // Linhas horizontais: espaçamento cresce com a proximidade.
    for (var i = 1; i <= 12; i++) {
      final y = horizon + floor.height * math.pow(i / 12, 2.1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Linhas que convergem para o ponto de fuga.
    for (var k = -9; k <= 9; k++) {
      final x = size.width / 2 + k * size.width / 6;
      canvas.drawLine(vanish, Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.color != color || old.opacity != opacity;
}
