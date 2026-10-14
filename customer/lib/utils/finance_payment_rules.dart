/// Spideli Finance payments without a server (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 2.3): which of the app's payment gateways a module's
/// `paymentMethods` offer, in which currencies, with which amounts, and the
/// messages of the refusals the app itself raises. Unit tested in
/// test/finance_payment_test.dart.
///
/// Module methods (`platform_settings/*.paymentMethods`) -> what the pay sheet offers:
/// - `wallet`       -> the Spideli Finance wallet (balance shown; refused when too low);
/// - `mobile_money` -> Orange Money, Flutterwave (its Mobile Money checkout), PayStack;
/// - `wave`         -> Flutterwave (its checkout offers Wave where Wave operates);
/// - `card`         -> Stripe (Visa / Mastercard), Flutterwave, PayStack, Mercado Pago,
///                     Xendit, Midtrans, PayFast, Razorpay;
/// - `paypal`       -> PayPal;
/// - `bank`         -> payouts only (the user's saved bank accounts).
/// A gateway is offered only when the admin enabled it for the user's region
/// (`settings/*`, per region) and its integration can charge the currency.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_rules.dart';

/// One payment gateway of the app, as Spideli Finance uses it.
class FinanceGateway {
  /// The key of `FinanceFunding.method` and `payment_receipts/{key}_{ref}`.
  final String key;

  /// The brand name (not translated).
  final String label;

  /// The module methods it serves (`card`, `paypal`, `mobile_money`, `wave`).
  final Set<String> families;

  /// What this app's integration of the gateway can charge.
  final Set<String> currencies;

  const FinanceGateway(this.key, this.label, this.families, this.currencies);
}

abstract final class FinanceGateways {
  static const String stripe = 'stripe';
  static const String paypal = 'paypal';
  static const String flutterwave = 'flutterwave';
  static const String orangeMoney = 'orange_money';
  static const String payStack = 'paystack';
  static const String mercadoPago = 'mercadopago';
  static const String xendit = 'xendit';
  static const String midTrans = 'midtrans';
  static const String payFast = 'payfast';
  static const String razorpay = 'razorpay';

  /// Module methods a gateway can serve.
  static const Set<String> gatewayMethods = {'mobile_money', 'wave', 'card', 'paypal'};

