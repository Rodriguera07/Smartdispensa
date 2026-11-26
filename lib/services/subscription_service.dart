import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/constants/app_constants.dart';

/// Planos oferecidos no paywall.
enum PlanType { monthly, quarterly, annual }

/// Resultado de uma tentativa de compra.
enum PurchaseOutcome { success, cancelled, failed, unavailable }

/// Integração com **RevenueCat** (plano Free, $0 até US$ 2.500/mês)
/// sobre o **Google Play Billing**.
///
/// Configuração esperada no painel do RevenueCat:
/// - Entitlement: `premium`
/// - Offering *current* com os pacotes padrão:
///   `$rc_monthly` (R$ 5,90), `$rc_three_month` (R$ 14,90) e
///   `$rc_annual` (R$ 49,90).
/// - No Google Play Console, cada plano base tem uma **oferta de teste
///   grátis de 7 dias** (P1W) — o Google aplica o trial automaticamente
///   para quem é elegível.
///
/// Se a chave do RevenueCat não for fornecida (`--dart-define`), o serviço
/// entra em modo "indisponível": o app funciona normalmente no plano Grátis.
class SubscriptionService {
  bool _configured = false;
  bool get isAvailable => _configured;

  final ValueNotifier<bool> isPremium = ValueNotifier(false);

  /// Configura o SDK e associa as compras ao usuário do Firebase
  /// (permite restaurar a assinatura em outro aparelho).
  Future<void> init(String firebaseUid) async {
    const apiKey = AppConstants.revenueCatAndroidKey;
    if (apiKey.isEmpty) {
      debugPrint('[Subscription] REVENUECAT_ANDROID_KEY ausente — modo grátis.');
      return;
    }

    try {
      if (!_configured) {
        if (kDebugMode) await Purchases.setLogLevel(LogLevel.info);
        await Purchases.configure(
          PurchasesConfiguration(apiKey)..appUserID = firebaseUid,
        );
        Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
        _configured = true;
      } else {
        await Purchases.logIn(firebaseUid);
      }
      _onCustomerInfo(await Purchases.getCustomerInfo());
    } on PlatformException catch (e) {
      debugPrint('[Subscription] Falha ao configurar: ${e.message}');
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    isPremium.value =
        info.entitlements.active.containsKey(AppConstants.premiumEntitlementId);
  }

  /// Pacotes da oferta atual mapeados para os nossos planos.
  Future<Map<PlanType, Package>> loadPackages() async {
    if (!_configured) return const {};
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return const {};
      return {
        if (current.monthly != null) PlanType.monthly: current.monthly!,
        if (current.threeMonth != null) PlanType.quarterly: current.threeMonth!,
        if (current.annual != null) PlanType.annual: current.annual!,
      };
    } on PlatformException catch (e) {
      debugPrint('[Subscription] Erro ao buscar ofertas: ${e.message}');
      return const {};
    }
  }

  /// Dias de teste grátis informados pela loja para o pacote (ou `null`).
  static int? trialDaysOf(Package package) {
    final period = package.storeProduct.defaultOption?.freePhase?.billingPeriod;
    if (period == null) return null;
    return switch (period.unit) {
      PeriodUnit.day => period.value,
      PeriodUnit.week => period.value * 7,
      PeriodUnit.month => period.value * 30,
      PeriodUnit.year => period.value * 365,
      _ => null,
    };
  }

  Future<PurchaseOutcome> purchase(Package package) async {
    if (!_configured) return PurchaseOutcome.unavailable;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _onCustomerInfo(result.customerInfo);
      return isPremium.value ? PurchaseOutcome.success : PurchaseOutcome.failed;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      debugPrint('[Subscription] Erro na compra: $code ${e.message}');
      return PurchaseOutcome.failed;
    }
  }

  /// Restaura assinaturas já feitas com a mesma conta Google.
  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      _onCustomerInfo(await Purchases.restorePurchases());
      return isPremium.value;
    } on PlatformException catch (e) {
      debugPrint('[Subscription] Erro ao restaurar: ${e.message}');
      return false;
    }
  }

  Future<void> logOut() async {
    isPremium.value = false;
    if (!_configured) return;
    try {
      if (!await Purchases.isAnonymous) await Purchases.logOut();
    } on PlatformException catch (e) {
      debugPrint('[Subscription] Erro no logout: ${e.message}');
    }
  }
}
