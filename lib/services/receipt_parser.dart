import '../core/utils/formatters.dart';
import '../models/receipt_item.dart';

/// Linha de texto detectada pelo OCR com sua posição na imagem.
///
/// Usamos um tipo próprio (e não o `TextLine` do ML Kit) para que o
/// processamento rode em um **isolate** — objetos simples são copiáveis
/// entre isolates — e para que o parser seja testável sem o plugin nativo.
class OcrLine {
  const OcrLine(this.text, this.left, this.top, this.height);

  final String text;
  final double left;
  final double top;
  final double height;

  double get centerY => top + height / 2;
}

/// Parser de cupons fiscais brasileiros (NFC-e, SAT, cupons de supermercado
/// e atacarejo) baseado em expressões regulares.
///
/// Formatos suportados (exemplos reais simplificados):
///
/// ```text
/// 001 7891000100103 LEITE INTEGRAL 1L  2 UN X 4,99  9,98      (linha única)
/// 002 ARROZ TIO JOAO 5KG UN 1 X 25,90 F1 25,90               (unidade antes)
/// 003 BANANA PRATA KG 0,845 X 5,99 5,06                       (a granel)
/// CAFE PILAO 500G                                             (atacarejo:
///    1 UN X 18,90 18,90                                        2 linhas)
/// SABAO EM PO OMO 1,6KG 32,90                                 (só total)
/// ```
///
/// Toda a lógica é Dart puro e síncrona: é chamada via `Isolate.run` pelo
/// [OcrService] para não travar a UI.
class ReceiptParser {
  const ReceiptParser();

  // ---------------------------------------------------------------------------
  // Blocos de regex
  // ---------------------------------------------------------------------------

  /// Quantidade: "2", "1,000", "0.345".
  static const _qty = r'\d{1,4}(?:[.,]\d{1,3})?';

  /// Preço: "4,99", "1.299,90", "12.90".
  static const _price = r'\d{1,3}(?:\.\d{3})*,\d{2}|\d{1,5}[.,]\d{2}';

  /// Unidades comuns em cupons.
  static const _units =
      r'UNID|UND|UNI|UN|KGS|KG|GR|G|LT|L|ML|PCT|PC|CX|FD|DZ|BD|SC|EMB|FR|PT';

  /// Código de tributação que alguns cupons imprimem entre preço e total
  /// (F1, T01, I1, N1, T18%, 18%...).
  static const _tax = r'(?:[A-Z]{1,2}\d{0,2}(?:[.,]\d{1,2})?%?|\d{1,2}%)';

  /// Linha completa: descrição + qtd + (un) + X + unitário + (total).
  static final _fullLine = RegExp(
    '^(?<desc>.*?[A-Z]{2}.*?)\\s+'
    '(?:(?<u1>$_units)\\s+)?'
    '(?<qty>$_qty)\\s*(?<u2>$_units)?\\s*X\\s*'
    '(?<unit>$_price)'
    '(?:\\s*=?\\s*(?:$_tax\\s+)?(?<total>$_price))?',
  );

  /// Linha só com quantidade (2ª linha do formato atacarejo).
  static final _qtyLine = RegExp(
    '^(?:(?<u1>$_units)\\s+)?(?<qty>$_qty)\\s*(?<u2>$_units)?\\s*X\\s*'
    '(?<unit>$_price)'
    '(?:\\s*=?\\s*(?:$_tax\\s+)?(?<total>$_price))?',
  );

  /// Descrição seguida apenas do valor (quantidade 1 implícita).
  static final _namePrice = RegExp(
    '^(?<desc>.*[A-Z]{3}.*?)\\s+(?<total>$_price)\\s*(?:$_tax)?\\s*\$',
  );

  /// Total da nota.
  static final _totalLine = RegExp(
    r'(?:VALOR\s*TOTAL|TOTAL\s*(?:A\s*PAGAR|R\$|GERAL)|VALOR\s*A\s*PAGAR|^TOTAL)'
    '\\D{0,12}(?<v>$_price)',
  );

  /// Cabeçalho da tabela de itens: a partir daqui começam os produtos.
  static final _itemsHeader = RegExp(
    r'(DESCRI|C[OÓ]D(IGO)?\s+DESC|ITEM\s+C[OÓ]D|QTD\.?\s*UN|VL\.?\s*UNIT)',
  );

  /// Fim da área de itens.
  static final _itemsEnd = RegExp(
    r'^(SUB\s*TOTAL|TOTAL|VALOR\s*TOTAL|VALOR\s*A\s*PAGAR|QTD\.?\s*TOTAL|'
    r'QTDE\.?\s*TOTAL|FORMA\s*(DE)?\s*PAGAMENTO|TOTAL\s*DE\s*ITENS)',
  );

