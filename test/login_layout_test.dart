import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:smart_dispensa/core/theme/app_theme.dart';
import 'package:smart_dispensa/preview/demo_services.dart';
import 'package:smart_dispensa/viewmodels/auth_viewmodel.dart';
import 'package:smart_dispensa/views/auth/login_view.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadTestFonts(); // medição de texto realista (em vez da fonte Ahem)
    await initializeDateFormatting('pt_BR');
  });

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthViewModel(
          DemoFirebaseService(signedIn: false),
          DemoSubscriptionService(),
        ),
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const LoginView(),
        ),
      ),
    );
    // A cena tem animação infinita: não usar pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 1500));
  }

  // Tamanhos reais de celulares (dp).
  const phones = {
    'Pequeno 360x640': Size(360, 640),
    'Comum 390x844': Size(390, 844),
    'Grande 412x915': Size(412, 915),
    'Compacto 320x568': Size(320, 568),
  };

  for (final entry in phones.entries) {
    testWidgets('sem rolagem e sem overflow — ${entry.key}', (tester) async {
      await pump(tester, entry.value);
      expect(tester.takeException(), isNull);
      // Nenhuma área rolável na tela principal.
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.text('Continuar com Google'), findsOneWidget);
      expect(find.text('Entrar com e-mail'), findsOneWidget);
      expect(find.text('Criar conta grátis'), findsOneWidget);
    });
  }

  testWidgets('fonte ampliada (130%) não quebra o layout', (tester) async {
    await pump(tester, const Size(360, 700), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aparelho deitado vira rolável em vez de estourar', (tester) async {
    await pump(tester, const Size(780, 360));
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('botões ficam dentro da tela (alcançáveis)', (tester) async {
    await pump(tester, const Size(360, 640));
    final rect = tester.getRect(find.text('Entrar com e-mail'));
    expect(rect.bottom, lessThanOrEqualTo(640));
    final consent = tester.getRect(find.text('Política de Privacidade'));
    expect(consent.bottom, lessThanOrEqualTo(640));
  });

  testWidgets('"Entrar com e-mail" abre a folha com os campos', (tester) async {
    await pump(tester, const Size(390, 844));
    await tester.tap(find.text('Entrar com e-mail'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('E-mail'), findsWidgets);
    expect(find.text('Senha'), findsWidgets);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Criar conta grátis" abre a folha já no cadastro', (tester) async {
    await pump(tester, const Size(390, 844));
    await tester.tap(find.text('Criar conta grátis'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Seu nome'), findsOneWidget);
    expect(find.text('Criar minha conta'), findsOneWidget);
  });

  testWidgets('arrastar a demonstração não gera erros', (tester) async {
    await pump(tester, const Size(390, 844));
    final hero = find.text('SUPERMERCADO');
    final gesture = await tester.startGesture(tester.getCenter(hero));
    await gesture.moveBy(const Offset(60, 20));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
  });
}
