/// Constantes de negócio e configuração do Smart Dispensa.
abstract final class AppConstants {
  static const String appName = 'Smart Dispensa';

  // ---------------------------------------------------------------------------
  // Plano Grátis
  // ---------------------------------------------------------------------------

  /// Escaneamentos de nota fiscal permitidos por mês no plano Grátis.
  static const int freeScansPerMonth = 3;

  /// Quantidade (em relação ao ideal) a partir da qual o item é
  /// considerado "acabando". Ex.: 0.25 = 25% do estoque ideal.
  static const double lowStockRatio = 0.25;

  /// Janela de histórico usada para sugestões inteligentes.
  static const int suggestionWindowDays = 90;

  /// Compras mínimas de um mesmo item para considerá-lo recorrente.
  static const int minPurchasesForSuggestion = 2;

  // ---------------------------------------------------------------------------
  // RevenueCat / Google Play Billing
  // ---------------------------------------------------------------------------

  /// Chave pública (SDK) Android do RevenueCat. Nunca commitamos a chave:
  /// ela é injetada no build com
  /// `flutter run --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx`.
  static const String revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');

  /// Identificador do Entitlement configurado no painel do RevenueCat.
  static const String premiumEntitlementId = 'premium';

  /// Período de teste grátis configurado no Google Play Console.
  static const int trialDays = 7;

  // Preços de referência (exibidos caso a loja ainda não tenha respondido).
  // Os valores reais e localizados SEMPRE vêm do Google Play quando
  // disponíveis.
  static const double monthlyPrice = 5.90;
  static const double quarterlyPrice = 14.90;
  static const double annualPrice = 49.90;
}
