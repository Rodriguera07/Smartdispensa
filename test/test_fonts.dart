import 'dart:io';

import 'package:flutter/services.dart';

/// Em testes, todo texto usa a fonte "Ahem" (cada letra é um quadrado largo),
/// o que gera estouros de layout que não existem no aparelho.
///
/// Este auxiliar registra a Roboto do próprio SDK do Flutter com os nomes de
/// família que o `google_fonts` usa (Inter e Plus Jakarta Sans), deixando a
/// medição de texto nos testes bem mais próxima da real.
Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<ByteData> bytes(String file) async {
    final data = await File('$dir/$file').readAsBytes();
    return ByteData.sublistView(data);
  }

  // variante do google_fonts → arquivo Roboto equivalente
  const variants = {
    'regular': 'Roboto-Regular.ttf',
    '500': 'Roboto-Medium.ttf',
    '600': 'Roboto-Bold.ttf',
    '700': 'Roboto-Bold.ttf',
    '800': 'Roboto-Black.ttf',
    '900': 'Roboto-Black.ttf',
    'italic': 'Roboto-Italic.ttf',
  };

  for (final family in const ['Inter', 'PlusJakartaSans']) {
    for (final v in variants.entries) {
      final loader = FontLoader('${family}_${v.key}')..addFont(bytes(v.value));
      await loader.load();
    }
  }
  final roboto = FontLoader('monospace')..addFont(bytes('Roboto-Regular.ttf'));
  await roboto.load();
}
