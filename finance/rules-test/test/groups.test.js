// Savings goals and tontines (design 3.6, 3.7): pools, counters tied to
// their posting, membership, one contribution per cycle and member, payouts
// approved by an admin who is not the beneficiary.

import { describe, it, beforeEach } from 'node:test';
import {
  setUp, as, ALICE, BOB, CAROL, DAVE, MALLORY, plan, batchOf, create, update, patch, without, read, newKey, newRef,
  walletId, platformId, walletFields, poolFields, gateway, SERVER_TIME, inc, WALLET, seed, union, later, day,
} from '../lib/fixtures.js';
import { allowed, denied, assert } from '../lib/expect.js';

// ---- savings: SavingsWrites -------------------------------------------------

function createGoal(uid, goalId, { invitedIds = [] } = {}) {
  return [
    create(`savings_goals/${goalId}`, {
      id: goalId, ownerId: uid, memberIds: [uid], invitedIds, name: 'Trip', purpose: 'travel', description: '', currency: 'XAF',
      targetAmount: 100000, savedAmount: 0, schedule: { frequency: 'monthly', amount: 10000 }, status: 'active', accountId: `goal_${goalId}`,
      createdAt: SERVER_TIME, updatedAt: SERVER_TIME,
    }),
    create(`financial_accounts/goal_${goalId}`, { ...poolFields('savings_goal', goalId, 'XAF', [uid]), id: `goal_${goalId}`, balance: 0, normalSide: 'credit', status: 'active', createdAt: SERVER_TIME, updatedAt: SERVER_TIME }),
  ];
}

function contribute(uid, goalId, amount, { funding = WALLET } = {}) {
  const id = newKey();
  const p = plan({ type: 'savings_contribution', from: funding.method === 'wallet' ? walletId(uid) : platformId(), to: `goal_${goalId}`, amount, userIds: [uid], sourceKind: 'savings_contributions', sourceId: id, createdBy: uid, funding });
  return {
    txId: p.txId,
    writes: [
      create(`savings_contributions/${id}`, { id, goalId, userId: uid, amount, currency: 'XAF', status: 'succeeded', reference: p.reference, txId: p.txId, funding: funding.method === 'wallet' ? 'wallet' : 'gateway', ...(funding.method === 'wallet' ? {} : { gateway: funding }), createdAt: SERVER_TIME }),
      ...p.writes,
      update(`savings_goals/${goalId}`, { savedAmount: inc(amount), lastTxId: p.txId, updatedAt: SERVER_TIME }),
    ],
  };
}

function soloWithdraw(uid, goalId, amount) {
  const id = newKey();
  const p = plan({ type: 'savings_withdrawal', from: `goal_${goalId}`, to: walletId(uid), amount, userIds: [uid], sourceKind: 'savings_withdrawals', sourceId: id, createdBy: uid });
  return [
    create(`savings_withdrawals/${id}`, { id, goalId, userId: uid, amount, currency: 'XAF', destination: { method: 'wallet', accountId: walletId(uid) }, createdAt: SERVER_TIME, status: 'completed', reference: p.reference, txId: p.txId, completedAt: SERVER_TIME }),
    ...p.writes,
    update(`savings_goals/${goalId}`, { savedAmount: inc(-amount), lastTxId: p.txId, updatedAt: SERVER_TIME }),
  ];
}

// ---- tontines: TontineWrites -----------------------------------------------

const T = 't1';
function seedActiveTontine({ beneficiary1 = BOB } = {}) {
  const members = [ALICE, BOB, CAROL];
  const order = [beneficiary1, ...members.filter((m) => m !== beneficiary1)];
  const docs = {
    [`tontines/${T}`]: { id: T, name: 'Family', currency: 'XAF', contributionAmount: 5000, frequency: 'monthly', membersLimit: 5, payoutOrderMethod: 'fixed', status: 'active', adminIds: [ALICE, BOB], memberIds: members, currentCycle: 1, potAccountId: `tontine_${T}`, createdBy: ALICE, createdAt: new Date() },
    [`financial_accounts/tontine_${T}`]: { id: `tontine_${T}`, kind: 'tontine_pot', refId: T, currency: 'XAF', balance: 0, normalSide: 'credit', status: 'active', lastTxId: '' },
  };
  order.forEach((uid, i) => {
    docs[`tontine_members/${T}_${uid}`] = { id: `${T}_${uid}`, tontineId: T, userId: uid, role: [ALICE, BOB].includes(uid) ? 'admin' : 'member', status: 'active', payoutPosition: i + 1 };
    docs[`tontine_cycles/${T}_${i + 1}`] = { id: `${T}_${i + 1}`, tontineId: T, number: i + 1, beneficiaryUserId: uid, expectedAmount: 15000, collectedAmount: 0, currency: 'XAF', status: i === 0 ? 'collecting' : 'upcoming', dueDate: later(30 * (i + 1) * day) };
  });
  return seed(docs);
}

