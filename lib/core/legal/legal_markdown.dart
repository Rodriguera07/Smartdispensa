// Leitor de Markdown mínimo para os documentos legais.
//
// Dart puro (sem Flutter): é usado pelas telas do app (LegalView) e pelo
// gerador das páginas web (tool/build_legal_pages.dart), garantindo que o
// texto do app e o publicado na web sejam exatamente o mesmo.
//
// Suporta: # títulos, parágrafos, listas (- e 1.), tabelas simples,
// **negrito** e _itálico_. Variáveis {{CHAVE}} vêm de assets/legal/config.json.

/// Trecho de texto com estilo.
class LegalSpan {
  const LegalSpan(this.text, {this.bold = false, this.italic = false});
  final String text;
  final bool bold;
  final bool italic;
}

sealed class LegalBlock {
  const LegalBlock();
}

class LegalHeading extends LegalBlock {
  const LegalHeading(this.level, this.text);
  final int level;
  final String text;
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.spans);
  final List<LegalSpan> spans;
}

class LegalListItem extends LegalBlock {
  const LegalListItem(this.spans, {this.number});
  final List<LegalSpan> spans;

  /// `null` para marcador (•), número para lista ordenada.
  final int? number;
}

class LegalTable extends LegalBlock {
  const LegalTable(this.header, this.rows);
  final List<List<LegalSpan>> header;
  final List<List<List<LegalSpan>>> rows;
}

/// Substitui `{{CHAVE}}` pelos valores da configuração.
String applyLegalVars(String text, Map<String, String> vars) =>
    text.replaceAllMapped(
      RegExp(r'\{\{([A-Z_]+)\}\}'),
      (m) => vars[m[1]] ?? m[0]!,
    );

/// Quebra `**negrito**` e `_itálico_` em trechos.
List<LegalSpan> parseLegalInline(String text) {
  final spans = <LegalSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|(?<![\w])_(.+?)_(?![\w])');
  var last = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > last) spans.add(LegalSpan(text.substring(last, m.start)));
    if (m[1] != null) {
      spans.add(LegalSpan(m[1]!, bold: true));
    } else {
      spans.add(LegalSpan(m[2]!, italic: true));
    }
    last = m.end;
  }
  if (last < text.length) spans.add(LegalSpan(text.substring(last)));
  return spans;
}

List<LegalBlock> parseLegalMarkdown(String source, Map<String, String> vars) {
  final lines = applyLegalVars(source, vars).split('\n');
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(LegalParagraph(parseLegalInline(paragraph.join(' '))));
    paragraph.clear();
  }

  List<String> cells(String row) => row
      .trim()
      .replaceAll(RegExp(r'^\||\|$'), '')
      .split('|')
      .map((c) => c.trim())
      .toList();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimRight();
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      flush();
      continue;
    }

    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flush();
      blocks.add(LegalHeading(heading[1]!.length, heading[2]!));
      continue;
    }

    final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flush();
      blocks.add(LegalListItem(parseLegalInline(bullet[1]!)));
      continue;
    }

    final ordered = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
    if (ordered != null) {
      flush();
      blocks.add(LegalListItem(
        parseLegalInline(ordered[2]!),
        number: int.parse(ordered[1]!),
      ));
      continue;
    }

    // Tabela: linha com | seguida de separador |---|
    if (trimmed.startsWith('|') &&
        i + 1 < lines.length &&
        RegExp(r'^\|?\s*:?-{3,}').hasMatch(lines[i + 1].trim())) {
      flush();
      final header = cells(trimmed).map(parseLegalInline).toList();
      final rows = <List<List<LegalSpan>>>[];
      i += 2;
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.add(cells(lines[i]).map(parseLegalInline).toList());
        i++;
      }
      i--;
      blocks.add(LegalTable(header, rows));
      continue;
    }

    paragraph.add(trimmed);
  }
  flush();
  return blocks;
}

/// Documentos legais disponíveis (arquivo em assets/legal/ e na web).
enum LegalDoc {
  privacy('privacidade', 'Política de Privacidade'),
  terms('termos', 'Termos de Uso'),
  cancel('cancelamento', 'Como cancelar a assinatura'),
  deleteAccount('excluir-conta', 'Excluir conta e dados');

  const LegalDoc(this.slug, this.title);

  final String slug;
  final String title;

  String get assetPath => 'assets/legal/$slug.md';
}
