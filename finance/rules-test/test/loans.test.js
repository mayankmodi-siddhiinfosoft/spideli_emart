// Member loans (design 3.8): apply (restricted users refused), vote (+1,
// once), close the vote, fund (never beyond the amount), the pay-out by the
// borrower only, repayments, and the lenders' collection bounded by their
// share of the repayments.

import { describe, it, beforeEach } from 'node:test';
import {
  setUp, as, ALICE, BOB, CAROL, EVE, MALLORY, plan, batchOf, create, update, patch, without, read, newKey,
  walletId, platformId, poolFields, gateway, SERVER_TIME, inc, WALLET, seed, union, later, day, dbl,
} from '../lib/fixtures.js';
import { allowed, denied, assert } from '../lib/expect.js';

const G = 'grp';
const L = 'loan1';

function seedGroup() {
  return seed({
    [`tontines/${G}`]: { id: G, name: 'Group', currency: 'XAF', contributionAmount: 5000, status: 'active', adminIds: [ALICE], memberIds: [ALICE, BOB, CAROL, EVE], membersLimit: 10, currentCycle: 1, createdBy: ALICE, createdAt: new Date() },
    [`financial_accounts/${walletId(EVE)}`]: { id: walletId(EVE), kind: 'wallet', userId: EVE, currency: 'XAF', balance: 50000, normalSide: 'credit', status: 'active', lastTxId: '' },
  });
}

function seedLoan(status, extra = {}) {
  return seed({
    [`loan_applications/${L}`]: {
      id: L, borrowerId: ALICE, groupId: G, groupName: 'Group', status, currency: 'XAF', amount: 20000, fundedAmount: 0, outstandingAmount: 0, repaidAmount: 0,
      durationMonths: 3, repaymentFrequency: 'monthly', purpose: 'business', description: '', eligibleVoterIds: [BOB, CAROL], lenderIds: [],
      votes: { yes: 0, no: 0 }, votingEndsAt: later(day), documents: [], createdAt: new Date(), ...extra,
    },
  });
}

function application(uid, id = newKey(), extra = {}) {
  return create(`loan_applications/${id}`, {
    id, borrowerId: uid, groupId: G, groupName: 'Group', status: 'submitted', currency: 'XAF', amount: 20000, fundedAmount: 0, outstandingAmount: 0, repaidAmount: 0,
    durationMonths: 3, repaymentFrequency: 'monthly', purpose: 'business', description: 'Stock', eligibleVoterIds: [ALICE, BOB, CAROL, EVE].filter((m) => m !== uid),
    lenderIds: [], votes: { yes: 0, no: 0 }, documents: [], createdAt: SERVER_TIME, updatedAt: SERVER_TIME, ...extra,
  });
}

const vote = (uid, approve, { by = 1 } = {}) => [
  create(`loan_votes/${L}_${uid}`, { loanId: L, voterId: uid, approve, comment: '', at: SERVER_TIME }),
  update(`loan_applications/${L}`, { [approve ? 'votes.yes' : 'votes.no']: inc(by), updatedAt: SERVER_TIME }),
];

async function fund(uid, amount, n = 1, { funding = WALLET } = {}) {
  const loan = await read(`loan_applications/${L}`);
  const id = `${L}_${uid}_${n}`;
  const last = loan.fundedAmount + amount >= loan.amount;
  const p = plan({
    type: 'loan_funding', from: funding.method === 'wallet' ? walletId(uid) : platformId(), to: `loan_${L}`, amount,
    newAccounts: loan.fundedAmount > 0 ? {} : { [`loan_${L}`]: poolFields('loan', L, 'XAF') },
    userIds: [uid], sourceKind: 'loan_fundings', sourceId: id, createdBy: uid, funding,
  });
  return [
    ...p.writes,
    create(`loan_fundings/${id}`, { id, loanId: L, lenderId: uid, borrowerId: loan.borrowerId, amount, currency: 'XAF', status: 'succeeded', funding: funding.method === 'wallet' ? 'wallet' : 'gateway', reference: p.reference, txId: p.txId, requestKey: newKey(), collected: 0, createdAt: SERVER_TIME }),
    update(`loan_applications/${L}`, { fundedAmount: loan.fundedAmount + amount, lenderIds: union(uid), ...(last ? { status: 'agreement_pending', fundedAt: SERVER_TIME } : {}), updatedAt: SERVER_TIME }),
    ...(last ? [create(`loan_agreements/${L}`, {
      loanId: L, borrowerId: loan.borrowerId, version: 1, principal: 20000, currency: 'XAF', interestMethod: 'flat', annualInterestPercent: dbl(12), fee: 400,
      totalRepayable: 20600, latePenaltyPercent: dbl(5), durationMonths: 3, repaymentFrequency: 'monthly', terms: '',
      installments: [{ number: 1, amount: 6867, principal: 6667, interest: 200 }, { number: 2, amount: 6867, principal: 6667, interest: 200 }, { number: 3, amount: 6866, principal: 6666, interest: 200 }],
      createdAt: SERVER_TIME, acceptedAt: null,
    })] : []),
  ];
}

