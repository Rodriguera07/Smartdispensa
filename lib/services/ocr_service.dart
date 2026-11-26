import 'dart:isolate';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/receipt_item.dart';
import 'receipt_parser.dart';

/// Leitura de notas fiscais 100% **offline e gratuita**.
///
/// Pipeline:
/// 1. `image_picker` captura (câmera) ou seleciona (galeria) a foto,
///    já redimensionada para economizar memória;
/// 2. **Google ML Kit** reconhece o texto no próprio aparelho (thread nativa,
///    sem API paga, sem internet);
/// 3. As linhas são convertidas em objetos simples ([OcrLine]) e o
///    [ReceiptParser] roda em um **isolate separado** (`Isolate.run`),
///    garantindo que a UI continue a 60/120 fps durante o processamento.
class OcrService {
  OcrService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  TextRecognizer? _recognizer;

  TextRecognizer get _textRecognizer =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  /// Abre câmera ou galeria. Retorna `null` se o usuário cancelar.
  Future<XFile?> pickImage({required bool fromCamera}) {
    return _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // 2400px de largura mantém o texto do cupom nítido sem estourar a RAM
      // de aparelhos de entrada.
      maxWidth: 2400,
      maxHeight: 4000,
      imageQuality: 92,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  /// Executa OCR + parsing na imagem indicada.
  Future<ReceiptScanResult> scanReceipt(String imagePath) async {
    final recognized =
        await _textRecognizer.processImage(InputImage.fromFilePath(imagePath));

    final lines = <OcrLine>[
      for (final block in recognized.blocks)
        for (final line in block.lines)
          OcrLine(
            line.text,
            line.boundingBox.left,
            line.boundingBox.top,
            line.boundingBox.height,
          ),
    ];

    if (lines.isEmpty) {
      return const ReceiptScanResult(items: []);
    }

    // Parsing pesado (regex sobre dezenas/centenas de linhas) fora da UI.
    return Isolate.run(
      () => const ReceiptParser().parse(ReceiptParser.buildRows(lines)),
      debugName: 'receipt-parser',
    );
  }

  /// Libera os recursos nativos do ML Kit.
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
