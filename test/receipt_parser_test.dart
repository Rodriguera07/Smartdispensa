import 'package:flutter_test/flutter_test.dart';
import 'package:smart_dispensa/models/item_category.dart';
import 'package:smart_dispensa/services/receipt_parser.dart';

void main() {
  const parser = ReceiptParser();

  group('ReceiptParser — NFC-e de supermercado', () {
    final result = parser.parse(const [
      'SUPERMERCADO BOM PRECO LTDA',
      'CNPJ: 12.345.678/0001-90 IE: 123456789',
      'DOCUMENTO AUXILIAR DA NOTA FISCAL DE CONSUMIDOR ELETRONICA',
      'ITEM COD DESCRICAO QTD UN VL UNIT VL TOTAL',
      '001 7891000100103 LEITE INTEGRAL ITALAC 1L 2 UN X 4,99 9,98',
      '002 7896006711112 ARROZ TIO JOAO 5KG UN 1 X 25,90 F1 25,90',
      '003 2000001 BANANA PRATA KG 0,845 X 5,99 5,06',
      '004 7891024134702 DETERGENTE YPE 500ML 3UNx2,49 7,47',
      'QTD. TOTAL DE ITENS 4',
      'VALOR TOTAL R\$ 48,41',
      'CARTAO DE CREDITO 48,41',
    ]);

    test('extrai todos os itens', () {
      expect(result.items, hasLength(4));
    });

    test('nome, quantidade e preço do leite', () {
      final leite = result.items[0];
      expect(leite.name, 'Leite Integral Italac 1L');
      expect(leite.quantity, 2);
      expect(leite.unitPrice, 4.99);
      expect(leite.category, ItemCategory.laticinios);
    });

    test('unidade antes da quantidade e código tributário', () {
      final arroz = result.items[1];
      expect(arroz.name, 'Arroz Tio Joao 5KG');
      expect(arroz.quantity, 1);
      expect(arroz.unitPrice, 25.90);
      expect(arroz.category, ItemCategory.mercearia);
    });

    test('produto a granel em kg', () {
      final banana = result.items[2];
      expect(banana.quantity, closeTo(0.845, 0.0001));
      expect(banana.unit, 'kg');
      expect(banana.category, ItemCategory.hortifruti);
    });

    test('multiplicação colada "3UNx2,49"', () {
      final det = result.items[3];
      expect(det.quantity, 3);
      expect(det.unitPrice, 2.49);
      expect(det.category, ItemCategory.limpeza);
    });

    test('total e loja detectados', () {
      expect(result.detectedTotal, 48.41);
      expect(result.storeName, 'Supermercado Bom Preco Ltda');
    });
  });

  group('ReceiptParser — atacarejo (2 linhas por item)', () {
    final result = parser.parse(const [
      'ATACADAO S.A.',
      'CODIGO DESCRICAO',
      '7891910000197 CAFE PILAO TRADICIONAL 500G',
      '2 UN X 18,90 37,80',
      '7891149103102 SABAO EM PO OMO 1,6KG',
      '1 UN X 32,9O 32,90',
      'SUBTOTAL 70,70',
    ]);

    test('junta descrição e quantidade', () {
      expect(result.items, hasLength(2));
      expect(result.items[0].name, 'Cafe Pilao Tradicional 500G');
      expect(result.items[0].quantity, 2);
      expect(result.items[0].unitPrice, 18.90);
    });

    test('corrige "O" lido no lugar de zero', () {
      expect(result.items[1].unitPrice, 32.90);
    });
  });

  test('descrição seguida só do valor assume quantidade 1', () {
    final result = parser.parse(const ['REFRIGERANTE COCA COLA 2L 9,49']);
    expect(result.items, hasLength(1));
    expect(result.items.single.quantity, 1);
    expect(result.items.single.unitPrice, 9.49);
    expect(result.items.single.category, ItemCategory.bebidas);
  });

  test('ignora linhas de pagamento, tributos e troco', () {
    final result = parser.parse(const [
      'TRIBUTOS APROXIMADOS LEI 12.741 R\$ 5,20',
      'TROCO 2,00',
      'DESCONTO 1,00',
    ]);
    expect(result.items, isEmpty);
  });

  test('reconstrói linhas a partir de blocos separados do OCR', () {
    final rows = ReceiptParser.buildRows(const [
      OcrLine('LEITE INTEGRAL 1L', 10, 100, 20),
      OcrLine('9,98', 400, 103, 20), // mesma linha física, coluna direita
      OcrLine('2 UN X 4,99', 200, 98, 20),
      OcrLine('ARROZ 5KG 1 X 25,90 25,90', 10, 140, 20),
    ]);
    expect(rows, [
      'LEITE INTEGRAL 1L 2 UN X 4,99 9,98',
      'ARROZ 5KG 1 X 25,90 25,90',
    ]);
  });
}
