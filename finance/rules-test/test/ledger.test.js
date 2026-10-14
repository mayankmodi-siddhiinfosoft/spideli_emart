// The ledger core: deposits through a gateway (receipts), internal and
// external transfers, withdrawals, conversions, bills, replay and direct
// balance edits, and who reads accounts / postings / transfers.

import { describe, it, beforeEach } from 'node:test';
import {
  setUp, as, stale, ALICE, BOB, CAROL, MALLORY, plan, batchOf, create, update, patch, without, read, newKey, newRef,
  walletId, platformId, walletFields, gateway, receiptIdOf, SERVER_TIME, inc, WALLET, seed,
} from '../lib/fixtures.js';
import { allowed, denied, assert } from '../lib/expect.js';

// FinanceWalletService.deposit -> WalletRules.depositWrites
function deposit(uid, amount, g, { cur = 'XAF', walletExists = true, opId = newKey(), purpose } = {}) {
  const p = plan({
    type: 'deposit', currency: cur, from: platformId(cur), to: walletId(uid, cur), amount,
    newAccounts: walletExists ? {} : { [walletId(uid, cur)]: walletFields(uid, cur) },
    userIds: [uid], sourceKind: 'wallet_operations', sourceId: opId, createdBy: uid, funding: g,
  });
  return [
    create(`wallet_operations/${opId}`, {
      id: opId, userId: uid, type: 'deposit', status: 'completed', currency: cur, amount, fee: 0, total: amount,
      accountId: walletId(uid, cur), gateway: g, txId: p.txId, reference: p.reference,
      ...(purpose ? { purpose } : {}), createdAt: SERVER_TIME, completedAt: SERVER_TIME,
    }),
    ...p.writes,
  ];
}

// TransferPlans.internal: always from the sender's wallet ([funding] only
// records how it was paid: a gateway payment is deposited first).
function internalTransfer(from, to, amount, fee, { funding = WALLET, fromAccount = walletId(from), toWalletExists = true, id = newKey() } = {}) {
  const p = plan({
    type: 'transfer', from: fromAccount, to: walletId(to), amount, fee,
    newAccounts: toWalletExists ? {} : { [walletId(to)]: walletFields(to, 'XAF') },
    userIds: [from, to], sourceKind: 'money_transfers', sourceId: id, createdBy: from,
  });
  return {
    id, txId: p.txId,
    writes: [
      create(`money_transfers/${id}`, {
        id, senderId: from, senderName: from, recipientId: to, participantIds: [from, to], channel: 'internal',
        recipient: { email: `${to}@example.test` }, recipientName: to, recipientVerified: true, currency: 'XAF',
        amount, fee, total: amount + fee, receiveAmount: amount, funding: funding.method === 'wallet' ? WALLET : funding,
        createdAt: SERVER_TIME, status: 'completed', reference: p.reference, txId: p.txId, completedAt: SERVER_TIME,
      }),
      ...p.writes,
    ],
  };
}

// WalletRules.withdrawWrites
function withdrawal(uid, amount, fee, { method = 'mobile_money' } = {}) {
  const opId = newKey();
  const p = plan({ type: 'withdrawal', from: walletId(uid), to: platformId(), amount: amount + fee, userIds: [uid], sourceKind: 'wallet_operations', sourceId: opId, createdBy: uid });
  return [create(`wallet_operations/${opId}`, { id: opId, userId: uid, type: 'withdrawal', status: 'pending', currency: 'XAF', amount, fee, total: amount + fee, accountId: walletId(uid), destination: { method, operator: 'Orange Money', number: '+237600000000' }, txId: p.txId, reference: p.reference, createdAt: SERVER_TIME }), ...p.writes];
}

