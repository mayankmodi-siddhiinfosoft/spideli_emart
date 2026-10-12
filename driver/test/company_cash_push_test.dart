import 'dart:io';

import 'package:driver/services/company_cash_push.dart';
import 'package:driver/services/push_template_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushTemplateText.fill', () {
    test('fills known placeholders, case-insensitively', () {
      expect(
        PushTemplateText.fill('{driverName} collected {amount} for #{orderid}', {'driverName': 'Ali', 'amount': 'XAF 5000', 'orderId': 'o1'}),
        'Ali collected XAF 5000 for #o1',
      );
      expect(PushTemplateText.fill('{DRIVERNAME} / {drivername}', {'driverName': 'Ali'}), 'Ali / Ali');
    });

    test('keeps unknown placeholders and other braces as written', () {
      expect(PushTemplateText.fill('Hi {who}, {amount}', {'amount': '5'}), 'Hi {who}, 5');
      expect(PushTemplateText.fill('{ amount } {1x} {}', {'amount': '5'}), '{ amount } {1x} {}');
    });

    test('null / empty text, and no values', () {
      expect(PushTemplateText.fill(null, {'amount': '5'}), '');
      expect(PushTemplateText.fill('', {'amount': '5'}), '');
      expect(PushTemplateText.fill('{amount}', const {}), '{amount}');
    });

    test('a value containing braces or dollar signs is inserted literally', () {
      expect(PushTemplateText.fill('{reason}', {'reason': r'short by $5 {amount}'}), r'short by $5 {amount}');
    });
  });

  group('CompanyCashPush', () {
    test('the five template types', () {
      expect(CompanyCashPush.templates, [
        'company_cash_collected',
        'company_cash_settlement_submitted',
        'company_cash_settlement_confirmed',
        'company_cash_settlement_rejected',
        'company_cash_adjustment',
      ]);
    });

    test('values: trimmed, blanks left out, signed amount only for adjustments', () {
      final v = CompanyCashPush.values(amount: '₹ 50', driverName: ' Ali ', companyName: '', orderId: 'o1', reference: 'tx1', reason: '  ');
      expect(v, {'amount': '₹ 50', 'driverName': 'Ali', 'orderId': 'o1', 'reference': 'tx1'});
      expect(CompanyCashPush.values(amount: '5', isCredit: true)['signedAmount'], '+5');
      expect(CompanyCashPush.values(amount: '5', isCredit: false)['signedAmount'], '-5');
    });

    test('company name falls back to the owner name', () {
      expect(CompanyCashPush.companyNameOf(companyName: ' Afrilight ', ownerName: 'Bob'), 'Afrilight');
      expect(CompanyCashPush.companyNameOf(companyName: '', ownerName: 'Bob'), 'Bob');
      expect(CompanyCashPush.companyNameOf(), '');
    });

    test('a template filled with the values', () {
      const String template = 'Your settlement of {amount} was rejected by {companyName}: {reason} (ref {reference})';
      final v = CompanyCashPush.values(amount: '1,000 F', companyName: 'Afrilight', reason: 'short', reference: 'tx9');
      expect(PushTemplateText.fill(template, v), 'Your settlement of 1,000 F was rejected by Afrilight: short (ref tx9)');
    });
  });

  test('the company cash service has no fixed push text any more', () {
    final String src = File('lib/services/company_cash_service.dart').readAsStringSync();
    expect(src.contains('sendOneNotification'), isFalse);
    for (final String t in CompanyCashPush.templates) {
      final String constant = {
        'company_cash_collected': 'CompanyCashPush.collected',
        'company_cash_settlement_submitted': 'CompanyCashPush.settlementSubmitted',
        'company_cash_settlement_confirmed': 'CompanyCashPush.settlementConfirmed',
        'company_cash_settlement_rejected': 'CompanyCashPush.settlementRejected',
        'company_cash_adjustment': 'CompanyCashPush.adjustment',
      }[t]!;
      expect(src.contains(constant), isTrue, reason: t);
    }
  });
}
