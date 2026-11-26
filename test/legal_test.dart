import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dispensa/core/legal/legal_markdown.dart';

void main() {
  group('Leitor de Markdown legal', () {
    test('títulos, listas, negrito, itálico e variáveis', () {
      final blocks = parseLegalMarkdown(
        '# Título\n\n_Atualizado: {{DATA}}_\n\nTexto **forte** aqui.\n\n- item um\n1. passo',
        {'DATA': '26/11/2026'},
      );
      expect(blocks[0], isA<LegalHeading>());
      final italic = (blocks[1] as LegalParagraph).spans.single;
      expect(italic.italic, isTrue);
      expect(italic.text, 'Atualizado: 26/11/2026');
      final strong = (blocks[2] as LegalParagraph).spans;
      expect(strong[1].bold, isTrue);
      expect(strong[1].text, 'forte');
      expect((blocks[3] as LegalListItem).number, isNull);
      expect((blocks[4] as LegalListItem).number, 1);
    });

    test('tabela', () {
      final blocks = parseLegalMarkdown('| A | B |\n|---|---|\n| 1 | **2** |', {});
      final t = blocks.single as LegalTable;
      expect(t.header.length, 2);
      expect(t.rows.single[1].single.bold, isTrue);
    });

    test('nome de pacote com sublinhado não vira itálico', () {
      final spans = parseLegalInline('br.com.smart_dispensa.app');
      expect(spans.single.italic, isFalse);
    });
  });

  group('Documentos do app', () {
    final config = (jsonDecode(File('assets/legal/config.json').readAsStringSync())
            as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, '$v'));

    for (final doc in LegalDoc.values) {
      test('${doc.slug}: abre e não tem variáveis sem valor', () {
        final md = File(doc.assetPath).readAsStringSync();
        final resolved = applyLegalVars(md, config);
        expect(RegExp(r'\{\{[A-Z_]+\}\}').hasMatch(resolved), isFalse,
            reason: 'Todo {{CAMPO}} precisa existir em config.json');
        final blocks = parseLegalMarkdown(md, config);
        expect(blocks.whereType<LegalHeading>().first.level, 1);
        expect(blocks.length, greaterThan(5));
      });
    }

    test('termos explicam teste grátis, cancelamento e reembolso', () {
      final md = File(LegalDoc.terms.assetPath).readAsStringSync();
      expect(md, contains('7 dias'));
      expect(md, contains('Cancelar assinatura'));
      expect(md, contains('art. 49'));
    });
  });
}
