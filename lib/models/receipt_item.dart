import 'item_category.dart';

/// Item extraído de uma nota fiscal pelo OCR, ainda **não salvo**.
///
/// É mutável de propósito: a tela de Pré-Validação edita os campos
/// diretamente antes da confirmação do usuário.
class ReceiptItem {
  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.unit = 'un',
    ItemCategory? category,
    this.include = true,
    this.rawLine,
  }) : category = category ?? ItemCategory.guess(name);

  String name;
  double quantity;
  String unit;
  double unitPrice;
  ItemCategory category;

  /// Se o usuário desmarcar, o item é ignorado ao salvar.
  bool include;

  /// Linha original do cupom (ajuda o usuário a conferir o OCR).
  final String? rawLine;

  double get total => quantity * unitPrice;

  @override
  String toString() =>
      'ReceiptItem($name, $quantity $unit x $unitPrice = $total, ${category.name})';
}

/// Resultado completo da leitura de uma nota.
class ReceiptScanResult {
  const ReceiptScanResult({
    required this.items,
    this.storeName,
    this.detectedTotal,
    this.rawText = '',
  });

  final List<ReceiptItem> items;
  final String? storeName;

  /// "VALOR TOTAL R$" impresso na nota, para conferência com a soma.
  final double? detectedTotal;

  final String rawText;

  bool get isEmpty => items.isEmpty;
  double get itemsTotal => items.fold(0, (sum, i) => sum + i.total);
}
