import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_transfer_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transfers and bills written by the app (.claude/FINANCE-DIRECT-FIRESTORE.md
/// sections 3.3 / 3.4): the recipient lookup and each batch.
void main() {
  Map<String, dynamic> doc(List<FinanceWrite> w, String prefix) => w.firstWhere((x) => x.path.startsWith(prefix)).data;
  List<Map<String, dynamic>> lines(List<FinanceWrite> w) => List<Map<String, dynamic>>.from(doc(w, 'ledger_transactions/')['lines'] as List);

  group('recipient lookup', () {
    final users = <(String, Map<String, dynamic>)>[
      ('a', {'countryCode': '+237', 'phoneNumber': '699123456', 'firstName': 'Awa', 'lastName': 'Ndiaye', 'role': 'customer', 'fcmToken': 'tok-a'}),
      ('b', {'countryCode': '+221', 'phoneNumber': '699123456', 'firstName': 'Binta', 'lastName': 'Fall', 'role': 'customer'}),
      ('c', {'countryCode': '+237', 'phoneNumber': '677000000', 'firstName': 'Cheikh', 'active': false}),
    ];

    test('the numbers a typed phone may be stored as', () {
      final c = RecipientMatch.phoneCandidates('+237 699 12 34 56');
      expect(c, containsAll(['237699123456', '+237699123456', '699123456']));
      expect(c.length, lessThanOrEqualTo(10));
      expect(RecipientMatch.phoneCandidates('--'), isEmpty);
    });

    test('with a country code, the whole number must match', () {
      final m = RecipientMatch.phoneMatches(users, '+237699123456');
      expect(m.map((u) => u.$1), ['a']);
      expect(RecipientMatch.phoneMatches(users, '00221699123456').map((u) => u.$1), ['b']);
    });

    test('without one, the sender\'s country breaks a tie', () {
      expect(RecipientMatch.phoneMatches(users, '699123456', countryCode: '+221').map((u) => u.$1), ['b']);
      expect(RecipientMatch.phoneMatches(users, '0699123456', countryCode: '+33').length, 2, reason: 'still ambiguous');
    });

    test('pick: one active customer, never the sender', () {
      final ok = RecipientMatch.pick([users[0]], 'me');
      expect(ok.reason, isNull);
      expect(ok.recipient!.name, 'Awa Ndiaye');
      expect(ok.recipient!.fcmToken, 'tok-a');
      expect(RecipientMatch.pick([], 'me').reason, 'recipient_not_found');
      expect(RecipientMatch.pick([users[2]], 'me').reason, 'recipient_not_found', reason: 'inactive');
      expect(RecipientMatch.pick([('x', {'role': 'driver'})], 'me').reason, 'recipient_not_found');
      expect(RecipientMatch.pick([users[0]], 'a').reason, 'self_transfer');
      expect(RecipientMatch.pick([users[0], users[1]], 'me').reason, 'recipient_ambiguous');
      expect(RecipientMatch.pick([users[0], users[0]], 'me').reason, isNull, reason: 'found twice (email and lowercase)');
    });
  });

  group('transfers', () {
    const internal = TransferDraft(
      channel: 'internal',
      currency: 'XAF',
      amount: 10000,
      fee: 150,
      recipient: {'email': 'awa@example.com'},
      recipientName: 'Awa Ndiaye',
      recipientId: 'a',
      note: 'Rent',
    );

    test('internal: completed, sender wallet -> recipient wallet + fee line, recipient wallet created', () {
      final w = TransferPlans.internal(
        id: 'k1',
        d: internal,
        senderId: 'me',
        senderName: 'Moi',
        funding: const FinanceFunding.wallet(),
        senderWalletId: 'wallet_me_XAF',
        recipientWallet: (id: 'wallet_a_XAF', exists: false),
        txId: 'tx_1_k',
      );
      final t = doc(w, 'money_transfers/');
      expect(w.first.path, 'money_transfers/k1');
      expect(t['status'], 'completed');
      expect(t['participantIds'], ['me', 'a']);
      expect(t['recipientVerified'], isTrue);
      expect(t['total'], 10150);
      expect(t['receiveAmount'], 10000);
      expect(t['txId'], 'tx_1_k');
      expect(t['funding'], {'method': 'wallet'});
      expect(lines(w), [
        {'accountId': 'wallet_me_XAF', 'direction': 'debit', 'amount': 10150},
        {'accountId': 'wallet_a_XAF', 'direction': 'credit', 'amount': 10000},
        {'accountId': 'platform_XAF', 'direction': 'credit', 'amount': 150},
      ]);
      expect(doc(w, 'ledger_transactions/')['userIds'], ['me', 'a']);
      expect(w.singleWhere((x) => x.path == 'financial_accounts/wallet_a_XAF').op, 'create');
      expect(w.singleWhere((x) => x.path == 'financial_accounts/wallet_a_XAF').data['userId'], 'a');
    });

    test('internal paid by a gateway: recorded on the transfer, posted from the wallet it was deposited to', () {
      final w = TransferPlans.internal(
        id: 'k1',
        d: internal,
        senderId: 'me',
        senderName: 'Moi',
        funding: const FinanceFunding.gateway('stripe', 'pi_9'),
        senderWalletId: 'wallet_me_XAF',
        recipientWallet: (id: 'wallet_a_XAF', exists: true),
        txId: 'tx_1_k',
      );
      expect(doc(w, 'money_transfers/')['funding'], {'method': 'stripe', 'reference': 'pi_9'});
      expect(doc(w, 'ledger_transactions/')['funding'], 'wallet');
      expect(w.where((x) => x.path.startsWith('payment_receipts/')), isEmpty, reason: 'the receipt belongs to the deposit');
      expect(w.singleWhere((x) => x.path == 'financial_accounts/wallet_a_XAF').op, 'update');
    });

    const mobile = TransferDraft(
      channel: 'mobile_money',
      currency: 'XAF',
      amount: 20000,
      fee: 300,
      recipient: {'operator': 'Orange Money', 'number': '+237699123456'},
      recipientName: 'Binta',
    );

    test('external: processing, the total from the wallet to the platform, no recipient account', () {
      final w = TransferPlans.external(
        id: 'k2',
        d: mobile,
        senderId: 'me',
        senderName: 'Moi',
        funding: const FinanceFunding.wallet(),
        senderWalletId: 'wallet_me_XAF',
        txId: 'tx_2_k',
      );
      final t = doc(w, 'money_transfers/');
      expect(t['status'], 'processing');
      expect(t['participantIds'], ['me']);
      expect(t.containsKey('recipientId'), isFalse);
      expect(t['recipientVerified'], isFalse);
      expect(doc(w, 'ledger_transactions/')['type'], 'transfer_out');
      expect(lines(w), [
        {'accountId': 'wallet_me_XAF', 'direction': 'debit', 'amount': 20300},
        {'accountId': 'platform_XAF', 'direction': 'credit', 'amount': 20300},
      ]);
    });

    test('cancel: an external transfer still processing that the admin has not taken', () {
      final t = {'senderId': 'me', 'channel': 'mobile_money', 'status': 'processing'};
      expect(TransferPlans.canRequestCancel(t, 'me'), isTrue);
      expect(TransferPlans.canRequestCancel({...t, 'adminLockedAt': 1}, 'me'), isFalse);
      expect(TransferPlans.canRequestCancel({...t, 'cancelRequested': true}, 'me'), isFalse);
      expect(TransferPlans.canRequestCancel({...t, 'status': 'completed'}, 'me'), isFalse);
      expect(TransferPlans.canRequestCancel({...t, 'channel': 'internal'}, 'me'), isFalse);
      expect(TransferPlans.canRequestCancel(t, 'other'), isFalse);
      expect(TransferPlans.cancelRequest()['cancelRequested'], isTrue);
    });

    test('beneficiaries: one per user, channel and recipient', () {
      expect(TransferPlans.beneficiaryId('me', 'mobile_money', mobile.recipientKey), TransferPlans.beneficiaryId('me', 'mobile_money', 'Orange Money:+237699123456'));
      expect(TransferPlans.beneficiaryId('me', 'internal', 'a/b'), isNot(contains('/')));
      final b = TransferPlans.beneficiary('me', mobile);
      expect(b['userId'], 'me');
      expect(b['displayName'], 'Binta');
      expect(b['recipient'], mobile.recipient);
    });
  });

  group('bills', () {
    final due = Biller.fromMap({'id': 'eneo', 'name': 'ENEO', 'category': 'electricity', 'currency': 'XAF', 'amountType': 'due', 'min': 500, 'max': 200000, 'feeFixed': {'XAF': 100}})!;

    test('without the lookup, a due bill takes the amount typed from the bill, within its bounds', () {
      expect(BillPlans.amountProblem(due, 15000), isNull);
      expect(BillPlans.amountProblem(due, 100), contains('minimum'));
      expect(BillPlans.amountProblem(due, 300000), contains('maximum'));
      expect(BillPlans.amountProblem(due, null), isNotNull);
    });

    test('payment: processing, the total from the wallet to the platform', () {
      final d = BillDraft(biller: due, account: '12345678901', amount: 15000, saveAccount: true);
      expect(d.fee, 100);
      final w = BillPlans.payment(id: 'k3', uid: 'me', d: d, funding: const FinanceFunding.wallet(), walletId: 'wallet_me_XAF', txId: 'tx_3_k');
      final r = doc(w, 'utility_payment_requests/');
      expect(w.first.path, 'utility_payment_requests/k3');
      expect(r['status'], 'processing');
      expect(r['total'], 15100);
      expect(r['billerName'], 'ENEO');
      expect(r['txId'], 'tx_3_k');
      expect(doc(w, 'ledger_transactions/')['type'], 'bill_payment');
      expect(lines(w)[0], {'accountId': 'wallet_me_XAF', 'direction': 'debit', 'amount': 15100});
      expect(BillPlans.savedAccountId('me', 'eneo', ' 12345678901 '), 'acc_me_eneo_12345678901');
    });

    test('categories of the client spec have names', () {
      expect(BillLabels.category('taxes'), 'Taxes');
      expect(BillLabels.category('products'), 'Products');
    });
  });

  test('the steps a transfer or bill goes through', () {
    expect(DirectFlow.steps, ['paid', 'processing', 'completed']);
    expect(DirectFlow.label('processing'), 'Processing');
  });
}
