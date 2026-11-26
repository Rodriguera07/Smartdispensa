import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'widgets/common_widgets.dart';
import 'widgets/gradient_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar transparente para o gradiente ocupar a tela toda.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await initializeDateFormatting('pt_BR');
  await AppTheme.preloadFonts();

  try {
    // Lê as credenciais de android/app/google-services.json.
    await Firebase.initializeApp();
    FirebaseService.configureFirestore(); // persistência offline
  } catch (e) {
    runApp(FirebaseSetupErrorApp(error: e.toString()));
    return;
  }

  // Notificações locais: prepara o canal e captura um toque que abriu o app.
  final notifications = NotificationService();
  await notifications.init();

  runApp(SmartDispensaApp(notifications: notifications));
}

/// Tela exibida se o Firebase não estiver configurado (ex.: falta o
/// `google-services.json`). Evita uma tela branca sem explicação.
class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 72),
                  const SizedBox(height: 32),
                  Text(
                    'Firebase não configurado',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Adicione o arquivo android/app/google-services.json '
                    'gerado no Console do Firebase e rode o app novamente.\n\n'
                    'Detalhe: $error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
