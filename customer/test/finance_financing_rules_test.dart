import 'package:customer/utils/finance_financing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = {
    'currencies': ['XAF'],
    'financingTypes': ['loan', 'grant', 'magic'],
    'documentTypes': ['business_plan', 'financial_statements', 'registration', 'quotes'],
    'requiredDocuments': [
      'business_plan',
      'unknown',
      {'type': 'financial_statements', 'financingTypes': ['loan']},
      {'type': 'registration'},
    ],
    'minAmount': {'XAF': 500000},
    'maxAmount': {'XAF': 100000000},
    'durationsMonths': [36, 12],
  };

  test('configuration: parsed, unknown values dropped, fails closed', () {
    final c = FinancingConfig.parse(raw)!;
    expect(c.financingTypes, ['loan', 'grant']);
    expect(c.durationsMonths, [12, 36]);
    expect(c.allowedContentTypes, contains('application/pdf'));
    expect(c.maxFileBytes, 20 * 1024 * 1024);
    expect(FinancingConfig.parse(null), isNull);
    expect(FinancingConfig.parse({...raw, 'financingTypes': ['magic']}), isNull);
    expect(FinancingConfig.parse({...raw, 'documentTypes': []}), isNull);
  });

  test('required documents depend on the financing type', () {
    final c = FinancingConfig.parse(raw)!;
    expect(c.requiredFor('loan'), ['business_plan', 'financial_statements', 'registration']);
    expect(c.requiredFor('grant'), ['business_plan', 'registration']);
    expect(c.hasDuration('loan'), isTrue);
    expect(c.hasDuration('grant'), isFalse);
  });

  test('missing documents ignore rejected uploads', () {
    final required = ['business_plan', 'registration'];
    expect(missingDocuments(required, [
      {'type': 'business_plan', 'status': 'received'},
      {'type': 'registration', 'status': 'rejected'},
    ]), ['registration']);
    expect(missingDocuments(required, [
      {'type': 'business_plan'},
      {'type': 'registration', 'status': 'accepted'},
    ]), isEmpty);
  });

  test('amount and file checks', () {
    final c = FinancingConfig.parse(raw)!;
    expect(c.amountProblem(1000000, 'XAF'), isNull);
    expect(c.amountProblem(100, 'XAF'), contains('minimum'));
    expect(c.amountProblem(200000000, 'XAF'), contains('maximum'));
    expect(c.amountProblem(null, 'XAF'), isNotNull);
    expect(c.fileProblem('application/pdf', 1000), isNull);
    expect(c.fileProblem('application/zip', 1000), contains('type'));
    expect(c.fileProblem('application/pdf', 30 * 1024 * 1024), contains('large'));
    expect(c.fileProblem('application/pdf', 0), contains('empty'));
    expect(contentTypeOf('Plan.PDF'), 'application/pdf');
    expect(extensionsFor(['application/pdf', 'image/jpeg']), ['pdf', 'jpg', 'jpeg']);
  });

  test('statuses', () {
    expect(FinancingStatus.editable('additional_info_required'), isTrue);
    expect(FinancingStatus.editable('under_review'), isFalse);
    expect(FinancingStatus.canSubmit('draft', const []), isTrue);
    expect(FinancingStatus.canSubmit('draft', const ['business_plan']), isFalse);
    expect(FinancingStatus.canWithdraw('approved'), isFalse);
  });
}
