import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:smart_dispensa/core/theme/app_theme.dart';
import 'package:smart_dispensa/services/subscription_service.dart';
import 'package:smart_dispensa/viewmodels/subscription_viewmodel.dart';
import 'package:smart_dispensa/views/paywall/paywall_view.dart';

void main() {
  setUpAll(() async {
    // Em testes não baixamos fontes: usa a fonte padrão do Flutter.
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });

  Future<void> pump(WidgetTester tester, Size size, {double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SubscriptionViewModel(SubscriptionService()),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
            child: const PaywallView(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('paywall exibe os 3 planos e o CTA de teste grátis', (tester) async {
    await pump(tester, const Size(390, 844));
    expect(find.text('Começar 7 Dias Grátis'), findsOneWidget);
    expect(find.textContaining('Escaneamento de notas'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Mensal'), 200, scrollable: list);
    expect(find.textContaining('cancele quando quiser'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Trimestral'), 200, scrollable: list);
    expect(find.textContaining('Mais Popular'), findsOneWidget);
    expect(find.textContaining('4,96'), findsOneWidget);
    expect(find.textContaining('economize 15%'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Anual'), 200, scrollable: list);
    expect(find.textContaining('4,15'), findsOneWidget);
    expect(find.textContaining('~30%'), findsOneWidget);
    expect(find.textContaining('por trimestre'), findsOneWidget);

    // Selecionar o anual atualiza o texto de transparência.
    await tester.tap(find.text('Anual'));
    await tester.pump();
    expect(find.textContaining('por ano'), findsOneWidget);
  });

  testWidgets('paywall sem overflow em tela pequena com fonte grande', (tester) async {
    await pump(tester, const Size(320, 640), textScale: 1.4);
    expect(tester.takeException(), isNull);
  });
}
