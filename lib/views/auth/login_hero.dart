import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Mini-demonstração viva do app para a tela de login.
///
/// Conta a história do produto em 7 segundos, sem uma palavra de texto:
/// **uma nota fiscal é escaneada por um laser → cada item reconhecido voa
/// para a despensa → as barras de estoque enchem.**
///
/// Interativo: arraste para inclinar a cena em 3D (volta com mola) e toque
/// para rever a animação. Respeita "reduzir animações" (mostra o quadro final).
class LoginHero extends StatefulWidget {
  const LoginHero({super.key});

  /// Tamanho de projeto; quem usa pode escalar com `FittedBox`.
  static const Size size = Size(320, 270);

  @override
  State<LoginHero> createState() => _LoginHeroState();
}

class _Row {
  const _Row(this.receiptName, this.price, this.emoji, this.name, this.before);
  final String receiptName;
  final String price;
  final String emoji;
  final String name;

  /// Nível do estoque antes de a nota ser lida (0..1).
  final double before;
}

class _LoginHeroState extends State<LoginHero>
    with SingleTickerProviderStateMixin {
  static const _rows = [
    _Row('LEITE INTEG 1L', '4,99', '🥛', 'Leite', 0.12),
    _Row('ARROZ 5KG', '25,90', '🍚', 'Arroz', 0.22),
    _Row('CAFE PILAO 500G', '19,90', '☕', 'Café', 0.0),
    _Row('SABAO EM PO', '32,90', '🧼', 'Sabão', 0.30),
  ];

  // Geometria do recibo (em px de projeto).
  static const double _receiptW = 140;
  static const double _receiptH = 190;
  static const double _headerH = 36;
  static const double _rowH = 26;

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  Offset _tilt = Offset.zero;
  bool _dragging = false;

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _replay() {
    HapticFeedback.selectionClick();
    _loop
      ..reset()
      ..repeat();
  }

  /// Instante (0..1 do ciclo) em que o laser passa pelo centro da linha [i].
  double _rowTime(int i) {
    final center = _headerH + _rowH * i + _rowH / 2;
    return 0.12 + 0.5 * (center / _receiptH);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // É uma ilustração de tamanho fixo: não escala com a fonte do sistema
    // (o título e o texto ao redor continuam escalando normalmente).
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Semantics(
        label: 'Demonstração: o app lê uma nota fiscal e atualiza a despensa',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _replay,
            onPanStart: (_) => setState(() => _dragging = true),
            onPanUpdate: (d) => setState(() {
              _tilt = Offset(
                (_tilt.dx + d.delta.dx / 90).clamp(-1.0, 1.0),
                (_tilt.dy + d.delta.dy / 90).clamp(-1.0, 1.0),
              );
            }),
            onPanEnd: (_) => setState(() {
              _dragging = false;
              _tilt = Offset.zero;
            }),
            onPanCancel: () => setState(() {
              _dragging = false;
              _tilt = Offset.zero;
            }),
            child: TweenAnimationBuilder<Offset>(
              tween: Tween(begin: Offset.zero, end: _tilt),
              // Segue o dedo na hora; ao soltar, volta com efeito de mola.
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, tilt, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0013)
                  ..rotateX(-tilt.dy * 0.30)
                  ..rotateY(tilt.dx * 0.40),
                child: child,
              ),
              child: RepaintBoundary(
                child: SizedBox.fromSize(
                  size: LoginHero.size,
                  child: reduceMotion
                      ? _scene(context, 0.8)
                      : AnimatedBuilder(
                          animation: _loop,
                          builder: (context, _) => _scene(context, _loop.value),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cena
  // ---------------------------------------------------------------------------

  Widget _scene(BuildContext context, double t) {
    final dark = context.isDark;

    final enter = Curves.easeOutCubic.transform((t / 0.10).clamp(0.0, 1.0));
    final exit = Curves.easeIn.transform(((t - 0.93) / 0.07).clamp(0.0, 1.0));
    final receiptOpacity = enter * (1 - exit);

    // Balanço suave de "flutuação" enquanto ninguém mexe.
    final sway = _dragging ? 0.0 : math.sin(t * 2 * math.pi) * 0.05;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0010)
        ..rotateY(sway),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Halo de luz atrás da cena.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.62,
                    colors: [
                      AppColors.mint.withValues(alpha: dark ? 0.22 : 0.20),
                      AppColors.mint.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Despensa (direita).
          Positioned(
            right: 0,
            top: 22,
            width: 132,
            height: 184,
            child: _pantryPanel(context, t),
          ),
          // Recibo (esquerda), levemente inclinado.
          Positioned(
            left: 2,
            top: 12,
            width: _receiptW,
            height: _receiptH + 8,
            child: Opacity(
              opacity: receiptOpacity,
              child: Transform.translate(
                offset: Offset(-24 * (1 - enter), 10 * (1 - enter)),
                child: Transform.rotate(
                  angle: -0.05,
                  child: _receipt(context, t),
                ),
              ),
            ),
          ),
          // Partículas que voam do recibo para a despensa.
          for (var i = 0; i < _rows.length; i++) _particle(i, t),
          // Selo final.
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(child: _doneBadge(t)),
          ),
          // Passos: dizem em palavras o que a animação mostra.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 32,
            child: _steps(context, t),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recibo
  // ---------------------------------------------------------------------------

  Widget _receipt(BuildContext context, double t) {
    final scan = ((t - 0.12) / 0.5).clamp(0.0, 1.0);
    final laserY = scan * _receiptH;
    final laserVisible = scan > 0 && scan < 1;

    const ink = Color(0xFF2B2F36);
    const mono = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: ['Courier New', 'Courier'],
      fontSize: 9,
      height: 1.1,
      color: ink,
      fontWeight: FontWeight.w600,
    );

    final rows = <Widget>[
      for (var i = 0; i < _rows.length; i++)
        Builder(
          builder: (context) {
            final rec = Curves.easeOut.transform(
              ((t - _rowTime(i)) / 0.04).clamp(0.0, 1.0),
            );
            return Container(
              height: _rowH,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.transparent,
                  AppColors.mint.withValues(alpha: 0.30),
                  rec,
                ),
                border: Border(
                  left: BorderSide(
                    color: Color.lerp(
                      Colors.transparent,
                      AppColors.mintDark,
                      rec,
                    )!,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _rows[i].receiptName,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: mono,
                    ),
                  ),
                  Text(_rows[i].price, style: mono),
                ],
              ),
            );
          },
        ),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Sombra do papel.
        Positioned(
          left: 4,
          right: 4,
          top: 10,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
        ),
        ClipPath(
          clipper: const _ZigZagClipper(),
          child: ColoredBox(
            color: const Color(0xFFF8F6EF),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _headerH,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Column(
                          children: [
                            Text(
                              'SUPERMERCADO',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontFamilyFallback: ['Courier New', 'Courier'],
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'CUPOM FISCAL  •  NFC-e',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontFamilyFallback: ['Courier New', 'Courier'],
                                fontSize: 7.5,
                                color: Color(0xFF7A808A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...rows,
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 6, 8, 0),
                      child: Divider(height: 1, color: Color(0xFFB8BCC4)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
                      child: Row(
                        children: [
                          Text('TOTAL R\$', style: mono),
                          const Spacer(),
                          Text(
                            '83,69',
                            style: mono.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: SizedBox(
                        height: 17,
                        child: CustomPaint(painter: _BarcodePainter()),
                      ),
                    ),
                  ],
                ),
                // Feixe de luz atrás do laser.
                if (laserVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: laserY - 34,
                    height: 34,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.mint.withValues(alpha: 0),
                            AppColors.mint.withValues(alpha: 0.38),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Linha do laser.
                if (laserVisible)
                  Positioned(
                    left: -2,
                    right: -2,
                    top: laserY - 1,
                    height: 2.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.mint.withValues(alpha: 0.95),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Despensa
  // ---------------------------------------------------------------------------

  Widget _pantryPanel(BuildContext context, double t) {
    final dark = context.isDark;
    final reset = Curves.easeIn.transform(((t - 0.93) / 0.07).clamp(0.0, 1.0));

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xCC0E2236) : const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.40)),
        boxShadow: [
          BoxShadow(
            color: AppColors.mint.withValues(alpha: 0.18),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.kitchen_rounded,
                size: 14,
                color: AppColors.mint,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Despensa',
                    style: context.text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < _rows.length; i++)
            Expanded(child: _pantryRow(context, i, t, reset)),
        ],
      ),
    );
  }

  Widget _pantryRow(BuildContext context, int i, double t, double reset) {
    final row = _rows[i];
    final fill = Curves.easeOutCubic.transform(
      ((t - _rowTime(i) - 0.05) / 0.14).clamp(0.0, 1.0),
    );
    final level = _lerp(_lerp(row.before, 0.95, fill), row.before, reset);
    final ok = level > 0.45;
    final color = level < 0.2
        ? AppColors.danger
        : (level < 0.45 ? AppColors.warning : AppColors.mint);

    return Row(
      children: [
        Text(row.emoji, style: const TextStyle(fontSize: 19)),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 5,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: color.withValues(alpha: 0.18)),
                      ),
                      FractionallySizedBox(
                        widthFactor: level.clamp(0.04, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.7),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          size: 15,
          color: color,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Passos (legenda)
  // ---------------------------------------------------------------------------

  Widget _steps(BuildContext context, double t) {
    // 0 = fotografando/escaneando, 1 = lendo os itens, 2 = pronto.
    final active = t < 0.30 ? 0 : (t < 0.64 ? 1 : 2);
    const labels = [('📸', 'Fotografe'), ('🔍', 'Lemos'), ('✅', 'Pronto')];

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          Expanded(
            child: _stepChip(context, labels[i], i == active, i < active),
          ),
        ],
      ],
    );
  }

  Widget _stepChip(
    BuildContext context,
    (String, String) label,
    bool active,
    bool done,
  ) {
    final dark = context.isDark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: active
            ? AppColors.mint.withValues(alpha: dark ? 0.22 : 0.28)
            : (dark ? AppColors.glassFillDark : const Color(0x99FFFFFF)),
        border: Border.all(
          color: active
              ? AppColors.mint
              : (done
                    ? AppColors.mint.withValues(alpha: 0.35)
                    : context.colors.outline),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.mint.withValues(alpha: 0.4),
                  blurRadius: 14,
                ),
              ]
            : const [],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${label.$1} ${label.$2}',
            style: context.text.labelMedium?.copyWith(
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active || done
                  ? context.colors.onSurface
                  : context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Partículas e selo
  // ---------------------------------------------------------------------------

  Widget _particle(int i, double t) {
    final u = ((t - _rowTime(i)) / 0.10).clamp(0.0, 1.0);
    if (u <= 0 || u >= 1) return const SizedBox.shrink();

    final startX = 12 + _receiptW; // borda direita do recibo
    final startY = 12 + _headerH + _rowH * i + _rowH / 2;
    final endX = LoginHero.size.width - 132 + 22; // emoji na despensa
    final endY = 22 + 8 + 14 + 4 + (184 - 8 - 6 - 18 - 4) / 4 * (i + 0.5);

    final e = Curves.easeInOutCubic.transform(u);
    final x = _lerp(startX, endX, e);
    // Arco: sobe no meio do trajeto.
    final y = _lerp(startY, endY, e) - math.sin(e * math.pi) * 16;
    final fade = math.sin(u * math.pi).clamp(0.0, 1.0);

    return Positioned(
      left: x - 8,
      top: y - 8,
      child: Opacity(
        opacity: fade,
        child: Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.mint.withValues(alpha: 0.95),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text(_rows[i].emoji, style: const TextStyle(fontSize: 9)),
        ),
      ),
    );
  }

  Widget _doneBadge(double t) {
    final inP = Curves.easeOutBack.transform(
      ((t - 0.66) / 0.08).clamp(0.0, 1.0),
    );
    final out = ((t - 0.93) / 0.05).clamp(0.0, 1.0);
    final v = inP * (1 - out);
    if (v <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.8 + 0.2 * v,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: AppColors.mint.withValues(alpha: 0.55),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.petroleum,
              ),
              SizedBox(width: 6),
              Text(
                '4 itens na despensa',
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.petroleum,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Borda inferior serrilhada do papel do cupom.
class _ZigZagClipper extends CustomClipper<Path> {
  const _ZigZagClipper();

  @override
  Path getClip(Size size) {
    const tooth = 7.0;
    final path = Path()..lineTo(0, size.height - tooth);
    var x = 0.0;
    var down = false;
    while (x < size.width) {
      x = math.min(x + tooth, size.width);
      path.lineTo(x, size.height - (down ? 0 : tooth));
      down = !down;
    }
    return path
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Código de barras decorativo.
class _BarcodePainter extends CustomPainter {
  const _BarcodePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2B2F36);
    final rnd = math.Random(7);
    var x = 0.0;
    while (x < size.width) {
      final w = 0.8 + rnd.nextInt(3) * 0.9;
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w + 0.8 + rnd.nextInt(3) * 0.8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
