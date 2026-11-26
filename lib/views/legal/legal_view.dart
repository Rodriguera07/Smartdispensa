import 'package:material_ui/material_ui.dart';

import '../../core/legal/legal_markdown.dart';
import '../../core/legal/legal_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';

/// Exibe um documento legal (Privacidade, Termos, Cancelamento, Exclusão).
///
/// O texto vem de assets/legal/*.md — o mesmo publicado na web — então o app
/// funciona offline e nunca mostra uma versão diferente da página pública.
class LegalView extends StatelessWidget {
  const LegalView({super.key, required this.doc});

  final LegalDoc doc;

  static Future<void> open(BuildContext context, LegalDoc doc) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalView(doc: doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(doc.title)),
      body: GradientBackground(
        child: SafeArea(
          child: FutureBuilder<List<LegalBlock>>(
            future: LegalRepository.load(doc),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('Não foi possível abrir o documento.'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              // O título "# ..." do arquivo já está na AppBar.
              final blocks = snap.data!
                  .where((b) => !(b is LegalHeading && b.level == 1))
                  .toList();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                itemCount: blocks.length,
                itemBuilder: (context, i) => _LegalBlockView(block: blocks[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView({required this.block});

  final LegalBlock block;

  TextSpan _spans(BuildContext context, List<LegalSpan> spans, TextStyle? base) {
    return TextSpan(
      style: base,
      children: [
        for (final s in spans)
          TextSpan(
            text: s.text,
            style: TextStyle(
              fontWeight: s.bold ? FontWeight.w700 : null,
              fontStyle: s.italic ? FontStyle.italic : null,
              color: s.italic ? context.colors.onSurfaceVariant : null,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = context.text.bodyLarge?.copyWith(height: 1.55);
    return switch (block) {
      LegalHeading(:final level, :final text) => Padding(
          padding: EdgeInsets.only(top: level == 2 ? 24 : 16, bottom: 6),
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: level == 2 ? context.text.titleLarge : context.text.titleMedium,
            ),
          ),
        ),
      LegalParagraph(:final spans) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text.rich(_spans(context, spans, body)),
        ),
      LegalListItem(:final spans, :final number) => Padding(
          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  number == null ? '•' : '$number.',
                  style: body?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(child: Text.rich(_spans(context, spans, body))),
            ],
          ),
        ),
      LegalTable(:final header, :final rows) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          // Em tela de celular, cada linha vira um cartão (mais legível que
          // uma tabela espremida).
          child: Column(
            children: [
              for (final row in rows)
                GlassCard(
                  blur: false,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < row.length; c++) ...[
                        if (c < header.length)
                          Text.rich(
                            _spans(context, header[c], context.text.labelSmall),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text.rich(
                            _spans(context, row[c], context.text.bodyMedium),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
    };
  }
}
