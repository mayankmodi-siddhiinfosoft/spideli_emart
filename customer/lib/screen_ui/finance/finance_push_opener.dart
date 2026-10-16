import 'package:customer/screen_ui/finance/bill_screens.dart';
import 'package:customer/screen_ui/finance/financing_screens.dart';
import 'package:customer/screen_ui/finance/insurance_screens.dart';
import 'package:customer/screen_ui/finance/intelligence_screens.dart';
import 'package:customer/screen_ui/finance/investment_screens.dart';
import 'package:customer/screen_ui/finance/kyc_screen.dart';
import 'package:customer/screen_ui/finance/lending_screens.dart';
import 'package:customer/screen_ui/finance/savings_screens.dart';
import 'package:customer/screen_ui/finance/tontine_screens.dart';
import 'package:customer/screen_ui/finance/transactions_screen.dart';
import 'package:customer/screen_ui/finance/transfer_screens.dart';
import 'package:customer/screen_ui/finance/wallet_screens.dart';
import 'package:customer/screen_ui/help_support_screen/help_support_screen.dart';
import 'package:customer/service/finance_financing_service.dart';
import 'package:customer/service/finance_insurance_service.dart';
import 'package:customer/service/finance_investment_service.dart';
import 'package:customer/service/finance_transfer_service.dart';
import 'package:customer/utils/finance_push_tap.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Opens the Finance screen of a tapped push or Notification Center row
/// ([FinancePushTap]), on top of whatever is open. A screen that needs its
/// service's settings opens its list when they cannot be read.
abstract final class FinancePushOpener {
  static Future<void> open(({FinanceTapKind kind, String id}) target) async {
    final String id = target.id;
    final Widget page = switch (target.kind) {
      FinanceTapKind.kyc => const KycScreen(),
      FinanceTapKind.walletOperation => WalletOperationScreen(operationId: id),
      FinanceTapKind.wallet => const TransactionsScreen(),
      FinanceTapKind.transfer => await _with(FinanceTransferService.config, (c) => TransferScreen(transferId: id, config: c), const TransfersScreen()),
      FinanceTapKind.transfers => const TransfersScreen(),
      FinanceTapKind.bill => await _with(FinanceTransferService.billsConfig, (c) => BillPaymentScreen(requestId: id, config: c), const BillsScreen()),
      FinanceTapKind.bills => const BillsScreen(),
      FinanceTapKind.goal => SavingsGoalScreen(goalId: id),
      FinanceTapKind.goals => const SavingsListScreen(),
      FinanceTapKind.tontine => TontineScreen(tontineId: id),
      FinanceTapKind.tontines => const TontineListScreen(),
      FinanceTapKind.loan => LoanScreen(loanId: id),
      FinanceTapKind.loans => const LoansScreen(),
      FinanceTapKind.fund => await _with(FinanceInvestmentService.config, (c) => FundScreen(fundId: id, config: c), const InvestmentsScreen()),
      FinanceTapKind.investments => const InvestmentsScreen(),
      FinanceTapKind.quote => await _with(FinanceInsuranceService.config, (c) => QuoteScreen(quoteId: id, config: c), const InsuranceScreen()),
      FinanceTapKind.policy => await _with(FinanceInsuranceService.config, (c) => PolicyScreen(policyId: id, config: c), const InsuranceScreen()),
      FinanceTapKind.claim => await _with(FinanceInsuranceService.config, (c) => ClaimScreen(claimId: id, config: c), const InsuranceScreen()),
      FinanceTapKind.insurance => const InsuranceScreen(),
      FinanceTapKind.financing => await _with(FinanceFinancingService.config, (c) => ApplicationScreen(applicationId: id, config: c), const FinancingScreen()),
      FinanceTapKind.financingList => const FinancingScreen(),
      FinanceTapKind.opportunity => OpportunityScreen(opportunityId: id),
      FinanceTapKind.support => HelpSupportScreen(),
    };
    await Get.to(() => page);
  }

  /// [build] with the settings [load] reads, else [fallback].
  static Future<Widget> _with<T>(Future<T?> Function() load, Widget Function(T config) build, Widget fallback) async {
    try {
      final T? config = await load();
      return config == null ? fallback : build(config);
    } catch (_) {
      return fallback;
    }
  }
}
