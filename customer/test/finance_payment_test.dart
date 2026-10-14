import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_payment_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pay sheet's rules (.claude/FINANCE-DIRECT-FIRESTORE.md section 2.3):
/// which gateways a module's methods offer, amounts in each gateway's unit,
/// and the payment handed to the module.
void main() {
  group('gateways offered', () {
    const all = {'stripe', 'paypal', 'flutterwave', 'orange_money', 'paystack', 'mercadopago', 'xendit', 'midtrans', 'payfast', 'razorpay'};
    List<String> keys(List<FinanceGateway> l) => l.map((g) => g.key).toList();

    test('mobile money in XAF: Orange Money then Flutterwave; never a gateway the region did not enable', () {
      expect(keys(FinanceGateways.offered(['wallet', 'mobile_money'], all, 'XAF')), ['orange_money', 'flutterwave']);
      expect(keys(FinanceGateways.offered(['mobile_money'], {'flutterwave'}, 'XAF')), ['flutterwave']);
      expect(FinanceGateways.offered(['mobile_money'], const {}, 'XAF'), isEmpty);
    });

    test('card -> Stripe (and the card checkouts that charge the currency); paypal -> PayPal', () {
      expect(keys(FinanceGateways.offered(['card'], all, 'XAF')), ['flutterwave', 'stripe']);
      expect(keys(FinanceGateways.offered(['paypal'], all, 'USD')), ['paypal']);
      expect(FinanceGateways.offered(['paypal'], all, 'XAF'), isEmpty, reason: 'PayPal cannot charge XAF');
      expect(keys(FinanceGateways.offered(['card'], all, 'INR')), ['stripe', 'razorpay']);
    });

    test('wave -> Flutterwave; the wallet alone needs no gateway', () {
      expect(keys(FinanceGateways.offered(['wave'], all, 'XOF')), ['flutterwave']);
      expect(FinanceGateways.wantsGateways(['wallet']), isFalse);
      expect(FinanceGateways.wantsGateways(['wallet', 'wave']), isTrue);
    });
  });

  group('amounts', () {
    test('Stripe: XAF has no decimals there either; USD in cents', () {
      expect(FinanceGateways.units('stripe', 10150, 'XAF'), 10150);
      expect(FinanceGateways.units('stripe', 1250, 'USD'), 1250);
      expect(FinanceGateways.units('paystack', 1250, 'NGN'), 1250);
    });

    test('major units as the gateways take them', () {
      expect(FinanceGateways.major(10150, 'XAF'), '10150');
      expect(FinanceGateways.major(1205, 'USD'), '12.05');
      expect(FinanceGateways.majorNum(1250, 'USD'), 12.5);
      expect(FinanceGateways.majorNum(500, 'XAF'), 500);
    });

    test('chargeable only in a currency the integration supports', () {
      expect(FinanceGateways.chargeable('orange_money', 5000, 'XAF'), isTrue);
      expect(FinanceGateways.chargeable('orange_money', 5000, 'XOF'), isFalse);
      expect(FinanceGateways.chargeable('stripe', 0, 'XAF'), isFalse);
      expect(FinanceGateways.chargeable('nope', 100, 'XAF'), isFalse);
    });
  });

  group('the payment handed to submit', () {
    test('wallet: a funding and the map the callables took', () {
      final p = FinancePayment.of(const FinanceFunding.wallet());
      expect(p.isWallet, isTrue);
      expect(p.isPayout, isFalse);
      expect(p['method'], 'wallet');
      expect(p.funding.isWallet, isTrue);
      expect(p.receiptId, isNull);
    });

    test('gateway: method and reference, one receipt per payment', () {
      final p = FinancePayment.of(const FinanceFunding.gateway('stripe', 'pi_123'));
      expect(p.isWallet, isFalse);
      expect(p['method'], 'stripe');
      expect(p['reference'], 'pi_123');
      expect(p.funding.receiptId, 'stripe_pi_123');
      // A function written for the funding takes it.
      String describe(FinanceFunding f) => f.toString();
      expect(describe(p), isNotEmpty);
    });

    test('payout: the destination, never a gateway funding', () {
      final p = FinancePayment.payout(FinanceDestination.bank(bankName: 'Afriland', bankCode: '10005', holderName: 'Jean Dupont', accountNumber: '10005000011234567890'));
      expect(p.isPayout, isTrue);
      expect(p.isWallet, isTrue, reason: 'no gateway takes money for a payout');
      expect(p['method'], 'bank');
      expect(p.destination!['accountMasked'], '•••• 7890');
      expect(() => p.destination!['x'] = 1, throwsUnsupportedError);
    });

    test('destinations as shown', () {
      expect(FinanceDestination.describe(FinanceDestination.mobileMoney('Orange Money', '+237699123456')), 'Orange Money · +237699123456');
      expect(FinanceDestination.describe(FinanceDestination.wave('+221771234567')), 'Wave · +221771234567');
      expect(FinanceDestination.describe(FinanceDestination.wallet()), '');
      expect(FinanceDestination.mask('1234'), '1234');
    });
  });

  test('messages: the app\'s own reasons, else the shared ones', () {
    expect(FinancePayErrors.messageKey('payment_not_completed'), 'The payment was not completed.');
    expect(FinancePayErrors.messageKey('insufficient_funds'), 'Insufficient balance.');
    expect(FinancePayErrors.messageKey('permission_denied'), contains('not allowed'));
    expect(FinancePayErrors.messageKey(null), contains('Something went wrong'));
  });

  test('replies: received, processing, or started', () {
    expect(FinancePayReply.succeeded({'status': 'succeeded'}), isTrue);
    expect(FinancePayReply.succeeded({'status': 'processing'}), isFalse);
    expect(FinancePayReply.processing({'status': 'processing'}), isTrue);
    expect(FinancePayReply.processing({'status': 'pending'}), isFalse);
  });
}
