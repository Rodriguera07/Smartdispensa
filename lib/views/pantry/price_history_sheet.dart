import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/purchase_record.dart';
import '../../services/firebase_service.dart';
import '../../viewmodels/pantry_viewmodel.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_card.dart';

/// Histórico de variação de preço de um produto (Premium ✨).
class PriceHistorySheet extends StatefulWidget {
  const PriceHistorySheet({super.key, required this.productName});

  final String productName;

  static Future<void> show(BuildContext context, String productName) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PriceHistorySheet(productName: productName),
    );
  }

  @override
  State<PriceHistorySheet> createState() => _PriceHistorySheetState();
}

class _PriceHistorySheetState extends State<PriceHistorySheet> {
  late final Future<List<PurchaseRecord>> _future = context
      .read<FirebaseService>()
      .fetchPriceHistory(
        context.read<PantryViewModel>().uid,
        TextUtils.normalize(widget.productName),
      );

  @override
  Widget build(BuildContext context) {
    final productName = widget.productName;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => FutureBuilder<List<PurchaseRecord>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final history = snap.data!;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(productName, style: context.text.headlineSmall),
                  ),
                  const PremiumBadge(compact: true),
                ],
              ),
              const SizedBox(height: 4),
              Text('Histórico de preços', style: context.text.bodyMedium),
              const SizedBox(height: 20),
              if (history.isEmpty)
                const EmptyState(
                  emoji: '📈',
                  title: 'Sem histórico ainda',
                  message: 'Escaneie suas notas fiscais para acompanhar a '
                      'variação de preço deste produto.',
                )
              else ...[
                _Stats(history: history),
                const SizedBox(height: 16),
                if (history.length >= 2)
                  GlassCard(
                    child: SizedBox(
                      height: 140,
                      child: CustomPaint(
                        painter: _SparklinePainter(
                          history.map((h) => h.unitPrice).toList(),
                          context.colors.primary,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                for (final h in history.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long_rounded),
                    title: Text(Fmt.currency(h.unitPrice),
                        style: context.text.titleMedium),
                    subtitle: Text(
                      '${Fmt.date(h.date)}${h.store != null ? ' • ${h.store}' : ''}',
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.history});

  final List<PurchaseRecord> history;

  @override
  Widget build(BuildContext context) {
    final prices = history.map((h) => h.unitPrice).toList();
    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    final avg = prices.reduce((a, b) => a + b) / prices.length;
    final change = prices.length >= 2 && prices.first > 0
        ? (prices.last - prices.first) / prices.first * 100
        : 0.0;
    final up = change > 0;

    Widget tile(String label, String value, {Color? color}) => Expanded(
          child: Column(
            children: [
              Text(label, style: context.text.bodySmall),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  value,
                  style: context.text.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        );

    return GlassCard(
      radius: AppTheme.radiusM,
      child: Row(
        children: [
          tile('Menor', Fmt.currency(min), color: AppColors.mint),
          tile('Média', Fmt.currency(avg)),
          tile('Maior', Fmt.currency(max), color: AppColors.danger),
          tile(
            'Variação',
            '${up ? '▲' : change < 0 ? '▼' : ''} ${change.abs().toStringAsFixed(1)}%',
            color: up ? AppColors.danger : AppColors.mint,
          ),
        ],
      ),
    );
  }
}

/// Gráfico de linha minimalista, sem dependências externas.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs() < 0.01 ? 1.0 : max - min;

    Offset point(int i) => Offset(
          size.width * i / (values.length - 1),
          size.height - ((values[i] - min) / range) * (size.height - 16) - 8,
        );

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(point(i), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