describe('ledger core', () => {
  beforeEach(setUp);

  describe('wallet deposit through a gateway', () => {
    it('is allowed with its payment receipt, and moves exactly the amount', async () => {
      allowed(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_1')))));
      assert.equal((await read(`financial_accounts/${walletId(ALICE)}`)).balance, 105000);
      assert.equal((await read('financial_accounts/platform_XAF')).balance, -5000);
      assert.equal((await read('payment_receipts/stripe_pi_1')).verified, false);
    });

    it('is denied when the gateway payment was already used (receipt reused)', async () => {
      allowed(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_2')))));
      denied(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_2')))), 'second deposit, same gateway reference');
      denied(await as(BOB).commit(batchOf(deposit(BOB, 5000, gateway('stripe', 'pi_2')))), 'another user, same gateway reference');
    });

    it('is denied without a receipt', async () => {
      const w = deposit(ALICE, 5000, gateway('stripe', 'pi_3'));
      denied(await as(ALICE).commit(batchOf(without(w, 'payment_receipts/stripe_pi_3'))));
    });

    it('is denied when the receipt names another posting, or a lower amount', async () => {
      const w = deposit(ALICE, 5000, gateway('stripe', 'pi_4'));
      denied(await as(ALICE).commit(batchOf(patch(w, 'payment_receipts/stripe_pi_4', (d) => ({ ...d, txId: 'tx_1700000000000_AAAAAAAA' })))));
      denied(await as(ALICE).commit(batchOf(patch(w, 'payment_receipts/stripe_pi_4', (d) => ({ ...d, amount: 10 })))));
    });

    it('creates the wallet with its first credit; never someone else\'s wallet from a deposit', async () => {
      allowed(await as(CAROL).commit(batchOf(deposit(CAROL, 2000, gateway('paypal', 'PAY-1'), { cur: 'EUR', walletExists: false }))));
      assert.equal((await read(`financial_accounts/${walletId(CAROL, 'EUR')}`)).balance, 2000);
      // Alice "deposits" into Bob's wallet.
      const opId = newKey();
      const p = plan({ type: 'deposit', from: platformId(), to: walletId(BOB), amount: 1000, userIds: [BOB, ALICE], sourceKind: 'wallet_operations', sourceId: opId, createdBy: ALICE, funding: gateway('stripe', 'pi_5') });
      const op = create(`wallet_operations/${opId}`, { id: opId, userId: ALICE, type: 'deposit', status: 'completed', currency: 'XAF', amount: 1000, gateway: gateway('stripe', 'pi_5'), txId: p.txId, reference: p.reference, createdAt: SERVER_TIME });
      denied(await as(ALICE).commit(batchOf([op, ...p.writes])));
    });

    it('is denied above the deposit maximum (a plain deposit)', async () => {
      denied(await as(ALICE).commit(batchOf(deposit(ALICE, 6000000, gateway('stripe', 'pi_6')))));
    });

    it('a gateway payment of a request (purpose) is a deposit too', async () => {
      allowed(await as(ALICE).commit(batchOf(deposit(ALICE, 3000, gateway('orange_money', 'OM/42'), { opId: 'orange_money_OM_42', purpose: { kind: 'virtual_cards', id: 'k1' } }))));
      assert.ok(await read('payment_receipts/orange_money_OM_42'));
    });
  });

  describe('internal transfer', () => {
    it('is allowed: sender -amount-fee, recipient +amount, platform +fee', async () => {
      const t = internalTransfer(ALICE, BOB, 10000, 100);
      allowed(await as(ALICE).commit(batchOf(t.writes)));
      assert.equal((await read(`financial_accounts/${walletId(ALICE)}`)).balance, 89900);
      assert.equal((await read(`financial_accounts/${walletId(BOB)}`)).balance, 60000);
      assert.equal((await read('financial_accounts/platform_XAF')).balance, 100);
    });

    it('creates the recipient\'s wallet when missing', async () => {
      const t = internalTransfer(ALICE, MALLORY, 1000, 10, { toWalletExists: false });
      allowed(await as(ALICE).commit(batchOf(t.writes)));
      assert.equal((await read(`financial_accounts/${walletId(MALLORY)}`)).balance, 1000);
    });

    it('is denied as an overdraft', async () => {
      const t = internalTransfer(ALICE, BOB, 150000, 1500);
      denied(await as(ALICE).commit(batchOf(t.writes)), 'wallet would go below 0 (re-authenticated)');
    });

    it('is denied debiting someone else\'s wallet', async () => {
      // Alice sends Bob's money to Carol (userIds made consistent, so only
      // the debit authorization can refuse it; the same batch from her own
      // wallet is allowed).
      const t = internalTransfer(ALICE, CAROL, 1000, 10, { fromAccount: walletId(BOB) });
      const ok = internalTransfer(ALICE, CAROL, 1000, 10);
      denied(await as(ALICE).commit(batchOf(patch(t.writes, `ledger_transactions/${t.txId}`, (d) => ({ ...d, userIds: [BOB, CAROL, ALICE] })))));
      allowed(await as(ALICE).commit(batchOf(ok.writes)));
      // Alice credits herself from Bob's wallet.
      const id = newKey();
      const p = plan({ type: 'transfer', from: walletId(BOB), to: walletId(ALICE), amount: 1000, fee: 10, userIds: [BOB, ALICE], sourceKind: 'money_transfers', sourceId: id, createdBy: ALICE });
      const rec = create(`money_transfers/${id}`, { id, senderId: BOB, recipientId: ALICE, participantIds: [BOB, ALICE], channel: 'internal', recipient: {}, recipientVerified: true, currency: 'XAF', amount: 1000, fee: 10, total: 1010, receiveAmount: 1000, funding: WALLET, createdAt: SERVER_TIME, status: 'completed', reference: p.reference, txId: p.txId, completedAt: SERVER_TIME });
      denied(await as(ALICE).commit(batchOf([rec, ...p.writes])));
    });

    it('is denied with wrong line amounts or balance changes', async () => {
      const t = internalTransfer(ALICE, BOB, 10000, 100);
      const tx = `ledger_transactions/${t.txId}`;
      // Lines that do not balance (debit 10100, credits 10000 + 50).
      denied(await as(ALICE).commit(batchOf(patch(t.writes, tx, (d) => ({ ...d, lines: [d.lines[0], d.lines[1], { ...d.lines[2], amount: 50 }] })))));
      // Bob's wallet credited more than its line.
      denied(await as(ALICE).commit(batchOf(patch(t.writes, `financial_accounts/${walletId(BOB)}`, (d) => ({ ...d, balance: inc(20000) })))));
      // The sender debited less than its line.
      denied(await as(ALICE).commit(batchOf(patch(t.writes, `financial_accounts/${walletId(ALICE)}`, (d) => ({ ...d, balance: inc(-100) })))));
      // A line's account not written in the batch.
      denied(await as(ALICE).commit(batchOf(without(t.writes, 'financial_accounts/platform_XAF'))));
      // A negative / zero amount.
      denied(await as(ALICE).commit(batchOf(patch(t.writes, tx, (d) => ({ ...d, lines: [{ ...d.lines[0], amount: 0 }, { ...d.lines[1], amount: -100 }, { ...d.lines[2], amount: 100 }] })))));
    });

    it('is denied with a fee below the configured fee, or a record that does not match its posting', async () => {
      const t = internalTransfer(ALICE, BOB, 10000, 0);
      denied(await as(ALICE).commit(batchOf(t.writes)), 'fee 0 where 1% is due');
      const t2 = internalTransfer(ALICE, BOB, 10000, 100);
      denied(await as(ALICE).commit(batchOf(patch(t2.writes, `money_transfers/${t2.id}`, (d) => ({ ...d, recipientId: CAROL, participantIds: [ALICE, CAROL] })))), 'record names another recipient');
      denied(await as(ALICE).commit(batchOf(without(t2.writes, `money_transfers/${t2.id}`))), 'posting without its request');
    });

    it('needs a recent re-authentication above security.reauthAbove', async () => {
      const t = internalTransfer(ALICE, BOB, 60000, 600);
      denied(await stale(ALICE).commit(batchOf(t.writes)));
      allowed(await as(ALICE).commit(batchOf(t.writes)));
    });

    it('paid by a gateway: deposited into the sender\'s wallet first, then the wallet transfer; never platform -> recipient', async () => {
      const g = gateway('stripe', 'pi_t1');
      allowed(await as(ALICE).commit(batchOf(deposit(ALICE, 5050, g, { opId: receiptIdOf(g), purpose: { kind: 'money_transfers', id: 'k' } }))));
      const t = internalTransfer(ALICE, BOB, 5000, 50, { funding: g });
      allowed(await as(ALICE).commit(batchOf(t.writes)));
      assert.equal((await read(`financial_accounts/${walletId(BOB)}`)).balance, 55000);
      assert.equal((await read(`financial_accounts/${walletId(ALICE)}`)).balance, 100000);
      // the platform paying the recipient directly, with a fresh receipt
      const id = newKey();
      const g2 = gateway('stripe', 'pi_t2');
      const p = plan({ type: 'transfer', from: platformId(), to: walletId(BOB), amount: 5000, userIds: [BOB], sourceKind: 'money_transfers', sourceId: id, createdBy: ALICE, funding: g2 });
      const rec = create(`money_transfers/${id}`, { id, senderId: ALICE, recipientId: BOB, participantIds: [ALICE, BOB], channel: 'internal', recipient: {}, recipientVerified: true, currency: 'XAF', amount: 5000, fee: 50, total: 5050, receiveAmount: 5000, funding: g2, createdAt: SERVER_TIME, status: 'completed', reference: p.reference, txId: p.txId, completedAt: SERVER_TIME });
      denied(await as(ALICE).commit(batchOf([rec, ...p.writes])));
    });
  });

  describe('replay and direct balance edits', () => {
    it('an old posting cannot be applied again', async () => {
      const t = internalTransfer(ALICE, BOB, 1000, 10);
      allowed(await as(ALICE).commit(batchOf(t.writes)));
      const replay = update(`financial_accounts/${walletId(BOB)}`, { balance: inc(1000), lastTxId: t.txId, updatedAt: SERVER_TIME });
      denied(await as(BOB).commit(batchOf([replay])), 'same posting applied to the account again');
    });

    it('nobody edits a balance without a posting, deletes an account, or rewrites a posting', async () => {
      denied(await as(ALICE).commit(batchOf([update(`financial_accounts/${walletId(ALICE)}`, { balance: inc(1000000), lastTxId: '', updatedAt: SERVER_TIME })])));
      denied(await as(ALICE).commit(batchOf([update(`financial_accounts/${walletId(ALICE)}`, { status: 'active', kind: 'platform' })])));
      denied(await as(ALICE).commit(batchOf([{ path: `financial_accounts/${walletId(ALICE)}`, op: 'delete' }])));
      const t = internalTransfer(ALICE, BOB, 1000, 10);
      allowed(await as(ALICE).commit(batchOf(t.writes)));
      denied(await as(ALICE).commit(batchOf([update(`ledger_transactions/${t.txId}`, { status: 'reversed' })])));
      denied(await as(ALICE).commit(batchOf([{ path: `ledger_transactions/${t.txId}`, op: 'delete' }])));
    });

    it('a frozen account (status not active) cannot move', async () => {
      await seed({ [`financial_accounts/${walletId(ALICE)}`]: { id: walletId(ALICE), kind: 'wallet', userId: ALICE, currency: 'XAF', balance: 100000, normalSide: 'credit', status: 'frozen', lastTxId: '' } });
      denied(await as(ALICE).commit(batchOf(internalTransfer(ALICE, BOB, 1000, 10).writes)));
    });

    it('nobody posts an admin-only type (reversal)', async () => {
      const id = newKey();
      const p = plan({ type: 'reversal', from: platformId(), to: walletId(ALICE), amount: 1000, userIds: [ALICE], sourceKind: 'money_transfers', sourceId: id, createdBy: ALICE });
      denied(await as(ALICE).commit(batchOf(p.writes)));
    });
  });

  describe('withdrawal, external transfer, bill, conversion', () => {

    it('a withdrawal debits amount + fee; refused with a low fee, a method not offered, or stale auth above the threshold', async () => {
      allowed(await as(ALICE).commit(batchOf(withdrawal(ALICE, 10000, 100))));
      assert.equal((await read(`financial_accounts/${walletId(ALICE)}`)).balance, 89900);
      denied(await as(ALICE).commit(batchOf(withdrawal(ALICE, 10000, 0))), 'fee below 1%');
      denied(await as(ALICE).commit(batchOf(withdrawal(ALICE, 10000, 100, { method: 'crypto' }))), 'method not offered');
      denied(await stale(ALICE).commit(batchOf(withdrawal(ALICE, 60000, 600))), 'above reauthAbove without re-auth');
      allowed(await as(ALICE).commit(batchOf(withdrawal(ALICE, 60000, 600))), 'above reauthAbove, re-authenticated');
    });

    it('an external transfer: the total leaves the wallet for the platform; a request without its posting, or a bare receipt, is refused', async () => {
      const id = newKey();
      const p = plan({ type: 'transfer_out', from: walletId(ALICE), to: platformId(), amount: 10100, userIds: [ALICE], sourceKind: 'money_transfers', sourceId: id, createdBy: ALICE });
      const rec = create(`money_transfers/${id}`, { id, senderId: ALICE, senderName: 'A', participantIds: [ALICE], channel: 'mobile_money', recipient: { operator: 'Orange Money', number: '+237611111111' }, recipientName: 'X', recipientVerified: false, currency: 'XAF', amount: 10000, fee: 100, total: 10100, receiveAmount: 10000, funding: WALLET, createdAt: SERVER_TIME, status: 'processing', reference: p.reference, txId: p.txId });
      denied(await as(ALICE).commit(batchOf([rec])), 'without its posting');
      denied(await as(ALICE).commit(batchOf(patch([rec, ...p.writes], `ledger_transactions/${p.txId}`, (d) => ({ ...d, lines: [{ ...d.lines[0], amount: 10000 }, { ...d.lines[1], amount: 10000 }] })).map((w) => (w.path.startsWith('financial_accounts/') ? { ...w, data: { ...w.data, balance: inc(w.path.includes('platform') ? 10000 : -10000) } } : w)))), 'the fee not paid');
      allowed(await as(ALICE).commit(batchOf([rec, ...p.writes])));
      assert.equal((await read(`financial_accounts/${walletId(ALICE)}`)).balance, 89900);
      // cancel request: the sender, once, before the admin takes it
      const cancel = update(`money_transfers/${id}`, { cancelRequested: true, cancelRequestedAt: SERVER_TIME });
      denied(await as(BOB).commit(batchOf([cancel])));
      allowed(await as(ALICE).commit(batchOf([cancel])));
      denied(await as(ALICE).commit(batchOf([update(`money_transfers/${id}`, { status: 'cancelled' })])), 'cancelling itself');
      // a receipt that names no posting (paying a request directly)
      const g = gateway('flutterwave', 'FLW-9');
      denied(await as(ALICE).commit(batchOf([create(`payment_receipts/${receiptIdOf(g)}`, { method: g.method, reference: g.reference, txId: null, amount: 10100, currency: 'XAF', userId: ALICE, verified: false, createdAt: SERVER_TIME })])));
    });

    it('restricted users (scopes transfers / payments / wallet, or all) are refused those operations', async () => {
      await seed({
        [`users/${ALICE}`]: { role: 'customer', active: true, financeRestriction: { status: 'restricted', scopes: ['transfers', 'wallet'] } },
        [`users/${BOB}`]: { role: 'customer', active: true, financeRestriction: { status: 'restricted', scopes: ['all'] } },
      });
      denied(await as(ALICE).commit(batchOf(internalTransfer(ALICE, CAROL, 1000, 10).writes)), 'transfers');
      denied(await as(BOB).commit(batchOf(internalTransfer(BOB, CAROL, 1000, 10).writes)), 'all');
      denied(await as(ALICE).commit(batchOf(withdrawal(ALICE, 10000, 100))), 'wallet');
      denied(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_rs')))), 'wallet: add money');
      allowed(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_rs2'), { opId: 'stripe_pi_rs2', purpose: { kind: 'tontine_contributions', id: 'x' } }))), 'the gateway step of an obligation');
      allowed(await as(CAROL).commit(batchOf(internalTransfer(CAROL, ALICE, 1000, 10).writes)), 'receiving is never blocked');
    });

    it('a bill paid from the wallet', async () => {
      await seed({ 'utility_billers/eneo': { published: true, name: 'ENEO', category: 'electricity', currency: 'XAF', amountType: 'open', min: 500, max: 500000, feePercent: 0, feeFixed: 100 } });
      const id = newKey();
      const p = plan({ type: 'bill_payment', from: walletId(ALICE), to: platformId(), amount: 5100, userIds: [ALICE], sourceKind: 'utility_payment_requests', sourceId: id, createdBy: ALICE });
      const rec = create(`utility_payment_requests/${id}`, { id, userId: ALICE, billerId: 'eneo', billerName: 'ENEO', category: 'electricity', account: '123456', currency: 'XAF', amount: 5000, fee: 100, total: 5100, status: 'processing', reference: p.reference, txId: p.txId, funding: WALLET, createdAt: SERVER_TIME });
      allowed(await as(ALICE).commit(batchOf([rec, ...p.writes])));
      const id2 = newKey();
      const p2 = plan({ type: 'bill_payment', from: walletId(ALICE), to: platformId(), amount: 5000, userIds: [ALICE], sourceKind: 'utility_payment_requests', sourceId: id2, createdBy: ALICE });
      denied(await as(ALICE).commit(batchOf([{ ...rec, path: `utility_payment_requests/${id2}`, data: { ...rec.data, id: id2, fee: 0, total: 5000, txId: p2.txId } }, ...p2.writes])), 'biller fee skipped');
    });

    function conversion(uid, amount, receive, { snapshot = 'eur_xaf' } = {}) {
      const opId = newKey();
      const tx = `tx_${opId.replace('-', '_')}`;
      const out = plan({ type: 'conversion', currency: 'XAF', from: walletId(uid, 'XAF'), to: platformId('XAF'), amount, userIds: [uid], sourceKind: 'wallet_operations', sourceId: opId, createdBy: uid, txId: tx });
      const into = plan({ type: 'conversion', currency: 'EUR', from: platformId('EUR'), to: walletId(uid, 'EUR'), amount: receive, newAccounts: { [walletId(uid, 'EUR')]: walletFields(uid, 'EUR') }, userIds: [uid], sourceKind: 'wallet_operations', sourceId: opId, createdBy: uid, txId: `${tx}b` });
      const fee = Math.round(amount * 1 / 100);
      return [
        create(`wallet_operations/${opId}`, { id: opId, userId: uid, type: 'conversion', status: 'completed', currency: 'XAF', amount, fee, total: amount, accountId: walletId(uid, 'XAF'), toCurrency: 'EUR', toAccountId: walletId(uid, 'EUR'), rate: 1 / 655.957, rateSource: 'BEAC', rateObservedAt: new Date(), rateSnapshotId: snapshot, receiveAmount: receive, txId: out.txId, txIds: [out.txId, into.txId], reference: out.reference, createdAt: SERVER_TIME, completedAt: SERVER_TIME }),
        ...out.writes,
        ...into.writes,
      ];
    }

    it('a conversion at the published rate (inverse pair, minor units) is allowed; a better rate is not', async () => {
      // 100000 XAF, fee 1000: 99000 / 655.957 EUR = 150.92 EUR = 15092 cents.
      allowed(await as(ALICE).commit(batchOf(conversion(ALICE, 100000, 15092))));
      assert.equal((await read(`financial_accounts/${walletId(ALICE, 'EUR')}`)).balance, 15092);
      assert.equal((await read(`financial_accounts/${walletId(ALICE, 'XAF')}`)).balance, 0);
    });

    it('a conversion receiving more than the rate allows, or without a published rate, is denied', async () => {
      denied(await as(ALICE).commit(batchOf(conversion(ALICE, 100000, 16000))));
      denied(await as(ALICE).commit(batchOf(conversion(ALICE, 100000, 15092, { snapshot: 'missing' }))));
    });
  });

  describe('reads', () => {
    it('accounts: own wallet yes, someone else\'s no, a missing one reads as missing; lists of own accounts only', async () => {
      allowed(await as(ALICE).get(`financial_accounts/${walletId(ALICE)}`));
      denied(await as(MALLORY).get(`financial_accounts/${walletId(ALICE)}`));
      assert.equal((await as(MALLORY).get(`financial_accounts/${walletId(ALICE, 'USD')}`)).status, 404);
      allowed(await as(ALICE).query('financial_accounts', { where: [['userId', '==', ALICE]] }));
      denied(await as(MALLORY).query('financial_accounts', { where: [['userId', '==', ALICE]] }));
      denied(await as(MALLORY).query('financial_accounts', {}));
    });

    it('postings: the users of a posting, never a stranger; transfers: their participants', async () => {
      const t = internalTransfer(ALICE, BOB, 1000, 10);
      allowed(await as(ALICE).commit(batchOf(t.writes)));
      allowed(await as(BOB).get(`ledger_transactions/${t.txId}`));
      denied(await as(MALLORY).get(`ledger_transactions/${t.txId}`));
      const q = await as(ALICE).query('ledger_transactions', { where: [['userIds', 'array-contains', ALICE]], orderBy: [['createdAt', 'desc']] });
      allowed(q);
      assert.equal(q.docs.length, 1);
      denied(await as(MALLORY).query('ledger_transactions', { where: [['userIds', 'array-contains', ALICE]] }));
      allowed(await as(BOB).get(`money_transfers/${t.id}`));
      denied(await as(MALLORY).get(`money_transfers/${t.id}`));
      allowed(await as(BOB).query('money_transfers', { where: [['participantIds', 'array-contains', BOB]] }));
    });

    it('receipts: their payer only', async () => {
      allowed(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_r')))));
      allowed(await as(ALICE).get('payment_receipts/stripe_pi_r'));
      denied(await as(MALLORY).get('payment_receipts/stripe_pi_r'));
    });
  });
});