function accept({ to = ALICE } = {}) {
  const p = plan({ type: 'loan_disbursement', from: `loan_${L}`, to: walletId(to), amount: 19600, fee: 400, userIds: [to], sourceKind: 'loan_disbursements', sourceId: L, createdBy: to });
  return [
    ...p.writes,
    create(`loan_disbursements/${L}`, { id: L, loanId: L, borrowerId: to, amount: 19600, fee: 400, currency: 'XAF', status: 'succeeded', reference: p.reference, txId: p.txId, paidAt: SERVER_TIME }),
    update(`loan_agreements/${L}`, { acceptedAt: SERVER_TIME }),
    update(`loan_applications/${L}`, { status: 'active', acceptedAt: SERVER_TIME, agreementVersion: 1, disbursedAt: SERVER_TIME, outstandingAmount: 20600, repaidAmount: 0, updatedAt: SERVER_TIME }),
    create(`loan_schedules/${L}`, { loanId: L, borrowerId: to, currency: 'XAF', installments: [{ number: 1, amount: 6867, status: 'upcoming' }, { number: 2, amount: 6867, status: 'upcoming' }, { number: 3, amount: 6866, status: 'upcoming' }], createdAt: SERVER_TIME, updatedAt: SERVER_TIME }),
  ];
}

async function repay(uid, amount) {
  const loan = await read(`loan_applications/${L}`);
  const key = newKey();
  const id = `${L}_${key}`;
  const out = loan.outstandingAmount - amount;
  const p = plan({ type: 'loan_repayment', from: walletId(uid), to: `loan_${L}`, amount, userIds: [uid], sourceKind: 'loan_repayments', sourceId: id, createdBy: uid });
  return [
    ...p.writes,
    create(`loan_repayments/${id}`, { id, loanId: L, borrowerId: uid, amount, currency: 'XAF', status: 'succeeded', funding: 'wallet', reference: p.reference, txId: p.txId, requestKey: key, createdAt: SERVER_TIME }),
    update(`loan_applications/${L}`, { outstandingAmount: out, repaidAmount: loan.repaidAmount + amount, ...(out === 0 ? { status: 'repaid', repaidAt: SERVER_TIME } : {}), updatedAt: SERVER_TIME }),
  ];
}

async function collect(uid, fundingId, amount) {
  const f = await read(`loan_fundings/${fundingId}`);
  const p = plan({ type: 'loan_lender_payout', from: `loan_${L}`, to: walletId(uid), amount, userIds: [uid], sourceKind: 'loan_fundings', sourceId: fundingId, createdBy: uid });
  return [...p.writes, update(`loan_fundings/${fundingId}`, { collected: f.collected + amount, updatedAt: SERVER_TIME })];
}

