// The app's other write shapes, as it sends them (customer/lib/utils/
// finance_*_rules.dart): each must be accepted (a false refusal breaks the
// app), with the matching misuse refused.

import { describe, it, beforeEach } from 'node:test';
import {
  setUp, as, stale, ALICE, BOB, CAROL, MALLORY, plan, batchOf, create, update, merge, read, newKey, walletId, platformId,
  SERVER_TIME, seed, union, later, day, DELETE, inc,
} from '../lib/fixtures.js';
import { allowed, denied, assert } from '../lib/expect.js';

describe('savings and tontine housekeeping', () => {
  beforeEach(async () => {
    await setUp();
    await seed({
      'savings_goals/g1': { id: 'g1', ownerId: ALICE, memberIds: [ALICE, BOB], invitedIds: [], name: 'Trip', purpose: 'travel', description: '', currency: 'XAF', targetAmount: 100000, savedAmount: 0, status: 'active', schedule: { frequency: 'monthly', amount: 1000 } },
      'tontines/tf': { id: 'tf', name: 'F', status: 'forming', adminIds: [ALICE], memberIds: [ALICE, BOB, CAROL], membersLimit: 4, currency: 'XAF', contributionAmount: 5000, frequency: 'monthly', payoutOrderMethod: 'random', rules: '', currentCycle: 0, createdBy: ALICE },
      'tontine_members/tf_alice': { id: 'tf_alice', tontineId: 'tf', userId: ALICE, role: 'admin', status: 'active', payoutPosition: 1 },
      'tontine_members/tf_bob': { id: 'tf_bob', tontineId: 'tf', userId: BOB, role: 'member', status: 'active' },
      'tontine_members/tf_carol': { id: 'tf_carol', tontineId: 'tf', userId: CAROL, role: 'member', status: 'active' },
      'tontine_members/tf_mallory': { id: 'tf_mallory', tontineId: 'tf', userId: MALLORY, role: 'member', status: 'declined', invitedBy: ALICE },
    });
  });

  it('goal: the owner edits, removes the schedule and invites; a member does not; the group cancellation request', async () => {
    allowed(await as(ALICE).commit(batchOf([update('savings_goals/g1', { name: 'Big trip', deadline: later(90 * day), schedule: DELETE, updatedAt: SERVER_TIME })])));
    denied(await as(BOB).commit(batchOf([update('savings_goals/g1', { name: 'Mine', updatedAt: SERVER_TIME })])));
    allowed(await as(ALICE).commit(batchOf([update('savings_goals/g1', { invitedIds: union(CAROL), updatedAt: SERVER_TIME })])));
    denied(await as(ALICE).commit(batchOf([update('savings_goals/g1', { invitedIds: union('x1', 'x2', 'x3', 'x4'), updatedAt: SERVER_TIME })])), 'beyond maxMembers');
    allowed(await as(ALICE).commit(batchOf([update('savings_goals/g1', { status: 'cancellation_requested', cancellationRequestedBy: ALICE, cancellationRequestedAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
  });

  it('tontine: invite again after a decline; a random start draws and saves the order with the cycles', async () => {
    const t = await read('tontines/tf');
    allowed(await as(ALICE).commit(batchOf([update('tontine_members/tf_mallory', {
      id: 'tf_mallory', tontineId: 'tf', tontineName: 'F', userId: MALLORY, displayName: 'M', email: '', role: 'member', status: 'invited', invitedBy: ALICE, invitedByName: 'A',
      contributionAmount: 5000, currency: 'XAF', frequency: 'monthly', membersLimit: 4, rules: '', payoutOrderMethod: 'random', invitedAt: SERVER_TIME,
    })])));
    const order = [CAROL, ALICE, BOB];
    const start = [
      ...order.map((u, i) => update(`tontine_members/tf_${u}`, { payoutPosition: i + 1 })),
      update('tontines/tf', { status: 'active', currentCycle: 1, nextDueAt: new Date(), startDate: new Date(), startedAt: SERVER_TIME, updatedAt: SERVER_TIME }),
      ...order.map((u, i) => create(`tontine_cycles/tf_${i + 1}`, { id: `tf_${i + 1}`, tontineId: 'tf', number: i + 1, dueDate: later((i + 1) * 30 * day), beneficiaryUserId: u, expectedAmount: 15000, collectedAmount: 0, currency: 'XAF', status: i === 0 ? 'collecting' : 'upcoming', createdAt: SERVER_TIME })),
    ];
    denied(await as(ALICE).commit(batchOf(start.slice(0, 3))), 'positions of a random tontine outside its start');
    allowed(await as(ALICE).commit(batchOf(start)));
    assert.equal((await read('tontine_members/tf_carol')).payoutPosition, 1);
    denied(await as(ALICE).commit(batchOf([create('tontine_cycles/tf_4', { id: 'tf_4', tontineId: 'tf', number: 4, beneficiaryUserId: ALICE, expectedAmount: 15000, collectedAmount: 0, currency: 'XAF', status: 'upcoming', createdAt: SERVER_TIME })])), 'an extra cycle after the start');
  });
});

describe('loan housekeeping', () => {
  beforeEach(async () => {
    await setUp();
    await seed({ 'loan_applications/l2': { id: 'l2', borrowerId: ALICE, groupId: 'g', status: 'voting', currency: 'XAF', amount: 20000, fundedAmount: 0, outstandingAmount: 0, repaidAmount: 0, eligibleVoterIds: [BOB, CAROL], lenderIds: [], votes: { yes: 0, no: 2 }, votingEndsAt: new Date(Date.now() - 1000), documents: [] } });
  });

  it('a supporting document by the borrower; a vote without the approval closes as rejected', async () => {
    allowed(await as(ALICE).commit(batchOf([update('loan_applications/l2', { documents: union({ name: 'Invoice', storagePath: `loan_documents/${ALICE}/l2/document-1-1.jpg` }), updatedAt: SERVER_TIME })])));
    denied(await as(BOB).commit(batchOf([update('loan_applications/l2', { documents: union({ name: 'x', storagePath: 'y' }), updatedAt: SERVER_TIME })])));
    denied(await as(CAROL).commit(batchOf([update('loan_applications/l2', { status: 'funding', votingClosedAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
    allowed(await as(CAROL).commit(batchOf([update('loan_applications/l2', { status: 'rejected', reason: 'vote', votingClosedAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
  });
});

describe('cards, insurance, investments, financing, KYC housekeeping', () => {
  beforeEach(async () => {
    await setUp();
    await seed({
      'virtual_cards/c1': { id: 'c1', userId: ALICE, currency: 'XAF', status: 'active', balance: 20000 },
      'insurance_quotes/q2': { id: 'q2', userId: ALICE, productId: 'p1', currency: 'XAF', status: 'quoted', premium: 60000, installmentAmount: 5000, validUntil: later(day) },
      'insurance_policies/pol': { id: 'pol', userId: ALICE, quoteId: 'pol', currency: 'XAF', premium: 60000, installmentAmount: 5000, status: 'renewal_due', renewalPremium: 62000 },
      'insurance_policies/pol2': { id: 'pol2', userId: ALICE, currency: 'XAF', premium: 60000, status: 'active', policyNumber: 'P-1', productName: 'Health' },
      'insurance_premiums/pol_2': { id: 'pol_2', userId: ALICE, policyId: 'pol', amount: 5000, currency: 'XAF', status: 'due', dueDate: new Date() },
      'insurance_claims/cl1': { id: 'cl1', userId: ALICE, policyId: 'pol2', currency: 'XAF', status: 'info_requested', documents: [] },
      'investment_redemptions/r1': { id: 'r1', userId: ALICE, fundId: 'f1', status: 'submitted' },
      'investment_redemptions/r2': { id: 'r2', userId: ALICE, fundId: 'f1', status: 'processing' },
      'financing_projects/pr': { id: 'pr', ownerId: ALICE, name: 'Shop', sector: 'commerce', country: 'CM', city: 'D', description: 'x', stage: 'startup', website: 'https://x.test' },
      'financing_applications/fa': { id: 'fa', ownerId: ALICE, projectId: 'pr', financingType: 'loan', amount: 1000000, currency: 'XAF', useOfFunds: 'x', status: 'additional_info_required' },
      'financing_documents/fd': { id: 'fd', ownerId: ALICE, applicationId: 'fa', type: 'business_plan', status: 'received' },
      'platform_settings/financing': { currencies: ['XAF'], financingTypes: ['loan', 'equity'], sectors: ['commerce'], stages: ['startup'], documentTypes: ['business_plan'], minAmount: { XAF: 500000 }, maxAmount: { XAF: 50000000 }, durationsMonths: [12] },
      'kyc_applications/k1': { id: 'k1', userId: ALICE, level: 'basic', accountType: 'individual', status: 'draft', revision: 1 },
      'kyc_documents/k1_national_id_front_1': { id: 'k1_national_id_front_1', applicationId: 'k1', userId: ALICE, type: 'national_id', side: 'front', status: 'uploaded' },
    });
  });

  it('card: a card-to-card transfer request is re-authenticated and within the balance', async () => {
    const tr = (amount, recipientId = BOB) => create(`card_funding_requests/${newKey()}`, { userId: ALICE, cardId: 'c1', type: 'transfer', amount, fee: 0, currency: 'XAF', recipientId, recipient: { userId: recipientId, name: 'Bob', contact: 'b@x.test' }, status: 'pending', reference: 'SPF-2', createdAt: SERVER_TIME, updatedAt: SERVER_TIME });
    denied(await stale(ALICE).commit(batchOf([tr(1000)])));
    denied(await as(ALICE).commit(batchOf([tr(1000, ALICE)])), 'to oneself');
    allowed(await as(ALICE).commit(batchOf([tr(1000)])));
  });

  it('insurance: decline, pay a due premium, renew at the renewal premium, auto-renew, cancel, answer and withdraw a claim', async () => {
    allowed(await as(ALICE).commit(batchOf([update('insurance_quotes/q2', { status: 'declined', declinedAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
    const p = plan({ type: 'insurance_premium', from: walletId(ALICE), to: platformId(), amount: 5000, userIds: [ALICE], sourceKind: 'insurance_premiums', sourceId: 'pol_2', createdBy: ALICE });
    const pay = [update('insurance_premiums/pol_2', { status: 'paid', paidAt: SERVER_TIME, txId: p.txId, reference: p.reference, payment: { method: 'wallet' }, updatedAt: SERVER_TIME }), ...p.writes];
    denied(await as(BOB).commit(batchOf(pay)), 'someone else\'s premium');
    allowed(await as(ALICE).commit(batchOf(pay)));
    const r = plan({ type: 'insurance_premium', from: walletId(ALICE), to: platformId(), amount: 62000, userIds: [ALICE], sourceKind: 'insurance_policies', sourceId: 'pol', createdBy: ALICE });
    const renew = (amount) => [update('insurance_policies/pol', { renewalRequestedAt: SERVER_TIME, renewalPaidAmount: amount, renewalTxId: r.txId, renewalReference: r.reference, renewalPayment: { method: 'wallet' }, updatedAt: SERVER_TIME }), ...r.writes];
    denied(await as(ALICE).commit(batchOf(renew(1000))), 'a renewal paid below the renewal premium');
    allowed(await as(ALICE).commit(batchOf(renew(62000))));
    allowed(await as(ALICE).commit(batchOf([update('insurance_policies/pol2', { autoRenew: true, updatedAt: SERVER_TIME })])));
    denied(await as(ALICE).commit(batchOf([update('insurance_policies/pol2', { status: 'active', policyNumber: 'P-2', updatedAt: SERVER_TIME })])));
    allowed(await as(ALICE).commit(batchOf([update('insurance_policies/pol2', { status: 'cancellation_requested', statusBefore: 'active', cancellationReason: 'Too expensive', cancellationRequestedAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
    const eid = newKey();
    allowed(await as(ALICE).commit(batchOf([
      update('insurance_claims/cl1', { status: 'under_review', documents: union({ name: 'photo', storagePath: `insurance_claims/${ALICE}/cl1/1.jpg` }), respondedAt: SERVER_TIME, updatedAt: SERVER_TIME }),
      create(`insurance_claims/cl1/events/${eid}`, { id: eid, type: 'customer_response', userId: ALICE, authorId: ALICE, message: 'Here it is', documents: [], createdAt: SERVER_TIME }),
    ])));
    denied(await as(ALICE).commit(batchOf([update('insurance_claims/cl1', { status: 'approved', updatedAt: SERVER_TIME })])));
    allowed(await as(ALICE).commit(batchOf([update('insurance_claims/cl1', { status: 'withdrawn', withdrawnAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
    allowed(await as(ALICE).query('events', {}, 'insurance_claims/cl1'));
    denied(await as(BOB).query('events', {}, 'insurance_claims/cl1'));
  });

  it('a claim on an active policy only', async () => {
    const claim = (policyId) => create(`insurance_claims/${newKey()}`, { userId: ALICE, policyId, policyNumber: 'P-1', productName: 'Health', currency: 'XAF', incidentDate: new Date(), description: 'Broken arm', amountClaimed: 30000, documents: [], status: 'submitted', createdAt: SERVER_TIME, updatedAt: SERVER_TIME });
    allowed(await as(ALICE).commit(batchOf([claim('pol2')])));
    await seed({ 'insurance_policies/pol3': { id: 'pol3', userId: ALICE, currency: 'XAF', status: 'pending_activation' } });
    denied(await as(ALICE).commit(batchOf([claim('pol3')])));
  });

  it('investments: a redemption is cancelled only while submitted', async () => {
    const cancel = (id) => update(`investment_redemptions/${id}`, { status: 'cancelled', cancelledAt: SERVER_TIME, updatedAt: SERVER_TIME });
    allowed(await as(ALICE).commit(batchOf([cancel('r1')])));
    denied(await as(ALICE).commit(batchOf([cancel('r2')])));
  });

  it('financing: edits while editable (optional fields deleted), a document removed while editable, withdrawn', async () => {
    allowed(await as(ALICE).commit(batchOf([update('financing_projects/pr', { name: 'Shop 2', sector: 'commerce', country: 'CM', city: 'D', description: 'y', stage: DELETE, employees: DELETE, foundedYear: DELETE, website: DELETE, updatedAt: SERVER_TIME })])));
    denied(await as(BOB).commit(batchOf([update('financing_projects/pr', { name: 'Mine', updatedAt: SERVER_TIME })])));
    allowed(await as(ALICE).commit(batchOf([update('financing_applications/fa', { financingType: 'equity', amount: 2000000, currency: 'XAF', durationMonths: DELETE, useOfFunds: 'z', updatedAt: SERVER_TIME })])));
    denied(await as(ALICE).commit(batchOf([update('financing_applications/fa', { approvedAmount: 2000000, updatedAt: SERVER_TIME })])));
    denied(await as(BOB).commit(batchOf([{ path: 'financing_documents/fd', op: 'delete' }])));
    allowed(await as(ALICE).commit(batchOf([{ path: 'financing_documents/fd', op: 'delete' }])));
    allowed(await as(ALICE).commit(batchOf([update('financing_applications/fa', { status: 'withdrawn', withdrawnAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
  });

  it('KYC: a new upload supersedes the earlier one of the same type and side', async () => {
    const id = 'k1_national_id_front_2';
    allowed(await as(ALICE).commit(batchOf([
      create(`kyc_documents/${id}`, { id, applicationId: 'k1', userId: ALICE, type: 'national_id', side: 'front', status: 'uploaded', storagePath: `kyc/${ALICE}/k1/national_id-front-2.jpg`, contentType: 'image/jpeg', size: 2000, revision: 1, createdAt: SERVER_TIME }),
      update('kyc_documents/k1_national_id_front_1', { status: 'superseded', supersededBy: id, updatedAt: SERVER_TIME }),
    ])));
    denied(await as(ALICE).commit(batchOf([update(`kyc_documents/${id}`, { status: 'accepted', updatedAt: SERVER_TIME })])));
  });

  it('the account\'s own savedPaymentMethods (bank entries included) stay writable', async () => {
    allowed(await as(ALICE).commit(batchOf([update(`users/${ALICE}`, { savedPaymentMethods: [{ id: 'b1', type: 'bank', number: '0123456789', bankName: 'Afriland', holderName: 'Alice', isDefault: false }] })])));
    allowed(await as(ALICE).commit(batchOf([create(`transfer_beneficiaries/ben_${ALICE}_mobile_money_237600`, { userId: ALICE, channel: 'mobile_money', displayName: 'Mum', detail: '+237 6•• 00', recipient: { operator: 'Orange Money', number: '+237600000000' }, createdAt: SERVER_TIME, lastUsedAt: SERVER_TIME })])));
    denied(await as(ALICE).commit(batchOf([create(`transfer_beneficiaries/ben_${BOB}_mobile_money_1`, { userId: ALICE, channel: 'mobile_money', recipient: {}, createdAt: SERVER_TIME, lastUsedAt: SERVER_TIME })])), 'an id of someone else');
    allowed(await as(ALICE).commit(batchOf([{ path: `transfer_beneficiaries/ben_${ALICE}_mobile_money_237600`, op: 'delete' }])));
    allowed(await as(ALICE).commit(batchOf([create(`utility_saved_accounts/acc_${ALICE}_eneo_123`, { userId: ALICE, billerId: 'eneo', billerName: 'ENEO', category: 'electricity', account: '123', nickname: '', createdAt: SERVER_TIME, lastUsedAt: SERVER_TIME })])));
  });
});
