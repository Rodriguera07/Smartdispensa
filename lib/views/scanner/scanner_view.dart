import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/firebase_service.dart';
import '../../services/ocr_service.dart';
import '../../viewmodels/pantry_viewmodel.dart';
import '../../viewmodels/scanner_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../paywall/paywall_view.dart';
import 'receipt_review_view.dart';

/// Scanner Inteligente de Nota Fiscal.
class ScannerView extends StatelessWidget {
  const ScannerView({super.key});

  /// Abre o scanner respeitando a cota do plano Grátis.
  static Future<void> open(BuildContext context) async {
    final premium = context.read<SubscriptionViewModel>().isPremium;
    final user = context.read<UserViewModel>();

    if (!user.canScan(isPremium: premium)) {
      await PaywallView.open(
        context,
        reason: 'Você já usou seus ${AppConstants.freeScansPerMonth} '
            'escaneamentos grátis deste mês. Com o Premium o scanner é ilimitado!',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (c) => ScannerViewModel(
            uid: user.uid,
            firebase: c.read<FirebaseService>(),
            ocr: c.read<OcrService>(),
            onScanConsumed: user.registerScan,
          ),
          child: const ScannerView(),
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar leitura?'),
        content: const Text('Os itens lidos desta nota não serão salvos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScannerViewModel>();
    final inReview = vm.status == ScanStatus.review;

    return PopScope(
      canPop: !inReview,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard(context)) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(inReview ? 'Conferir itens' : 'Escanear Nota Fiscal'),
        ),
        extendBodyBehindAppBar: true,
        body: GradientBackground(
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (vm.status) {
                ScanStatus.idle => const _IdleBody(key: ValueKey('idle')),
                ScanStatus.processing =>
                  const _ProcessingBody(key: ValueKey('processing')),
                ScanStatus.error => const _ErrorBody(key: ValueKey('error')),
                ScanStatus.review => ReceiptReviewView(
                    key: const ValueKey('review'),
                    onSave: () => _save(context),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }

  void _save(BuildContext context) {
    final vm = context.read<ScannerViewModel>();
    final saved = vm.save(context.read<PantryViewModel>().items);
    if (saved == 0) {
      showAppSnack(context, 'Nenhum item válido para salvar',
          icon: Icons.info_rounded);
      return;
    }
    Navigator.of(context).pop();
    showAppSnack(context, '🎉 $saved itens adicionados à sua despensa!');
  }
}

// =============================================================================
// Estados
// =============================================================================

class _IdleBody extends StatelessWidget {
  const _IdleBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ScannerViewModel>();
    final premium = context.select<SubscriptionViewModel, bool>((s) => s.isPremium);
    final remaining = context.select<UserViewModel, int>(
      (u) => u.scansRemaining(isPremium: false),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        GlassCard(
          radius: AppTheme.radiusL,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mint.withValues(alpha: 0.4),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    size: 48, color: AppColors.petroleum),
              ),
              const SizedBox(height: 18),
              Text('Fotografe sua nota fiscal',
                  textAlign: TextAlign.center, style: context.text.titleLarge),
              const SizedBox(height: 8),
              Text(
                'A leitura acontece no seu celular, sem internet e sem '
                'custo. Depois você confere tudo antes de salvar.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _Tip(emoji: '💡', text: 'Use um lugar bem iluminado'),
        const _Tip(emoji: '📏', text: 'Deixe a nota reta e esticada'),
        const _Tip(emoji: '🔍', text: 'Enquadre a parte com os produtos'),
        const SizedBox(height: 22),
        GlowButton(
          label: 'Tirar foto da nota',
          icon: Icons.photo_camera_rounded,
          onPressed: () => vm.scan(fromCamera: true),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => vm.scan(fromCamera: false),
          icon: const Icon(Icons.photo_library_rounded),
          label: const Text('Escolher da galeria'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: vm.startManualReview,
          child: const Text('Prefiro digitar os itens'),
        ),
        const SizedBox(height: 8),
        Center(
          child: premium
              ? const PremiumBadge(label: 'Scanner ilimitado')
              : Text(
                  '$remaining de ${AppConstants.freeScansPerMonth} '
                  'escaneamentos grátis restantes este mês',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: context.text.bodyLarge)),
        ],
      ),
    );
  }
}

class _ProcessingBody extends StatefulWidget {
  const _ProcessingBody({super.key});

  @override
  State<_ProcessingBody> createState() => _ProcessingBodyState();
}

class _ProcessingBodyState extends State<_ProcessingBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Lendo sua nota fiscal',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              height: 200,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GlassCard(
                      child: Column(
                        children: List.generate(
                          7,
                          (i) => Container(
                            height: 8,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            width: i.isEven ? 110 : 80,
                            decoration: BoxDecoration(
                              color: context.colors.onSurface
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Linha de "laser" do scanner.
                  AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) => Positioned(
                      left: 8,
                      right: 8,
                      top: 12 + 170 * _c.value,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.mint.withValues(alpha: 0.8),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Lendo sua nota...', style: context.text.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Reconhecendo produtos, quantidades e preços',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ScannerViewModel>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        EmptyState(
          emoji: '🧾',
          title: 'Não conseguimos ler',
          message: vm.error ?? 'Tente novamente.',
        ),
        GlowButton(
          label: 'Tentar outra foto',
          icon: Icons.photo_camera_rounded,
          onPressed: () => vm.scan(fromCamera: true),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: vm.startManualReview,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Adicionar manualmente'),
        ),
        TextButton(onPressed: vm.reset, child: const Text('Voltar')),
      ],
    );
  }
}