  /// Every gateway, in the order the pay sheet lists them (Mobile Money first).
  static const List<FinanceGateway> all = [
    FinanceGateway(orangeMoney, 'Orange Money', {'mobile_money'}, {'XAF'}),
    FinanceGateway(flutterwave, 'Flutterwave', {'mobile_money', 'wave', 'card'},
        {'XAF', 'XOF', 'NGN', 'GHS', 'KES', 'TZS', 'RWF', 'ZAR', 'ZMW', 'MWK', 'EGP', 'USD', 'EUR', 'GBP'}),
    FinanceGateway(stripe, 'Stripe', {'card'},
        {'XAF', 'XOF', 'GNF', 'RWF', 'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'CHF', 'NGN', 'GHS', 'KES', 'ZAR', 'MAD', 'EGP', 'AED', 'SAR', 'INR'}),
    FinanceGateway(paypal, 'PayPal', {'paypal'}, {'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'CHF'}),
    FinanceGateway(payStack, 'PayStack', {'card', 'mobile_money'}, {'NGN', 'GHS', 'ZAR', 'KES', 'USD'}),
    FinanceGateway(mercadoPago, 'Mercado Pago', {'card'}, {'ARS', 'BRL', 'COP', 'MXN', 'PEN', 'UYU'}),
    FinanceGateway(xendit, 'Xendit', {'card'}, {'IDR', 'PHP', 'THB', 'MYR'}),
    FinanceGateway(midTrans, 'Midtrans', {'card'}, {'IDR'}),
    FinanceGateway(payFast, 'PayFast', {'card'}, {'ZAR'}),
    FinanceGateway(razorpay, 'Razorpay', {'card'}, {'INR'}),
  ];

  static FinanceGateway? of(String key) => all.where((g) => g.key == key).firstOrNull;

  static String label(String key) => key == 'wallet' ? 'Spideli Finance wallet' : (of(key)?.label ?? key);

  /// The gateways the pay sheet offers for a module's [methods], among those
  /// [enabled] in the user's region, able to charge [currency].
  static List<FinanceGateway> offered(List<String> methods, Set<String> enabled, String currency) => [
        for (final g in all)
          if (enabled.contains(g.key) && g.currencies.contains(currency) && g.families.any(methods.contains)) g,
      ];

  /// Whether [methods] name any gateway family (the gateways must then be loaded).
  static bool wantsGateways(List<String> methods) => methods.any(gatewayMethods.contains);

  // Stripe's own decimals (stripe.com/docs/currencies), where they differ from 2.
  static const Set<String> _stripeZeroDecimal = {'BIF', 'CLP', 'DJF', 'GNF', 'JPY', 'KMF', 'KRW', 'MGA', 'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'};
  static const Set<String> _stripeThreeDecimal = {'BHD', 'JOD', 'KWD', 'OMR', 'TND'};

  /// [minor] (the ledger's minor units of [currency]) in the smallest unit
  /// the [gateway] API takes (Stripe, PayStack), or null when it cannot be
  /// expressed exactly. Other gateways take [major].
  static int? units(String gateway, int minor, String currency) {
    final int own = FinanceMoney.exponent(currency);
    final int theirs = switch (gateway) {
      stripe => _stripeZeroDecimal.contains(currency) ? 0 : (_stripeThreeDecimal.contains(currency) ? 3 : 2),
      payStack => 2,
      _ => own,
    };
    if (theirs >= own) return minor * _pow10(theirs - own);
    final int div = _pow10(own - theirs);
    return minor % div == 0 ? minor ~/ div : null;
  }

  /// [minor] in major units as the gateways' amount text: 1500 XAF -> "1500",
  /// 1250 USD -> "12.50".
  static String major(int minor, String currency) {
    final int e = FinanceMoney.exponent(currency);
    if (e == 0) return '$minor';
    final int unit = _pow10(e);
    return '${minor ~/ unit}.${(minor % unit).toString().padLeft(e, '0')}';
  }

  /// [major] as a number (an int for a currency without decimals).
  static num majorNum(int minor, String currency) {
    final int e = FinanceMoney.exponent(currency);
    return e == 0 ? minor : minor / _pow10(e);
  }

  /// Whether [gateway] can charge [minor] of [currency] exactly.
  static bool chargeable(String gateway, int minor, String currency) =>
      minor > 0 && (of(gateway)?.currencies.contains(currency) ?? false) && units(gateway, minor, currency) != null;

  static int _pow10(int n) => math.pow(10, n).toInt();
}

/// What the pay sheet hands to the module's `submit`:
/// - paying: the funding of the payment ([FinanceFunding]: the wallet, or a
///   gateway payment already taken, with its reference);
/// - receiving (payout): the [destination] the user chose
///   (`{method: wallet}`, `{method: mobile_money, operator, number}`,
///   `{method: wave, number}`, `{method: bank, bankName, bankCode?,
///   holderName, accountNumber, accountMasked}`); its funding is the wallet
///   (no gateway takes money for a payout).
///
/// It is also the payment map the former callables took
/// (`{method, reference}` / the destination), so a module still sending a
/// `Map<String, dynamic>` keeps compiling while it moves to the funding.
class FinancePayment extends FinanceFunding with MapMixin<String, dynamic> {
  /// The chosen destination of a payout; null when paying.
  final Map<String, dynamic>? destination;
  final Map<String, dynamic> _map;

  FinancePayment.of(FinanceFunding funding)
      : destination = null,
        _map = funding.toMap(),
        super.gateway(funding.method, funding.reference);

  FinancePayment.payout(Map<String, dynamic> destination)
      : destination = Map<String, dynamic>.unmodifiable(destination),
        _map = Map<String, dynamic>.of(destination),
        super.gateway('wallet', null);

  bool get isPayout => destination != null;

  /// The funding alone (what `FinanceLedger.plan` takes).
  FinanceFunding get funding => isWallet ? const FinanceFunding.wallet() : FinanceFunding.gateway(method, reference);

  @override
  dynamic operator [](Object? key) => _map[key];

  @override
  void operator []=(String key, dynamic value) => _map[key] = value;

  @override
  Iterable<String> get keys => _map.keys;

  @override
  dynamic remove(Object? key) => _map.remove(key);

  @override
  void clear() => _map.clear();
}

/// A payout destination as a map, and how it is shown.
abstract final class FinanceDestination {
  static Map<String, dynamic> wallet() => const {'method': 'wallet'};

  static Map<String, dynamic> mobileMoney(String operator, String number) => {'method': 'mobile_money', 'operator': operator, 'number': number};

  static Map<String, dynamic> wave(String number) => {'method': 'wave', 'number': number};

  static Map<String, dynamic> bank({required String bankName, String? bankCode, required String holderName, required String accountNumber}) => {
        'method': 'bank',
        'bankName': bankName,
        if (bankCode != null && bankCode.isNotEmpty) 'bankCode': bankCode,
        'holderName': holderName,
        'accountNumber': accountNumber,
        'accountMasked': mask(accountNumber),
      };

  /// "•••• 6789": the end of an account number.
  static String mask(String account) {
    final s = account.replaceAll(RegExp(r'\s'), '');
    return s.length <= 4 ? s : '•••• ${s.substring(s.length - 4)}';
  }

  /// "Orange Money · +237699123456", "Wave · ...", "Afriland · •••• 6789", or "" for the wallet.
  static String describe(Map<String, dynamic>? d) {
    if (d == null) return '';
    return switch (d['method']) {
      'mobile_money' => '${d['operator'] ?? 'Mobile Money'} · ${d['number'] ?? ''}',
      'wave' => 'Wave · ${d['number'] ?? ''}',
      'bank' => '${d['bankName'] ?? ''} · ${d['accountMasked'] ?? mask('${d['accountNumber'] ?? ''}')}',
      _ => '',
    };
  }
}

/// Messages of the refusals the payment, wallet, transfer and bill code
/// raises itself (a gateway fails, the connection drops, no rate...); any
/// other reason, `permission_denied` included, is [FinanceErrors]'s.
abstract final class FinancePayErrors {
  static const Map<String, String> _messages = {
    'payment_not_completed': 'The payment was not completed.',
    'gateway_unavailable': 'This payment method cannot be used right now. Choose another one.',
    'network': 'Could not reach Spideli Finance. Check your connection and try again.',
    'service_unavailable': 'This service is not available right now.',
    'rate_unavailable': 'No exchange rate is available for these currencies right now.',
    'recipient_ambiguous': 'Several accounts use this number. Enter it with the country code.',
    'not_cancellable': 'This transfer can no longer be cancelled.',
  };

  static String messageKey(String? reason) => _messages[reason] ?? FinanceErrors.messageKey(reason);
}

/// The pay sheet's reading of a module's reply (`status`, `reference`, `instructions`).
abstract final class FinancePayReply {
  /// The money arrived (a wallet or gateway payment posted).
  static bool succeeded(Map<String, dynamic> reply) => const ['succeeded', 'completed', 'paid'].contains(reply['status']);

  /// Paid; the request now waits for Spideli to complete it (a payout, a biller).
  static bool processing(Map<String, dynamic> reply) => const ['processing', 'pending_admin', 'requested', 'submitted'].contains(reply['status']);
}