  /// Linhas que nunca são produtos.
  static final _blacklist = RegExp(
    r'(CNPJ|CPF|\bI\.?E\.?\b|INSCR|CUPOM|NFC-?E|NF-?E|DANFE|DOCUMENTO|'
    r'AUXILIAR|CONSUMIDOR|PROTOCOLO|CHAVE\s*DE|SERIE|S[EÉ]RIE|EXTRATO|'
    r'TROCO|DINHEIRO|CART[AÃ]O|CR[EÉ]DITO|D[EÉ]BITO|\bPIX\b|DESCONTO|'
    r'ACR[EÉ]SCIMO|TRIBUTO|LEI\s*\d|12\.?741|IBPT|APROXIMAD|CONSULTE|'
    r'WWW\.|HTTP|\.GOV|SEFAZ|OPERADOR|CAIXA\s*\d|PDV|OBRIGAD|VOLTE\s*SEMPRE|'
    r'ENDERE[CÇ]O|TELEFONE|FONE|^RUA\b|^AV\.?\b|BAIRRO|CEP\b|EMISS[AÃ]O|'
    r'VIA\s*CONSUMIDOR|PAGAMENTO|VALOR\s*PAGO|^QTD|^ITEM\s|^C[OÓ]D)',
  );

  // ---------------------------------------------------------------------------
  // Reconstrução de linhas
  // ---------------------------------------------------------------------------

  /// O ML Kit frequentemente separa as colunas de uma mesma linha do cupom
  /// em blocos diferentes ("LEITE 1L" à esquerda, "9,98" à direita).
  /// Agrupamos as linhas cujo centro vertical está próximo para reconstruir
  /// a linha "física" do papel, ordenando da esquerda para a direita.
  static List<String> buildRows(List<OcrLine> lines) {
    if (lines.isEmpty) return const [];

    final sorted = [...lines]..sort((a, b) => a.centerY.compareTo(b.centerY));

    final heights = sorted.map((l) => l.height).toList()..sort();
    final medianHeight = heights[heights.length ~/ 2];
    final tolerance = (medianHeight * 0.55).clamp(4.0, 60.0);

    final rows = <List<OcrLine>>[];
    var current = <OcrLine>[sorted.first];
    var currentCenter = sorted.first.centerY;

    for (final line in sorted.skip(1)) {
      if ((line.centerY - currentCenter).abs() <= tolerance) {
        current.add(line);
        // Média móvel do centro da linha.
        currentCenter =
            current.map((l) => l.centerY).reduce((a, b) => a + b) /
                current.length;
      } else {
        rows.add(current);
        current = [line];
        currentCenter = line.centerY;
      }
    }
    rows.add(current);

    return [
      for (final row in rows)
        (row..sort((a, b) => a.left.compareTo(b.left)))
            .map((l) => l.text.trim())
            .where((t) => t.isNotEmpty)
            .join(' '),
    ];
  }

  // ---------------------------------------------------------------------------
  // Parser principal
  // ---------------------------------------------------------------------------

