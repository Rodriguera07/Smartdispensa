// MODO DEMONSTRAÇÃO: roda o app inteiro com dados de exemplo, sem Firebase.
//
//   flutter run -d chrome -t lib/preview/main_preview.dart
//
// Parâmetros de URL (na web):
//   ?screen=login   começa deslogado (tela de login)
//   ?premium=1      simula assinante Premium (libera relatórios)
//   ?theme=light    abre no tema claro

import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import '../app.dart';
import 'demo_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  final params = Uri.base.queryParameters;
  final firebase = DemoFirebaseService(signedIn: params['screen'] != 'login');
  if (params['theme'] == 'light') {
    firebase.updatePreferences('demo-user', darkMode: false);
  }

  runApp(SmartDispensaApp(
    firebase: firebase,
    ocr: DemoOcrService(),
    subscriptions: DemoSubscriptionService(premium: params['premium'] == '1'),
  ));
}
