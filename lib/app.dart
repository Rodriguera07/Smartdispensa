import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/ocr_service.dart';
import 'services/subscription_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/pantry_viewmodel.dart';
import 'viewmodels/reminder_viewmodel.dart';
import 'viewmodels/shopping_list_viewmodel.dart';
import 'viewmodels/subscription_viewmodel.dart';
import 'viewmodels/theme_viewmodel.dart';
import 'viewmodels/user_viewmodel.dart';
import 'views/auth/login_view.dart';
import 'views/home/home_shell.dart';
import 'views/splash/splash_view.dart';

/// Raiz do aplicativo.
///
/// ### Árvore de dependências
/// ```text
/// Serviços (singletons)       FirebaseService · OcrService · SubscriptionService
/// Globais                     ThemeViewModel · AuthViewModel
/// Sessão (por usuário logado) UserViewModel · SubscriptionViewModel ·
///                             PantryViewModel · ShoppingListViewModel ·
///                             ReminderViewModel
/// ```
/// Os providers de sessão ficam no `builder` do MaterialApp — **acima do
/// Navigator** — para que rotas empilhadas (Scanner, Paywall...) também os
/// enxerguem. São recriados a cada login (chave = uid) e descartados no
/// logout, o que fecha os listeners do Firestore automaticamente.
class SmartDispensaApp extends StatelessWidget {
  const SmartDispensaApp({
    super.key,
    this.firebase,
    this.ocr,
    this.subscriptions,
    this.notifications,
  });

  /// Serviços injetáveis (testes e modo demonstração). Quando `null`,
  /// usa as implementações reais.
  final FirebaseService? firebase;
  final OcrService? ocr;
  final SubscriptionService? subscriptions;
  final NotificationService? notifications;

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => firebase ?? FirebaseService()),
        Provider(
          create: (_) => ocr ?? OcrService(),
          dispose: (_, s) => s.dispose(),
        ),
        Provider(create: (_) => subscriptions ?? SubscriptionService()),
        Provider(create: (_) => notifications ?? NotificationService()),
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        ChangeNotifierProvider(
          create: (c) => AuthViewModel(
            c.read<FirebaseService>(),
            c.read<SubscriptionService>(),
            c.read<NotificationService>(),
          ),
        ),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Smart Dispensa',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          themeAnimationDuration: const Duration(milliseconds: 250),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) => _SessionScope(child: child!),
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

/// Injeta os ViewModels da sessão quando há usuário logado.
class _SessionScope extends StatelessWidget {
  const _SessionScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthViewModel, ({String uid, String? name})?>(
      (a) => a.user == null
          ? null
          : (uid: a.user!.uid, name: a.user!.displayName),
    );
    if (user == null) return child;

    return MultiProvider(
      key: ValueKey(user.uid),
      providers: [
        ChangeNotifierProvider(
          create: (c) => UserViewModel(
            uid: user.uid,
            firebase: c.read<FirebaseService>(),
            theme: c.read<ThemeViewModel>(),
            fallbackName: user.name,
          ),
        ),
        ChangeNotifierProvider(
          create: (c) => SubscriptionViewModel(c.read<SubscriptionService>()),
        ),
        ChangeNotifierProvider(
          create: (c) => PantryViewModel(
            uid: user.uid,
            firebase: c.read<FirebaseService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (c) => ShoppingListViewModel(
            uid: user.uid,
            firebase: c.read<FirebaseService>(),
            pantry: c.read<PantryViewModel>(),
          ),
        ),
        ChangeNotifierProvider(
          // lazy: false → começa a reagendar os lembretes assim que o
          // usuário entra, mesmo sem abrir a tela de perfil.
          lazy: false,
          create: (c) => ReminderViewModel(
            user: c.read<UserViewModel>(),
            pantry: c.read<PantryViewModel>(),
            shopping: c.read<ShoppingListViewModel>(),
            notifications: c.read<NotificationService>(),
          ),
        ),
      ],
      child: child,
    );
  }
}

/// Decide entre Splash, Login e o app principal.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  /// Tempo mínimo da splash, para a marca respirar (sem atrasar o Firebase).
  bool _minSplashDone = false;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _minSplashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    // No logout, fecha qualquer rota empilhada (scanner, paywall...).
    final uid = auth.user?.uid;
    if (_lastUid != null && uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SmartDispensaApp.navigatorKey.currentState
            ?.popUntil((r) => r.isFirst);
      });
    }
    _lastUid = uid;

    final Widget page;
    if (!auth.initialized || !_minSplashDone) {
      page = const SplashView();
    } else if (auth.user == null) {
      page = const LoginView();
    } else {
      page = const HomeShell();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
    );
  }
}
