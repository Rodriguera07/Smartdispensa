import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import 'legal_markdown.dart';

/// Carrega os documentos legais e os dados de contato (assets/legal/).
abstract final class LegalRepository {
  static Map<String, String>? _config;
  static final Map<LegalDoc, List<LegalBlock>> _cache = {};

  static Future<Map<String, String>> config() async {
    return _config ??= (jsonDecode(
      await rootBundle.loadString('assets/legal/config.json'),
    ) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, '$v'));
  }

  static Future<List<LegalBlock>> load(LegalDoc doc) async {
    final cached = _cache[doc];
    if (cached != null) return cached;
    final blocks = parseLegalMarkdown(
      await rootBundle.loadString(doc.assetPath),
      await config(),
    );
    return _cache[doc] = blocks;
  }

  /// E-mail de suporte (ou `null` se ainda não foi preenchido).
  static Future<String?> supportEmail() async {
    final email = (await config())['EMAIL'] ?? '';
    return email.contains('@') ? email : null;
  }

  // ---------------------------------------------------------------------------
  // Links externos
  // ---------------------------------------------------------------------------

  /// Página de assinaturas do Google Play, já filtrada para este app.
  static Future<bool> openPlaySubscriptions() async {
    final package = (await config())['PACKAGE'] ?? '';
    final uri = Uri.https(
      'play.google.com',
      '/store/account/subscriptions',
      {if (package.isNotEmpty) 'package': package},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Abre o app de e-mail com o assunto preenchido.
  static Future<bool> emailSupport({String subject = 'Suporte Smart Dispensa'}) async {
    final email = await supportEmail();
    if (email == null) return false;
    return launchUrl(Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}',
    ));
  }
}