describe('member loans', () => {
  beforeEach(async () => {
    await setUp();
    await seedGroup();
  });

  it('a group member applies; a restricted user (loans) is refused; voters must be the whole group', async () => {
    allowed(await as(ALICE).commit(batchOf([application(ALICE)])));
    denied(await as(EVE).commit(batchOf([application(EVE)])), 'financeRestriction scopes [loans]');
    denied(await as(MALLORY).commit(batchOf([application(MALLORY)])), 'not a member of the group');
    denied(await as(ALICE).commit(batchOf([application(ALICE, newKey(), { eligibleVoterIds: [BOB] })])), 'voters chosen by the borrower');
    denied(await as(ALICE).commit(batchOf([application(ALICE, newKey(), { amount: 5000000 })])), 'above maxAmount');
    denied(await as(ALICE).commit(batchOf([application(ALICE, newKey(), { status: 'funding' })])), 'skipping the review');
  });

  it('readable by the borrower, voters and lenders; the credit assessment by the borrower only', async () => {
    await seedLoan('voting');
    await seed({ [`credit_assessments/${L}`]: { loanId: L, borrowerId: ALICE, score: 700 } });
    allowed(await as(ALICE).get(`loan_applications/${L}`));
    allowed(await as(BOB).get(`loan_applications/${L}`));
    allowed(await as(BOB).query('loan_applications', { where: [['eligibleVoterIds', 'array-contains', BOB]] }));
    denied(await as(MALLORY).get(`loan_applications/${L}`));
    allowed(await as(ALICE).get(`credit_assessments/${L}`));
    denied(await as(BOB).get(`credit_assessments/${L}`));
  });

  it('a vote counts +1, once, for an eligible voter only', async () => {
    await seedLoan('voting');
    allowed(await as(BOB).commit(batchOf(vote(BOB, true))));
    denied(await as(BOB).commit(batchOf(vote(BOB, true))), 'voting twice');
    denied(await as(CAROL).commit(batchOf(vote(CAROL, true, { by: 2 }))), '+2');
    denied(await as(CAROL).commit(batchOf([vote(CAROL, false)[0], update(`loan_applications/${L}`, { 'votes.yes': inc(1), updatedAt: SERVER_TIME })])), 'a no counted as a yes');
    denied(await as(CAROL).commit(batchOf([vote(CAROL, true)[1]])), 'a count without its vote');
    denied(await as(MALLORY).commit(batchOf(vote(MALLORY, true))), 'not eligible');
    denied(await as(ALICE).commit(batchOf(vote(ALICE, true))), 'the borrower');
    allowed(await as(CAROL).commit(batchOf(vote(CAROL, false))));
    const l = await read(`loan_applications/${L}`);
    assert.deepEqual(l.votes, { yes: 1, no: 1 });
    allowed(await as(BOB).get(`loan_votes/${L}_${BOB}`));
    denied(await as(CAROL).get(`loan_votes/${L}_${BOB}`), 'another voter\'s vote');
  });

  it('a vote after votingEndsAt is refused; the close follows the quorum and approval', async () => {
    await seedLoan('voting', { votingEndsAt: new Date(Date.now() - 1000), votes: { yes: 2, no: 0 } });
    denied(await as(BOB).commit(batchOf(vote(BOB, true))), 'after the end');
    const close = (status) => [update(`loan_applications/${L}`, { status, ...(status === 'rejected' ? { reason: 'vote' } : {}), votingClosedAt: SERVER_TIME, updatedAt: SERVER_TIME })];
    denied(await as(BOB).commit(batchOf(close('rejected'))), 'rejecting an approved vote');
    denied(await as(MALLORY).commit(batchOf(close('funding'))), 'not a participant');
    allowed(await as(BOB).commit(batchOf(close('funding'))));
  });

  it('funding: an eligible member, never beyond the amount, never the borrower; the last funder issues the agreement', async () => {
    await seedLoan('funding');
    allowed(await as(BOB).commit(batchOf(await fund(BOB, 15000))));
    assert.equal((await read(`financial_accounts/loan_${L}`)).balance, 15000);
    denied(await as(CAROL).commit(batchOf(await fund(CAROL, 10000))), 'beyond the amount');
    denied(await as(ALICE).commit(batchOf(await fund(ALICE, 5000))), 'the borrower');
    denied(await as(MALLORY).commit(batchOf(await fund(MALLORY, 5000))), 'not eligible');
    const lastFunding = await fund(CAROL, 5000);
    denied(await as(CAROL).commit(batchOf(patch(lastFunding, `loan_applications/${L}`, (d) => ({ ...d, fundedAmount: 25000 })))), 'fundedAmount not the posting');
    denied(await as(CAROL).commit(batchOf(patch(lastFunding, `loan_agreements/${L}`, (d) => ({ ...d, totalRepayable: 40000 })))), 'agreement above the configured interest');
    denied(await as(CAROL).commit(batchOf(without(lastFunding, `loan_agreements/${L}`))), 'funded without the agreement');
    allowed(await as(CAROL).commit(batchOf(lastFunding)));
    const l = await read(`loan_applications/${L}`);
    assert.equal(l.status, 'agreement_pending');
    assert.deepEqual(l.lenderIds, [BOB, CAROL]);
  });

  it('the pay-out: the borrower only, the whole funded amount (fee to the platform)', async () => {
    await seedLoan('funding');
    allowed(await as(BOB).commit(batchOf(await fund(BOB, 15000))));
    allowed(await as(CAROL).commit(batchOf(await fund(CAROL, 5000))));
    denied(await as(BOB).commit(batchOf(accept({ to: BOB }))), 'a lender pays the loan out to themself');
    const partial = accept().map((w) => (w.path.startsWith('ledger_transactions/') ? { ...w, data: { ...w.data, lines: [{ ...w.data.lines[0], amount: 10400 }, { ...w.data.lines[1], amount: 10000 }, w.data.lines[2]] } } : w));
    denied(await as(ALICE).commit(batchOf(partial)), 'part of the funded amount');
    allowed(await as(ALICE).commit(batchOf(accept())));
    assert.equal((await read(`financial_accounts/${walletId(ALICE)}`)).balance, 119600);
    assert.equal((await read(`financial_accounts/loan_${L}`)).balance, 0);
    assert.equal((await read(`loan_applications/${L}`)).outstandingAmount, 20600);
    denied(await as(ALICE).commit(batchOf(accept())), 'paid out twice');
  });

  it('repayments lower outstandingAmount by exactly the posting; lenders collect at most their share', async () => {
    await seedLoan('funding');
    allowed(await as(BOB).commit(batchOf(await fund(BOB, 15000))));
    allowed(await as(CAROL).commit(batchOf(await fund(CAROL, 5000))));
    allowed(await as(ALICE).commit(batchOf(accept())));
    const r = await repay(ALICE, 8000);
    denied(await as(ALICE).commit(batchOf(patch(r, `loan_applications/${L}`, (d) => ({ ...d, outstandingAmount: 0, status: 'repaid', repaidAt: SERVER_TIME })))), 'outstanding cleared by a partial repayment');
    denied(await as(BOB).commit(batchOf(await repay(BOB, 8000))), 'someone else repays as the borrower');
    allowed(await as(ALICE).commit(batchOf(r)));
    assert.equal((await read(`loan_applications/${L}`)).outstandingAmount, 12600);
    // repaid 8000: Bob (15000 of 20000) may collect floor(8000 x 15000 / 20000) = 6000, Carol 2000.
    denied(await as(BOB).commit(batchOf(await collect(BOB, `${L}_${BOB}_1`, 6001))), 'above the share');
    denied(await as(CAROL).commit(batchOf(await collect(CAROL, `${L}_${BOB}_1`, 1000))), 'on someone else\'s funding');
    allowed(await as(BOB).commit(batchOf(await collect(BOB, `${L}_${BOB}_1`, 4000))));
    denied(await as(BOB).commit(batchOf(await collect(BOB, `${L}_${BOB}_1`, 2001))), 'the rest of the share + 1');
    allowed(await as(BOB).commit(batchOf(await collect(BOB, `${L}_${BOB}_1`, 2000))));
    allowed(await as(CAROL).commit(batchOf(await collect(CAROL, `${L}_${CAROL}_1`, 2000))));
    assert.equal((await read(`financial_accounts/loan_${L}`)).balance, 0);
  });

  it('the borrower cancels before money is committed, not after', async () => {
    await seedLoan('voting');
    const cancel = [update(`loan_applications/${L}`, { status: 'cancelled', cancelledAt: SERVER_TIME, updatedAt: SERVER_TIME })];
    denied(await as(BOB).commit(batchOf(cancel)));
    allowed(await as(ALICE).commit(batchOf(cancel)));
    await seedLoan('active');
    denied(await as(ALICE).commit(batchOf(cancel)));
  });
});