async function tontineContribution(uid, cycleId, { funding = WALLET } = {}) {
  const cycle = await read(`tontine_cycles/${cycleId}`);
  const id = `${cycleId}_${uid}`;
  const amount = 5000;
  const completes = cycle.collectedAmount + amount >= cycle.expectedAmount;
  const p = plan({ type: 'tontine_contribution', from: funding.method === 'wallet' ? walletId(uid) : platformId(), to: `tontine_${T}`, amount, userIds: [uid], sourceKind: 'tontine_contributions', sourceId: id, createdBy: uid, funding });
  return {
    txId: p.txId,
    writes: [
      create(`tontine_contributions/${id}`, { id, tontineId: T, cycleId, cycleNumber: cycle.number, userId: uid, amount, currency: 'XAF', status: 'paid', reference: p.reference, txId: p.txId, funding: funding.method === 'wallet' ? 'wallet' : 'gateway', ...(funding.method === 'wallet' ? {} : { gateway: funding }), paidAt: SERVER_TIME, createdAt: SERVER_TIME }),
      ...p.writes,
      update(`tontine_cycles/${cycleId}`, { collectedAmount: inc(amount), ...(completes ? { status: 'payout_pending' } : {}), lastTxId: p.txId, updatedAt: SERVER_TIME }),
      ...(completes ? [create(`tontine_payouts/${cycleId}`, { id: cycleId, tontineId: T, cycleId, cycleNumber: cycle.number, beneficiaryUserId: cycle.beneficiaryUserId, amount: cycle.expectedAmount, currency: 'XAF', status: 'pending_approval', createdAt: SERVER_TIME })] : []),
    ],
  };
}

async function approvePayout(approver, cycleNumber) {
  const cycleId = `${T}_${cycleNumber}`;
  const payout = await read(`tontine_payouts/${cycleId}`);
  const next = await read(`tontine_cycles/${T}_${cycleNumber + 1}`);
  const p = plan({ type: 'tontine_payout', from: `tontine_${T}`, to: walletId(payout.beneficiaryUserId), amount: payout.amount, userIds: [payout.beneficiaryUserId], sourceKind: 'tontine_payouts', sourceId: cycleId, createdBy: approver });
  return [
    ...p.writes,
    update(`tontine_payouts/${cycleId}`, { status: 'paid', txId: p.txId, reference: p.reference, approvedBy: approver, approvedAt: SERVER_TIME, paidAt: SERVER_TIME }),
    update(`tontine_cycles/${cycleId}`, { status: 'paid', paidAt: SERVER_TIME, updatedAt: SERVER_TIME }),
    ...(next
      ? [update(`tontine_cycles/${T}_${cycleNumber + 1}`, { status: 'collecting', updatedAt: SERVER_TIME }), update(`tontines/${T}`, { currentCycle: cycleNumber + 1, nextDueAt: next.dueDate, updatedAt: SERVER_TIME })]
      : [update(`tontines/${T}`, { status: 'completed', completedAt: SERVER_TIME, updatedAt: SERVER_TIME })]),
  ];
}