  ReceiptScanResult parse(List<String> rawRows) {
    final rows = rawRows.map(_normalizeRow).where((r) => r.isNotEmpty).toList();

    final storeName = _detectStore(rows);
    final detectedTotal = _detectTotal(rows);

    // Se há cabeçalho de tabela, os itens começam depois dele.
    var start = 0;
    for (var i = 0; i < rows.length; i++) {
      if (_itemsHeader.hasMatch(rows[i])) {
        start = i + 1;
        break;
      }
    }

    final items = <ReceiptItem>[];
    String? pendingDescription;

    for (var i = start; i < rows.length; i++) {
      final row = rows[i];

      if (_itemsEnd.hasMatch(row)) break;
      if (_blacklist.hasMatch(row)) {
        pendingDescription = null;
        continue;
      }

      // 1) Linha só de quantidade → completa a descrição anterior.
      final qtyMatch = _qtyLine.firstMatch(row);
      if (qtyMatch != null) {
        if (pendingDescription != null) {
          final item = _buildItem(
            description: pendingDescription,
            qty: qtyMatch.namedGroup('qty'),
            unitToken: qtyMatch.namedGroup('u2') ?? qtyMatch.namedGroup('u1'),
            unitPrice: qtyMatch.namedGroup('unit'),
            total: qtyMatch.namedGroup('total'),
            raw: '$pendingDescription | $row',
          );
          if (item != null) items.add(item);
        }
        pendingDescription = null;
        continue;
      }

      // 2) Linha completa.
      final full = _fullLine.firstMatch(row);
      if (full != null) {
        final item = _buildItem(
          description: full.namedGroup('desc')!,
          qty: full.namedGroup('qty'),
          unitToken: full.namedGroup('u2') ?? full.namedGroup('u1'),
          unitPrice: full.namedGroup('unit'),
          total: full.namedGroup('total'),
          raw: row,
        );
        if (item != null) items.add(item);
        pendingDescription = null;
        continue;
      }

      // 3) Descrição + valor.
      final simple = _namePrice.firstMatch(row);
      if (simple != null) {
        final item = _buildItem(
          description: simple.namedGroup('desc')!,
          qty: '1',
          unitToken: null,
          unitPrice: null,
          total: simple.namedGroup('total'),
          raw: row,
        );
        if (item != null) items.add(item);
        pendingDescription = null;
        continue;
      }

      // 4) Só descrição → aguarda a linha de quantidade.
      if (RegExp(r'[A-Z]{3}').hasMatch(row)) {
        pendingDescription = row;
      }
    }

    return ReceiptScanResult(
      items: items,
      storeName: storeName,
      detectedTotal: detectedTotal,
      rawText: rawRows.join('\n'),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Corrige ruídos típicos do OCR antes de aplicar as regex.
  String _normalizeRow(String input) {
    var s = input.toUpperCase().trim();
    s = s.replaceAll(RegExp(r'[|_~`´"]'), ' ');
    // "4 , 99" → "4,99"
    s = s.replaceAllMapped(
      RegExp(r'(\d)\s*([,.])\s*(\d)'),
      (m) => '${m[1]}${m[2]}${m[3]}',
    );
    // Letra O lida no lugar de zero em preços: "4,9O" → "4,90".
    s = s.replaceAllMapped(
      RegExp(r'(\d[,.])([0-9O]{2})\b'),
      (m) => '${m[1]}${m[2]!.replaceAll('O', '0')}',
    );
    // Multiplicação: "2x4,99", "2 × 4,99", "2*4,99" → "2 X 4,99".
    s = s.replaceAllMapped(
      RegExp(r'(\d|[A-Z])\s*[X×\*]\s*(\d)'),
      (m) => '${m[1]} X ${m[2]}',
    );
    // "R$" solto antes de preços.
    s = s.replaceAll(RegExp(r'R\$\s*'), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _detectStore(List<String> rows) {
    for (final row in rows.take(6)) {
      if (_blacklist.hasMatch(row)) continue;
      final letters = RegExp(r'[A-Z]').allMatches(row).length;
      final digits = RegExp(r'\d').allMatches(row).length;
      if (letters >= 4 && digits <= 2) return TextUtils.titleCase(row);
    }
    return null;
  }

  double? _detectTotal(List<String> rows) {
    for (final row in rows) {
      final m = _totalLine.firstMatch(row);
      if (m != null && !row.contains('ITENS')) {
        return _toDouble(m.namedGroup('v'));
      }
    }
    return null;
  }

  ReceiptItem? _buildItem({
    required String description,
    required String? qty,
    required String? unitToken,
    required String? unitPrice,
    required String? total,
    required String raw,
  }) {
    final name = _cleanName(description);
    if (name.length < 2) return null;

    var quantity = _toDouble(qty) ?? 1;
    var unitValue = _toDouble(unitPrice);
    final totalValue = _toDouble(total);

    if (quantity <= 0 || quantity > 999) quantity = 1;

    // Reconciliação entre unitário, quantidade e total.
    if (unitValue == null && totalValue != null) {
      unitValue = totalValue / quantity;
    } else if (unitValue != null && totalValue != null) {
      final expected = unitValue * quantity;
      if ((expected - totalValue).abs() > 0.05) {
        if ((totalValue - unitValue).abs() <= 0.05) {
          quantity = 1; // quantidade mal lida pelo OCR
        } else {
          unitValue = totalValue / quantity; // unitário mal lido
        }
      }
    }

    if (unitValue == null || unitValue <= 0 || unitValue > 9999) return null;

    final unit = _normalizeUnit(unitToken, quantity);

    return ReceiptItem(
      name: TextUtils.titleCase(name),
      quantity: quantity,
      unit: unit,
      unitPrice: double.parse(unitValue.toStringAsFixed(2)),
      rawLine: raw,
    );
  }

  String _cleanName(String description) {
    var s = description.trim();
    // Número sequencial do item ("001 ").
    s = s.replaceFirst(RegExp(r'^\d{1,4}\s+'), '');
    // Código EAN/interno ("7891000100103 ").
    s = s.replaceFirst(RegExp(r'^\d{4,14}\s+'), '');
    // Unidade solta no fim ("... UN").
    s = s.replaceFirst(RegExp('\\s+(?:$_units)\$'), '');
    // Lixo de pontuação nas pontas.
    s = s.replaceAll(RegExp(r'^[^A-Z0-9]+|[^A-Z0-9%]+$'), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeUnit(String? token, double quantity) {
    switch (token) {
      case 'KG':
      case 'KGS':
        return 'kg';
      case 'G':
      case 'GR':
        return 'g';
      case 'L':
      case 'LT':
        return 'l';
      case 'ML':
        return 'ml';
      case null:
        // Quantidade fracionada sem unidade → produto pesado.
        return quantity % 1 != 0 ? 'kg' : 'un';
      default:
        return 'un';
    }
  }

  static double? _toDouble(String? input) {
    if (input == null || input.isEmpty) return null;
    var s = input;
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(s);
  }
}
