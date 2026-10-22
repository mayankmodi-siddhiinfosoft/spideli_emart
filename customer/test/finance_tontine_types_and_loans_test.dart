import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_lending_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tontine Types & Sponsorship', () {
    test('professional tontine: HR admin in adminIds but not memberIds, no initial payout position', () {
      final writes = TontineWrites.create(
        tontineId: 'ton_prof',
        uid: 'hr_uid',
        displayName: 'HR Admin',
        email: 'hr@company.com',
        name: 'Corporate Tontine',
        description: 'Company sponsored tontine',
        rules: 'Company pays unpaid debts',
        contributionAmount: 50000,
        currency: 'XAF',
        frequency: 'monthly',
        membersLimit: 10,
        payoutOrderMethod: 'fixed',
        startDate: DateTime(2026, 11, 1),
        type: 'professional',
        sponsorId: 'company_uid',
      );

      final tontineWrite = writes.firstWhere((w) => w.path == 'tontines/ton_prof');
      expect(tontineWrite.data['type'], 'professional');
      expect(tontineWrite.data['sponsorId'], 'company_uid');
      expect(tontineWrite.data['adminIds'], ['hr_uid']);
      // For professional tontine, HR admin does NOT contribute and is not in memberIds
      expect(tontineWrite.data['memberIds'], isEmpty);

      final hrMemberWrite = writes.firstWhere((w) => w.path == 'tontine_members/ton_prof_hr_uid');
      expect(hrMemberWrite.data['role'], 'admin');
      expect(hrMemberWrite.data['status'], 'active');
      expect(hrMemberWrite.data['payoutPosition'], isNull);
    });

    test('group tontine defaults to type group and includes creator in memberIds', () {
      final writes = TontineWrites.create(
        tontineId: 'ton_grp',
        uid: 'user_1',
        displayName: 'User One',
        email: 'user1@test.com',
        name: 'Friends Group',
        description: 'Informal savings',
        rules: 'Standard rules',
        contributionAmount: 20000,
        currency: 'XAF',
        frequency: 'monthly',
        membersLimit: 5,
        payoutOrderMethod: 'random',
        startDate: DateTime(2026, 11, 1),
      );

      final tontineWrite = writes.firstWhere((w) => w.path == 'tontines/ton_grp');
      expect(tontineWrite.data['type'], 'group');
      expect(tontineWrite.data['memberIds'], ['user_1']);
      expect(tontineWrite.data['adminIds'], ['user_1']);
    });

    test('association tontine: executive contributes and can remove a member', () {
      final writes = TontineWrites.create(
        tontineId: 'ton_assoc',
        uid: 'exec_uid',
        displayName: 'Assoc Exec',
        email: 'exec@assoc.org',
        name: 'Community Assoc',
        description: 'Association savings',
        rules: 'Association rules',
        contributionAmount: 10000,
        currency: 'XAF',
        frequency: 'monthly',
        membersLimit: 12,
        payoutOrderMethod: 'fixed',
        startDate: DateTime(2026, 11, 1),
        type: 'association',
        sponsorId: 'assoc_sponsor_uid',
      );

      final tontineWrite = writes.firstWhere((w) => w.path == 'tontines/ton_assoc');
      expect(tontineWrite.data['type'], 'association');
      expect(tontineWrite.data['memberIds'], ['exec_uid']);

      // Remove member writes
      final removeWrites = TontineWrites.removeMember('ton_assoc', 'member_to_remove');
      expect(removeWrites, hasLength(2));
      final memberWrite = removeWrites.firstWhere((w) => w.path == 'tontine_members/ton_assoc_member_to_remove');
      expect(memberWrite.data['status'], 'removed');
      final tontineUpdate = removeWrites.firstWhere((w) => w.path == 'tontines/ton_assoc');
      expect(tontineUpdate.op, 'update');
    });

    test('member salary declaration and confirmation writes', () {
      final declareWrites = SalaryWrites.declare(
        tontineId: 'ton_prof',
        uid: 'emp_uid',
        monthlySalary: 300000,
        currency: 'XAF',
      );
      expect(declareWrites, hasLength(1));
      expect(declareWrites.first.path, 'member_salaries/ton_prof_emp_uid');
      expect(declareWrites.first.data['monthlySalary'], 300000);
      expect(declareWrites.first.data['confirmedBy'], isNull);

      final confirmWrites = SalaryWrites.confirm(
        tontineId: 'ton_prof',
        uid: 'emp_uid',
        adminUid: 'hr_uid',
      );
      expect(confirmWrites, hasLength(1));
      expect(confirmWrites.first.path, 'member_salaries/ton_prof_emp_uid');
      expect(confirmWrites.first.data['confirmedBy'], 'hr_uid');
    });
  });

  group('Loans: Anonymous offers, Guarantor, Loan Centre, Extensions', () {
    final cfg = LendingConfig(
      currencies: const ['XAF'],
      minAmount: const {'XAF': 5000},
      maxAmount: const {'XAF': 500000},
      durationsMonths: const [3, 6, 12],
      repaymentFrequencies: const ['monthly'],
      purposes: const ['business', 'emergency'],
      interestMethod: 'declining',
      annualInterestPercent: 12.0,
      feePercent: 2.0,
      latePenaltyPercent: 1.0,
      votingHours: 120,
      quorumPercent: 50,
      approvalPercent: 50,
      paymentMethods: const ['wallet', 'gateway'],
      loanCentreEnabled: true,
      loanCentreGuarantorRequired: true,
      loanCentreMaxAmount: const {'XAF': 200000},
      groupGuarantorRequired: true,
    );

    test('apply in Loan Centre (visibility: public) writes both loan_applications and anonymous loan_offers', () {
      final writes = LoanPlans.apply(
        loanId: 'loan_pub_1',
        uid: 'borrower_1',
        groupId: '',
        groupName: 'Loan Centre',
        memberIds: const [],
        amount: 100000,
        currency: 'XAF',
        purpose: 'business',
        durationMonths: 6,
        repaymentFrequency: 'monthly',
        description: 'Working capital',
        visibility: 'public',
        anonymous: true,
        guarantorUserId: 'guarantor_1',
        scoreBand: 'good',
      );

      expect(writes, hasLength(2));
      final app = writes.firstWhere((w) => w.path == 'loan_applications/loan_pub_1');
      expect(app.data['borrowerId'], 'borrower_1');
      expect(app.data['visibility'], 'public');
      expect(app.data['status'], 'guarantor_pending');
      expect(app.data['guarantor']['userId'], 'guarantor_1');
      expect(app.data['guarantor']['status'], 'invited');

      final offer = writes.firstWhere((w) => w.path == 'loan_offers/loan_pub_1');
      expect(offer.data['visibility'], 'public');
      expect(offer.data['status'], 'guarantor_pending');
      expect(offer.data['scoreBand'], 'good');
      expect(offer.data.containsKey('borrowerId'), isFalse);
    });

    test('guarantor required check in LoanChecks.apply', () {
      // Public loan without guarantor should be refused
      final errNoGuarantor = LoanChecks.apply(
        config: cfg,
        uid: 'b1',
        memberIds: const [],
        amount: 50000,
        currency: 'XAF',
        durationMonths: 3,
        frequency: 'monthly',
        restricted: false,
        isPublic: true,
        guarantorRequired: true,
      );
      expect(errNoGuarantor, 'guarantor_required');

      // Cannot guarantee self
      final errSelfGuarantor = LoanChecks.apply(
        config: cfg,
        uid: 'b1',
        memberIds: const [],
        amount: 50000,
        currency: 'XAF',
        durationMonths: 3,
        frequency: 'monthly',
        restricted: false,
        isPublic: true,
        guarantorRequired: true,
        guarantorUserId: 'b1',
      );
      expect(errSelfGuarantor, 'invite_self');

      // Valid with different guarantor
      final ok = LoanChecks.apply(
        config: cfg,
        uid: 'b1',
        memberIds: const [],
        amount: 50000,
        currency: 'XAF',
        durationMonths: 3,
        frequency: 'monthly',
        restricted: false,
        isPublic: true,
        guarantorRequired: true,
        guarantorUserId: 'g1',
      );
      expect(ok, isNull);
    });

    test('salary cap check in LoanChecks.apply', () {
      // Amount 120,000 exceeds salary cap 100,000 (1/3 of 300,000)
      final err = LoanChecks.apply(
        config: cfg,
        uid: 'emp1',
        memberIds: const ['emp1', 'other1'],
        amount: 120000,
        currency: 'XAF',
        durationMonths: 3,
        frequency: 'monthly',
        restricted: false,
        salaryCap: 100000,
      );
      expect(err, 'salary_cap_exceeded');

      // Amount 80,000 is within salary cap 100,000
      final ok = LoanChecks.apply(
        config: cfg,
        uid: 'emp1',
        memberIds: const ['emp1', 'other1'],
        amount: 80000,
        currency: 'XAF',
        durationMonths: 3,
        frequency: 'monthly',
        restricted: false,
        salaryCap: 100000,
      );
      expect(ok, isNull);
    });

    test('guarantor responds: accept transitions to submitted, decline transitions to rejected', () {
      final acceptWrites = LoanPlans.respondGuarantor('loan_1', 'g1', true);
      expect(acceptWrites, hasLength(2));
      final appAccept = acceptWrites.firstWhere((w) => w.path == 'loan_applications/loan_1');
      expect(appAccept.data['guarantor.status'], 'accepted');
      expect(appAccept.data['status'], 'submitted');
      final offerAccept = acceptWrites.firstWhere((w) => w.path == 'loan_offers/loan_1');
      expect(offerAccept.data['status'], 'submitted');

      final declineWrites = LoanPlans.respondGuarantor('loan_1', 'g1', false);
      expect(declineWrites, hasLength(2));
      final appDecline = declineWrites.firstWhere((w) => w.path == 'loan_applications/loan_1');
      expect(appDecline.data['guarantor.status'], 'declined');
      expect(appDecline.data['status'], 'rejected');
      expect(appDecline.data['reason'], 'guarantor_declined');
      final offerDecline = declineWrites.firstWhere((w) => w.path == 'loan_offers/loan_1');
      expect(offerDecline.data['status'], 'rejected');
    });

    test('requestExtension writes to loan_extension_requests', () {
      final writes = LoanPlans.requestExtension(
        extensionId: 'ext_1',
        loanId: 'loan_1',
        borrowerId: 'b1',
        installmentNumber: 2,
        requestedDays: 14,
        reason: 'Temporary delay in customer payments',
        extraInterestPercent: 1.5,
      );

      expect(writes, hasLength(1));
      expect(writes.first.path, 'loan_extension_requests/ext_1');
      expect(writes.first.data['installmentNumber'], 2);
      expect(writes.first.data['requestedDays'], 14);
      expect(writes.first.data['status'], 'requested');
      expect(writes.first.data['extraInterestPercent'], 1.5);
    });
  });
}