describe('savings goals', () => {
  beforeEach(setUp);

  it('the owner creates a goal with its empty account; never for someone else, never with money in it', async () => {
    allowed(await as(ALICE).commit(batchOf(createGoal(ALICE, 'g1', { invitedIds: [BOB] }))));
    denied(await as(MALLORY).commit(batchOf(patch(createGoal(ALICE, 'g2'), 'savings_goals/g2', (d) => d))), 'ownerId is someone else');
    denied(await as(ALICE).commit(batchOf(patch(createGoal(ALICE, 'g3'), 'savings_goals/g3', (d) => ({ ...d, savedAmount: 50000 })))));
    denied(await as(ALICE).commit(batchOf(patch(createGoal(ALICE, 'g4'), 'financial_accounts/goal_g4', (d) => ({ ...d, balance: 50000 })))));
  });

  it('members and invitees read the goal; a stranger does not', async () => {
    allowed(await as(ALICE).commit(batchOf(createGoal(ALICE, 'g1', { invitedIds: [BOB] }))));
    allowed(await as(BOB).get('savings_goals/g1'));
    allowed(await as(BOB).query('savings_goals', { where: [['invitedIds', 'array-contains', BOB]] }));
    denied(await as(MALLORY).get('savings_goals/g1'));
    denied(await as(MALLORY).get('financial_accounts/goal_g1'));
  });

  it('the invitee joins; only themself; a member contributes and savedAmount follows the posting exactly', async () => {
    allowed(await as(ALICE).commit(batchOf(createGoal(ALICE, 'g1', { invitedIds: [BOB] }))));
    denied(await as(MALLORY).commit(batchOf([update('savings_goals/g1', { invitedIds: [], memberIds: [ALICE, MALLORY], updatedAt: SERVER_TIME })])), 'not invited');
    allowed(await as(BOB).commit(batchOf([update('savings_goals/g1', { invitedIds: [], memberIds: union(BOB), updatedAt: SERVER_TIME })])));
    const c = contribute(BOB, 'g1', 7000);
    allowed(await as(BOB).commit(batchOf(c.writes)));
    assert.equal((await read('savings_goals/g1')).savedAmount, 7000);
    assert.equal((await read('financial_accounts/goal_g1')).balance, 7000);
    // savedAmount moved by another amount than the posting
    const bad = contribute(BOB, 'g1', 1000);
    denied(await as(BOB).commit(batchOf(patch(bad.writes, 'savings_goals/g1', (d) => ({ ...d, savedAmount: inc(5000) })))), 'savedAmount +5000 for a 1000 posting');
    // no savedAmount update at all
    denied(await as(BOB).commit(batchOf(without(bad.writes, 'savings_goals/g1'))), 'posting without the goal counter');
    // savedAmount moved without any posting
    denied(await as(BOB).commit(batchOf([update('savings_goals/g1', { savedAmount: inc(100000), updatedAt: SERVER_TIME })])));
    // a stranger contributing
    denied(await as(MALLORY).commit(batchOf(contribute(MALLORY, 'g1', 1000).writes)));
  });

  it('a gateway-funded contribution (platform -> goal with its receipt)', async () => {
    allowed(await as(ALICE).commit(batchOf(createGoal(ALICE, 'g1'))));
    allowed(await as(ALICE).commit(batchOf(contribute(ALICE, 'g1', 3000, { funding: gateway('stripe', 'pi_g1') }).writes)));
    assert.equal((await read('savings_goals/g1')).savedAmount, 3000);
  });

  it('the solo owner withdraws to their own wallet; a group goal only requests; nobody else withdraws', async () => {
    allowed(await as(ALICE).commit(batchOf(createGoal(ALICE, 'g1'))));
    allowed(await as(ALICE).commit(batchOf(contribute(ALICE, 'g1', 20000).writes)));
    allowed(await as(ALICE).commit(batchOf(soloWithdraw(ALICE, 'g1', 5000))));
    assert.equal((await read('savings_goals/g1')).savedAmount, 15000);
    denied(await as(ALICE).commit(batchOf(soloWithdraw(ALICE, 'g1', 50000))), 'more than saved');
    denied(await as(MALLORY).commit(batchOf(soloWithdraw(MALLORY, 'g1', 1000))), 'a stranger');
    // to someone else's wallet
    const w = soloWithdraw(ALICE, 'g1', 1000);
    const tx = w.find((x) => x.path.startsWith('ledger_transactions/'));
    const redirected = w.map((x) => (x.path === `financial_accounts/${walletId(ALICE)}` ? { ...x, path: `financial_accounts/${walletId(MALLORY)}` } : x))
      .map((x) => (x === tx ? { ...x, data: { ...x.data, lines: [x.data.lines[0], { ...x.data.lines[1], accountId: walletId(MALLORY) }], accountIds: [`goal_g1`, walletId(MALLORY)], userIds: [MALLORY, ALICE] } } : x));
    denied(await as(ALICE).commit(batchOf(redirected)), 'goal money to another wallet');
    // a group goal: the direct withdrawal is refused, the request is allowed
    allowed(await as(BOB).commit(batchOf(createGoal(BOB, 'g2', { invitedIds: [CAROL] }))));
    allowed(await as(CAROL).commit(batchOf([update('savings_goals/g2', { invitedIds: [], memberIds: union(CAROL), updatedAt: SERVER_TIME })])));
    allowed(await as(CAROL).commit(batchOf(contribute(CAROL, 'g2', 4000).writes)));
    denied(await as(BOB).commit(batchOf(soloWithdraw(BOB, 'g2', 1000))));
    const rid = newKey();
    allowed(await as(CAROL).commit(batchOf([create(`savings_withdrawals/${rid}`, { id: rid, goalId: 'g2', userId: CAROL, amount: 1000, currency: 'XAF', destination: { method: 'wallet', accountId: walletId(CAROL) }, createdAt: SERVER_TIME, status: 'requested' })])));
  });

  it('the solo owner cancels: the whole balance back to the wallet', async () => {
    allowed(await as(ALICE).commit(batchOf(createGoal(ALICE, 'g1'))));
    allowed(await as(ALICE).commit(batchOf(contribute(ALICE, 'g1', 8000).writes)));
    const p = plan({ type: 'savings_withdrawal', from: 'goal_g1', to: walletId(ALICE), amount: 8000, userIds: [ALICE], sourceKind: 'savings_goals', sourceId: 'g1', createdBy: ALICE });
    const cancel = [...p.writes, update('savings_goals/g1', { status: 'cancelled', savedAmount: inc(-8000), lastTxId: p.txId, cancelledAt: SERVER_TIME, updatedAt: SERVER_TIME })];
    denied(await as(ALICE).commit(batchOf(patch(cancel, 'savings_goals/g1', (d) => ({ ...d, savedAmount: inc(-7000) })))), 'cancelled with money left in the counter');
    allowed(await as(ALICE).commit(batchOf(cancel)));
    assert.equal((await read('savings_goals/g1')).status, 'cancelled');
    assert.equal((await read(`financial_accounts/${walletId(ALICE)}`)).balance, 100000);
  });
});

