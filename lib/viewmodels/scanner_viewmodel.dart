import 'package:flutter/foundation.dart';

import '../models/item_category.dart';
import '../models/pantry_item.dart';
import '../models/purchase_record.dart';
import '../models/receipt_item.dart';
import '../services/firebase_service.dart';
import '../services/ocr_service.dart';

enum ScanStatus { idle, processing, review, error }

/// Fluxo do Scanner Inteligente: captura → OCR → pré-validação → salvar.
///
/// Criado com escopo da tela (é descartado ao sair do scanner).
class ScannerViewModel extends ChangeNotifier {
  ScannerViewModel({
    required this.uid,
    required this._firebase,
    required this._ocr,
    required this.onScanConsumed,
  });

  final String uid;
  final FirebaseService _firebase;
  final OcrService _ocr;

  /// Chamado quando um escaneamento válido deve contar na cota mensal.
  final VoidCallback onScanConsumed;

  ScanStatus _status = ScanStatus.idle;
  ScanStatus get status => _status;

  String? _error;
  String? get error => _error;

  ReceiptScanResult? _result;
  String? get storeName => _result?.storeName;
  double? get detectedTotal => _result?.detectedTotal;

  final List<ReceiptItem> _items = [];
  List<ReceiptItem> get items => List.unmodifiable(_items);

  int get includedCount => _items.where((i) => i.include).length;
  double get includedTotal =>
      _items.where((i) => i.include).fold(0.0, (s, i) => s + i.total);

  /// Abre câmera/galeria e processa a nota. Retorna `false` se cancelado.
  Future<bool> scan({required bool fromCamera}) async {
    final file = await _ocr.pickImage(fromCamera: fromCamera);
    if (file == null) return false;

    _status = ScanStatus.processing;
    _error = null;
    notifyListeners();

    try {
      final result = await _ocr.scanReceipt(file.path);
      _result = result;
      _items
        ..clear()
        ..addAll(result.items);

      if (result.isEmpty) {
        _status = ScanStatus.error;
        _error = 'Não encontramos itens nesta foto. Tente uma foto mais '
            'próxima, reta e bem iluminada — ou adicione os itens manualmente.';
      } else {
        _status = ScanStatus.review;
        onScanConsumed();
      }
    } catch (e) {
      debugPrint('[Scanner] $e');
      _status = ScanStatus.error;
      _error = 'Não foi possível ler a imagem. Tente novamente.';
    }
    notifyListeners();
    return true;
  }

  /// Permite revisar manualmente mesmo quando o OCR falha.
  void startManualReview() {
    _status = ScanStatus.review;
    if (_items.isEmpty) addEmptyItem();
    notifyListeners();
  }

  void reset() {
    _status = ScanStatus.idle;
    _items.clear();
    _result = null;
    _error = null;
    notifyListeners();
  }

  // --- Edição na Pré-Validação ----------------------------------------------

  void addEmptyItem() {
    _items.add(ReceiptItem(name: '', quantity: 1, unitPrice: 0));
    notifyListeners();
  }

  void updateItem(
    ReceiptItem item, {
    String? name,
    double? quantity,
    double? unitPrice,
    ItemCategory? category,
    bool? include,
  }) {
    if (name != null) item.name = name;
    if (quantity != null) item.quantity = quantity;
    if (unitPrice != null) item.unitPrice = unitPrice;
    if (category != null) item.category = category;
    if (include != null) item.include = include;
    notifyListeners();
  }

  void removeItem(ReceiptItem item) {
    _items.remove(item);
    notifyListeners();
  }

  /// Salva na despensa + histórico. Retorna quantos itens foram salvos.
  int save(List<PantryItem> currentPantry) {
    final valid = _items
        .where((i) => i.include && i.name.trim().isNotEmpty && i.quantity > 0)
        .toList();
    if (valid.isEmpty) return 0;

    _firebase.restockAndRecord(
      uid: uid,
      entries: [
        for (final i in valid)
          RestockEntry(
            name: i.name.trim(),
            category: i.category,
            quantity: i.quantity,
            unit: i.unit,
            unitPrice: i.unitPrice > 0 ? i.unitPrice : null,
          ),
      ],
      currentPantry: currentPantry,
      source: PurchaseSource.receipt,
      store: storeName,
    );
    return valid.length;
  }
}
