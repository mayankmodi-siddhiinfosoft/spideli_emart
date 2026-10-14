import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:customer/utils/finance_financing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Project financing written directly by the owner
/// (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.11): pure plans of writes.
void main() {
  group('projects', () {
    final fields = {
      'name': 'Agro CM',
      'sector': 'agriculture',
      'stage': 'growth',
      'country': 'Cameroon',
      'city': 'Douala',
      'description': 'Cassava processing for the local market and export.',
      'employees': 12,
      'website': '',
    };

    test('a new project belongs to its owner; empty optional fields are not stored', () {
      final w = FinancingPlans.saveProject(projectId: 'p1', uid: 'u1', isNew: true, fields: fields).single;
      expect(w.path, 'financing_projects/p1');
      expect(w.op, 'create');
      expect(w.data['ownerId'], 'u1');
      expect(w.data['id'], 'p1');
      expect(w.data['employees'], 12);
      expect(w.data.containsKey('website'), isFalse);
      expect(w.data.containsKey('foundedYear'), isFalse);
      expect(w.data['createdAt'], isA<FieldValue>());
    });

    test('an edit changes the fields only (never the owner) and removes the emptied ones', () {
      final w = FinancingPlans.saveProject(projectId: 'p1', uid: 'u1', isNew: false, fields: fields).single;
      expect(w.op, 'update');
      expect(w.data.containsKey('ownerId'), isFalse);
      expect(w.data.containsKey('createdAt'), isFalse);
      expect(w.data['website'], isA<FieldValue>());
      expect(w.data['name'], 'Agro CM');
    });
  });

  group('applications', () {
    final fields = {'projectId': 'p1', 'financingType': 'loan', 'amount': 5000000, 'currency': 'XAF', 'durationMonths': 24, 'useOfFunds': 'A second press line and working capital.'};

    test('a draft for the owner\'s project, with no reviewer yet', () {
      final w = FinancingPlans.createApplication(applicationId: 'a1', uid: 'u1', projectId: 'p1', projectName: 'Agro CM', fields: fields).single;
      expect(w.path, 'financing_applications/a1');
      expect(w.op, 'create');
      expect(w.data['status'], 'draft');
      expect(w.data['ownerId'], 'u1');
      expect(w.data['projectName'], 'Agro CM');
      expect(w.data['reviewerIds'], isEmpty);
      expect(w.data['durationMonths'], 24);
    });

    test('an edit: the financing fields only; a duration that no longer applies is removed', () {
      final w = FinancingPlans.updateApplication('a1', {...fields, 'financingType': 'grant', 'durationMonths': null}).single;
      expect(w.op, 'update');
      expect(w.data.keys.toSet(), {'financingType', 'amount', 'currency', 'durationMonths', 'useOfFunds', 'updatedAt'});
      expect(w.data['durationMonths'], isA<FieldValue>());
    });

    test('submit with the declaration; the reviewers\' request is answered', () {
      final w = FinancingPlans.submit('a1', message: 'Statements added.').single;
      expect(w.data['status'], 'submitted');
      expect(w.data['declarationAccepted'], isTrue);
      expect(w.data['declarationAcceptedAt'], isA<FieldValue>());
      expect(w.data['submittedAt'], isA<FieldValue>());
      expect(w.data['ownerMessage'], 'Statements added.');
      expect(w.data.containsKey('reason'), isTrue);
      expect(w.data['reason'], isNull);
    });

    test('withdraw', () {
      final w = FinancingPlans.withdraw('a1').single;
      expect(w.data['status'], 'withdrawn');
    });

    test('checks: editable, every required document, withdrawal before approval', () {
      expect(FinancingChecks.edit('draft'), isNull);
      expect(FinancingChecks.edit('additional_info_required'), isNull);
      expect(FinancingChecks.edit('submitted'), 'financing_not_editable');
      expect(FinancingChecks.submit('draft', const []), isNull);
      expect(FinancingChecks.submit('draft', const ['business_plan']), 'financing_documents_missing');
      expect(FinancingChecks.submit('under_review', const []), 'financing_not_editable');
      expect(FinancingChecks.withdraw('under_review'), isNull);
      expect(FinancingChecks.withdraw('approved'), 'financing_not_editable');
    });
  });

  group('documents', () {
    test('recorded after the upload, received until the reviewers decide', () {
      final w = FinancingPlans.addDocument(
        documentId: 'd1',
        uid: 'u1',
        applicationId: 'a1',
        type: 'business_plan',
        name: 'plan.pdf',
        storagePath: 'financing_documents/u1/a1/1-plan.pdf',
        contentType: 'application/pdf',
        size: 1024,
      ).single;
      expect(w.path, 'financing_documents/d1');
      expect(w.op, 'create');
      expect(w.data['status'], 'received');
      expect(w.data['ownerId'], 'u1');
      expect(w.data['storagePath'], startsWith('financing_documents/u1/a1/'));
    });

    test('removed with a delete', () {
      final w = FinancingPlans.removeDocument('d1').single;
      expect(w.path, 'financing_documents/d1');
      expect(w.op, 'delete');
    });
  });
}