describe('tontines', () => {
  beforeEach(setUp);

  it('create, invite, accept, start: the app\'s batches', async () => {
    const tid = 'tn';
    const now = new Date();
    allowed(await as(ALICE).commit(batchOf([
      create(`tontines/${tid}`, { id: tid, name: 'Club', description: '', rules: 'Be on time', currency: 'XAF', contributionAmount: 5000, frequency: 'monthly', membersLimit: 3, payoutOrderMethod: 'fixed', startDate: now, status: 'forming', adminIds: [ALICE], memberIds: [ALICE], currentCycle: 0, potAccountId: `tontine_${tid}`, createdBy: ALICE, createdAt: SERVER_TIME, updatedAt: SERVER_TIME }),
      create(`tontine_members/${tid}_${ALICE}`, { id: `${tid}_${ALICE}`, tontineId: tid, tontineName: 'Club', userId: ALICE, displayName: 'A', email: 'a@x.test', role: 'admin', status: 'active', payoutPosition: 1, joinedAt: SERVER_TIME, createdAt: SERVER_TIME }),
      create(`financial_accounts/tontine_${tid}`, { ...poolFields('tontine_pot', tid, 'XAF'), id: `tontine_${tid}`, balance: 0, normalSide: 'credit', status: 'active', createdAt: SERVER_TIME, updatedAt: SERVER_TIME }),
    ])));
    const t = await read(`tontines/${tid}`);
    const invite = (uid, by = ALICE) => create(`tontine_members/${tid}_${uid}`, { id: `${tid}_${uid}`, tontineId: tid, tontineName: 'Club', userId: uid, displayName: uid, email: '', role: 'member', status: 'invited', invitedBy: by, invitedByName: by, contributionAmount: 5000, currency: 'XAF', frequency: 'monthly', membersLimit: 3, startDate: t.startDate, rules: 'Be on time', payoutOrderMethod: 'fixed', invitedAt: SERVER_TIME, createdAt: SERVER_TIME });
    denied(await as(BOB).commit(batchOf([invite(CAROL, BOB)])), 'not an admin');
    denied(await as(ALICE).commit(batchOf(patch([invite(BOB)], `tontine_members/${tid}_${BOB}`, (d) => ({ ...d, contributionAmount: 1000 })))), 'terms differ from the tontine');
    allowed(await as(ALICE).commit(batchOf([invite(BOB)])));
    allowed(await as(ALICE).commit(batchOf([invite(CAROL)])));
    // the invitee reads its own invitation, not the tontine
    allowed(await as(BOB).get(`tontine_members/${tid}_${BOB}`));
    allowed(await as(BOB).query('tontine_members', { where: [['userId', '==', BOB], ['status', '==', 'invited']] }));
    denied(await as(BOB).get(`tontines/${tid}`));
    // someone else cannot accept Bob's invitation
    denied(await as(MALLORY).commit(batchOf([update(`tontine_members/${tid}_${BOB}`, { status: 'active', respondedAt: SERVER_TIME, joinedAt: SERVER_TIME }), update(`tontines/${tid}`, { memberIds: union(MALLORY), updatedAt: SERVER_TIME })])));
    const accept = (uid) => [update(`tontine_members/${tid}_${uid}`, { status: 'active', respondedAt: SERVER_TIME, joinedAt: SERVER_TIME }), update(`tontines/${tid}`, { memberIds: union(uid), updatedAt: SERVER_TIME })];
    allowed(await as(BOB).commit(batchOf(accept(BOB))));
    denied(await as(CAROL).commit(batchOf([accept(CAROL)[1]])), 'joining without an accepted invitation in the batch');
    allowed(await as(CAROL).commit(batchOf(accept(CAROL))));
    allowed(await as(ALICE).commit(batchOf([update(`tontine_members/${tid}_${BOB}`, { payoutPosition: 2 }), update(`tontine_members/${tid}_${CAROL}`, { payoutPosition: 3 })])));
    const start = [
      update(`tontines/${tid}`, { status: 'active', currentCycle: 1, nextDueAt: now, startedAt: SERVER_TIME, updatedAt: SERVER_TIME }),
      ...[ALICE, BOB, CAROL].map((uid, i) => create(`tontine_cycles/${tid}_${i + 1}`, { id: `${tid}_${i + 1}`, tontineId: tid, number: i + 1, dueDate: now, beneficiaryUserId: uid, expectedAmount: 15000, collectedAmount: 0, currency: 'XAF', status: i === 0 ? 'collecting' : 'upcoming', createdAt: SERVER_TIME })),
    ];
    denied(await as(BOB).commit(batchOf(start)), 'not an admin');
    denied(await as(ALICE).commit(batchOf(patch(start, `tontine_cycles/${tid}_1`, (d) => ({ ...d, expectedAmount: 99999 })))), 'a cycle with another pot');
    allowed(await as(ALICE).commit(batchOf(start)));
    denied(await as(ALICE).commit(batchOf([invite(DAVE)])), 'no invitation once started');
  });

  it('active members read the tontine and its records; a stranger does not', async () => {
    await seedActiveTontine();
    allowed(await as(CAROL).get(`tontines/${T}`));
    allowed(await as(CAROL).query('tontine_cycles', { where: [['tontineId', '==', T]], orderBy: [['number', 'asc']] }));
    allowed(await as(CAROL).query('tontine_members', { where: [['tontineId', '==', T]] }));
    denied(await as(MALLORY).get(`tontines/${T}`));
    denied(await as(MALLORY).query('tontine_cycles', { where: [['tontineId', '==', T]] }));
    denied(await as(MALLORY).get(`financial_accounts/tontine_${T}`));
  });

  it('a member contributes once per cycle; collectedAmount follows the posting; a stranger cannot', async () => {
    await seedActiveTontine();
    const c = await tontineContribution(ALICE, `${T}_1`);
    allowed(await as(ALICE).commit(batchOf(c.writes)));
    assert.equal((await read(`tontine_cycles/${T}_1`)).collectedAmount, 5000);
    // the same member, same cycle, again (create-only id)
    const again = await tontineContribution(ALICE, `${T}_1`);
    denied(await as(ALICE).commit(batchOf(again.writes)), 'second contribution to the same cycle');
    // collectedAmount moved by another amount
    const bob = await tontineContribution(BOB, `${T}_1`);
    denied(await as(BOB).commit(batchOf(patch(bob.writes, `tontine_cycles/${T}_1`, (d) => ({ ...d, collectedAmount: inc(10000) })))));
    denied(await as(BOB).commit(batchOf(without(bob.writes, `tontine_cycles/${T}_1`))), 'without the cycle counter');
    // a non-member
    await seed({ [`financial_accounts/${walletId(MALLORY)}`]: { id: walletId(MALLORY), kind: 'wallet', userId: MALLORY, currency: 'XAF', balance: 50000, normalSide: 'credit', status: 'active', lastTxId: '' } });
    denied(await as(MALLORY).commit(batchOf((await tontineContribution(MALLORY, `${T}_1`)).writes)));
    // another amount than the tontine's
    const odd = await tontineContribution(BOB, `${T}_1`);
    denied(await as(BOB).commit(batchOf(patch(odd.writes, `tontine_contributions/${T}_1_${BOB}`, (d) => ({ ...d, amount: 4000 })))));
    // a cycle that is not collecting
    denied(await as(BOB).commit(batchOf((await tontineContribution(BOB, `${T}_2`)).writes)), 'upcoming cycle');
    allowed(await as(BOB).commit(batchOf(bob.writes)));
  });

  it('the contribution that completes the pot (paid by a gateway: the heaviest batch) opens the payout', async () => {
    await seedActiveTontine();
    allowed(await as(ALICE).commit(batchOf((await tontineContribution(ALICE, `${T}_1`)).writes)));
    allowed(await as(BOB).commit(batchOf((await tontineContribution(BOB, `${T}_1`)).writes)));
    const last = await tontineContribution(CAROL, `${T}_1`, { funding: gateway('flutterwave', 'FLW-T1') });
    denied(await as(CAROL).commit(batchOf(without(last.writes, `tontine_payouts/${T}_1`).map((w) => (w.path === `tontine_cycles/${T}_1` ? { ...w, data: { collectedAmount: w.data.collectedAmount, lastTxId: w.data.lastTxId, updatedAt: SERVER_TIME } } : w)))), 'completing without moving to payout_pending');
    allowed(await as(CAROL).commit(batchOf(last.writes)));
    assert.equal((await read(`tontine_cycles/${T}_1`)).status, 'payout_pending');
    assert.equal((await read(`tontine_payouts/${T}_1`)).status, 'pending_approval');
    assert.equal((await read(`financial_accounts/tontine_${T}`)).balance, 15000);
  });

  it('a payout is approved by an admin who is not the beneficiary, once, to the beneficiary', async () => {
    await seedActiveTontine({ beneficiary1: BOB });
    for (const u of [ALICE, BOB, CAROL]) allowed(await as(u).commit(batchOf((await tontineContribution(u, `${T}_1`)).writes)));
    denied(await as(BOB).commit(batchOf(await approvePayout(BOB, 1))), 'the beneficiary (an admin) approves their own payout');
    denied(await as(CAROL).commit(batchOf(await approvePayout(CAROL, 1))), 'not an admin');
    // an admin redirecting the pot to themself
    const redirect = (await approvePayout(ALICE, 1)).map((w) => {
      if (w.path === `financial_accounts/${walletId(BOB)}`) return { ...w, path: `financial_accounts/${walletId(ALICE)}` };
      if (w.path.startsWith('ledger_transactions/')) return { ...w, data: { ...w.data, lines: [w.data.lines[0], { ...w.data.lines[1], accountId: walletId(ALICE) }], accountIds: [`tontine_${T}`, walletId(ALICE)], userIds: [ALICE] } };
      return w;
    });
    denied(await as(ALICE).commit(batchOf(redirect)), 'pot paid to the approver');
    allowed(await as(ALICE).commit(batchOf(await approvePayout(ALICE, 1))));
    assert.equal((await read(`financial_accounts/${walletId(BOB)}`)).balance, 50000 - 5000 + 15000);
    assert.equal((await read(`tontines/${T}`)).currentCycle, 2);
    assert.equal((await read(`tontine_cycles/${T}_2`)).status, 'collecting');
    // paid already: never twice
    denied(await as(ALICE).commit(batchOf(await approvePayout(ALICE, 1))));
  });

  it('only active members raise disputes', async () => {
    await seedActiveTontine();
    const d = (uid) => create(`tontine_disputes/${newKey()}`, { tontineId: T, raisedBy: uid, subject: 'Late', description: 'Cycle 1 is late', status: 'open', createdAt: SERVER_TIME });
    allowed(await as(CAROL).commit(batchOf([d(CAROL)])));
    denied(await as(MALLORY).commit(batchOf([d(MALLORY)])));
  });
});
