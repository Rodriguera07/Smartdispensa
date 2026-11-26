import 'package:intl/intl.dart';

/// Formatação padronizada em português do Brasil.
abstract final class Fmt {
  static final NumberFormat _brl =
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 2);

  static final NumberFormat _qty = NumberFormat('#,##0.###', 'pt_BR');

  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _dayMonth = DateFormat("d 'de' MMM", 'pt_BR');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'pt_BR');

  /// `12.5` → `R$ 12,50`
  static String currency(num value) => _brl.format(value);

  /// `2.0` → `2`, `0.345` → `0,345`
  static String quantity(num value) => _qty.format(value);

  static String date(DateTime d) => _date.format(d);
  static String dayMonth(DateTime d) => _dayMonth.format(d);

  /// `novembro 2026` → `Novembro 2026`
  static String monthYear(DateTime d) {
    final s = _monthYear.format(d);
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  /// Converte texto digitado pelo usuário ("12,90", "R$ 1.299,90") em double.
  static double? parseMoney(String input) {
    var s = input.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (s.isEmpty) return null;
    if (s.contains(',')) {
      // Formato brasileiro: ponto = milhar, vírgula = decimal.
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(s);
  }
}

/// Utilidades de texto.
abstract final class TextUtils {
  static const _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  /// Remove acentos e caixa. Usado como chave de comparação entre itens
  /// ("Café Pilão 500g" == "CAFE PILAO 500G").
  static String normalize(String input) {
    final lower = input.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_accents[ch] ?? ch);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// "LEITE INTEGRAL ITALAC 1L" → "Leite Integral Italac 1L"
  static String titleCase(String input) {
    final words = input.toLowerCase().split(RegExp(r'\s+'));
    const keepLower = {'de', 'da', 'do', 'das', 'dos', 'e', 'com', 'p/', 'c/'};
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      // Medidas (1l, 500g, 2kg, 350ml) ficam em maiúsculas: 1L, 500G.
      if (RegExp(r'^\d+([.,]\d+)?(kg|g|l|ml|un|m)$').hasMatch(w)) {
        out.add(w.toUpperCase());
      } else if (i > 0 && keepLower.contains(w)) {
        out.add(w);
      } else {
        out.add(w[0].toUpperCase() + w.substring(1));
      }
    }
    return out.join(' ');
  }
}

/// Chave do período mensal (ex.: "2026-11"), usada na cota de scans.
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
