import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../services/subscription_service.dart';

/// Estado do Premium e da tela de planos.
class SubscriptionViewModel extends ChangeNotifier {
  SubscriptionViewModel(this._service) {
    _service.isPremium.addListener(notifyListeners);
  }

  final SubscriptionService _service;

  bool get isPremium => _service.isPremium.value;
  bool get storeAvailable => _service.isAvailable;

  Map<PlanType, Package> _packages = const {};
  bool _loading = false;
  bool get loading => _loading;

  bool _purchasing = false;
  bool get purchasing => _purchasing;

  /// Trimestral pré-selecionado ("Mais Popular 🔥").
  PlanType _selected = PlanType.quarterly;
  PlanType get selected => _selected;

  void select(PlanType plan) {
    if (plan == _selected) return;
    _selected = plan;
    notifyListeners();
  }

  Future<void> loadOfferings() async {
    if (!storeAvailable || _loading || _packages.isNotEmpty) return;
    _loading = true;
    notifyListeners();
    _packages = await _service.loadPackages();
    _loading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Preços: sempre da loja quando disponíveis; senão, valores de referência.
  // ---------------------------------------------------------------------------

  static int monthsOf(PlanType p) => switch (p) {
        PlanType.monthly => 1,
        PlanType.quarterly => 3,
        PlanType.annual => 12,
      };

  double priceOf(PlanType plan) =>
      _packages[plan]?.storeProduct.price ??
      switch (plan) {
        PlanType.monthly => AppConstants.monthlyPrice,
        PlanType.quarterly => AppConstants.quarterlyPrice,
        PlanType.annual => AppConstants.annualPrice,
      };

  String priceLabel(PlanType plan) =>
      _packages[plan]?.storeProduct.priceString ?? Fmt.currency(priceOf(plan));

  /// Equivalente mensal (ex.: R$ 4,96/mês).
  String perMonthLabel(PlanType plan) =>
      Fmt.currency(_floor2(priceOf(plan) / monthsOf(plan)));

  /// Economia percentual (0–100) em relação a pagar o plano mensal.
  /// Ex.: trimestral = 15,8% → exibido como "15%"; anual = 29,5% → "~30%".
  double savingsPercent(PlanType plan) {
    final full = priceOf(PlanType.monthly) * monthsOf(plan);
    if (plan == PlanType.monthly || full <= 0) return 0;
    return (1 - priceOf(plan) / full) * 100;
  }

  int get trialDays {
    final pkg = _packages[_selected];
    if (pkg == null) return AppConstants.trialDays;
    return SubscriptionService.trialDaysOf(pkg) ?? 0;
  }

  static double _floor2(double v) => (v * 100).floorToDouble() / 100;

  // ---------------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------------

  Future<PurchaseOutcome> purchaseSelected() async {
    final pkg = _packages[_selected];
    if (pkg == null) return PurchaseOutcome.unavailable;
    _purchasing = true;
    notifyListeners();
    final outcome = await _service.purchase(pkg);
    _purchasing = false;
    notifyListeners();
    return outcome;
  }

  Future<bool> restore() async {
    _purchasing = true;
    notifyListeners();
    final ok = await _service.restore();
    _purchasing = false;
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    _service.isPremium.removeListener(notifyListeners);
    super.dispose();
  }
}
