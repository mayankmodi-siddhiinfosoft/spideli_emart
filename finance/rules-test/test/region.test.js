// Spideli Finance per region (APP-SPEC-FINANCE-REGION-SETTINGS, 15 Oct
// 2026): the rules read finance_settings/{regionId}_{module}, never
// platform_settings; a new request names a region of the caller's
// users.regionIds that offers Finance, in one of its currencies; a record
// already made keeps its own region's settings.

import { describe, it, beforeEach } from 'node:test';
import {
  setUp, as, ALICE, BOB, REGION, OTHER_REGION, OFF_REGION, plan, batchOf, rawBatchOf, stamp, create, update, newKey,
  walletId, platformId, gateway, SERVER_TIME, WALLET, seed,
} from '../lib/fixtures.js';
import { allowed, denied } from '../lib/expect.js';

// FinanceWalletService.depositGateway (a plain deposit, or one that pays [purpose]).
function deposit(uid, amount, g, { purpose } = {}) {
  const opId = newKey();
  const p = plan({ type: 'deposit', from: platformId(), to: walletId(uid), amount, userIds: [uid], sourceKind: 'wallet_operations', sourceId: opId, createdBy: uid, funding: g });
  return [
    create(`wallet_operations/${opId}`, {
      id: opId, userId: uid, type: 'deposit', status: 'completed', currency: 'XAF', amount, fee: 0, total: amount,
      accountId: walletId(uid), gateway: g, txId: p.txId, reference: p.reference, ...(purpose ? { purpose } : {}),
      createdAt: SERVER_TIME, completedAt: SERVER_TIME,
    }),
    ...p.writes,
  ];
}

// TransferPlans.internal, 1% fee.
function transfer(from, to, amount) {
  const id = newKey();
  const fee = Math.round(amount / 100);
  const p = plan({ type: 'transfer', from: walletId(from), to: walletId(to), amount, fee, userIds: [from, to], sourceKind: 'money_transfers', sourceId: id, createdBy: from });
  return [
    create(`money_transfers/${id}`, {
      id, senderId: from, senderName: from, recipientId: to, participantIds: [from, to], channel: 'internal', recipient: { email: `${to}@example.test` },
      recipientName: to, recipientVerified: true, currency: 'XAF', amount, fee, total: amount + fee, receiveAmount: amount, funding: WALLET,
      createdAt: SERVER_TIME, status: 'completed', reference: p.reference, txId: p.txId, completedAt: SERVER_TIME,
    }),
    ...p.writes,
  ];
}

describe('finance regions', () => {
  beforeEach(setUp);

  it('a request names a region of the user that offers Finance', async () => {
    allowed(await as(ALICE).commit(batchOf(transfer(ALICE, BOB, 1000))), 'the user\'s region, Finance on');
    denied(await as(ALICE).commit(rawBatchOf(transfer(ALICE, BOB, 1000))), 'no regionId');
    denied(await as(ALICE).commit(rawBatchOf(stamp(transfer(ALICE, BOB, 1000), OFF_REGION))), 'a region of the user without Finance');
    denied(await as(ALICE).commit(rawBatchOf(stamp(transfer(ALICE, BOB, 1000), OTHER_REGION))), 'a region that is not the user\'s');
    await seed({ [`users/${ALICE}`]: { id: ALICE, role: 'customer', active: true, firstName: ALICE, email: `${ALICE}@example.test`, wallet_amount: 0, regionIds: [REGION, OTHER_REGION] } });
    denied(await as(ALICE).commit(rawBatchOf(stamp(transfer(ALICE, BOB, 1000), OTHER_REGION))), 'XAF is not a currency of that region (INR)');
  });

  it('the admin switching Finance off for the region stops new requests', async () => {
    await seed({ [`regions/${REGION}`]: { id: REGION, name: 'Yaounde', currencyId: 'cur_xaf', financeEnabled: false, publish: true } });
    denied(await as(ALICE).commit(batchOf(transfer(ALICE, BOB, 1000))));
    denied(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_off')))), 'a plain deposit');
  });

  it('the settings are the region\'s, never platform_settings', async () => {
    // platform_settings/wallet has deposits disabled: the region's settings apply.
    allowed(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_r1')))));
    await seed({ [`finance_settings/${REGION}_wallet`]: { regionId: REGION, module: 'wallet', currencies: ['XAF'], deposit: { enabled: false } } });
    denied(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_r2')))), 'the admin turned deposits off in the region');
    await seed({ [`finance_settings/${REGION}_transfers`]: { regionId: REGION, module: 'transfers', currencies: ['XAF'] } });
    denied(await as(ALICE).commit(batchOf(transfer(ALICE, BOB, 1000))), 'no internal channel in the region\'s settings');
  });

  it('a gateway deposit paying a request names the request\'s region', async () => {
    const purpose = { kind: 'money_transfers', id: 'tr1' };
    allowed(await as(ALICE).commit(batchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_p1'), { purpose }))));
    denied(await as(ALICE).commit(rawBatchOf(deposit(ALICE, 5000, gateway('stripe', 'pi_p2'), { purpose }))), 'without a regionId');
  });

  it('a posting may carry its regionId, never a malformed one', async () => {
    const w = transfer(ALICE, BOB, 1000);
    const noLedgerRegion = stamp(w).map((x) => (x.path.startsWith('ledger_transactions/') ? { ...x, data: Object.fromEntries(Object.entries(x.data).filter(([k]) => k !== 'regionId')) } : x));
    allowed(await as(ALICE).commit(rawBatchOf(noLedgerRegion)), 'the posting without regionId (the admin\'s postings have none)');
    const bad = stamp(transfer(ALICE, BOB, 1000)).map((x) => (x.path.startsWith('ledger_transactions/') ? { ...x, data: { ...x.data, regionId: 'a/b' } } : x));
    denied(await as(ALICE).commit(rawBatchOf(bad)));
  });

  it('a record keeps the settings of its own region', async () => {
    await seed({
      'savings_goals/g1': { id: 'g1', ownerId: ALICE, memberIds: [ALICE], invitedIds: [], name: 'Trip', purpose: 'travel', currency: 'XAF', targetAmount: 100000, savedAmount: 0, status: 'active', accountId: 'goal_g1', regionId: REGION },
      'savings_goals/g2': { id: 'g2', ownerId: ALICE, memberIds: [ALICE], invitedIds: [], name: 'Trip', purpose: 'travel', currency: 'XAF', targetAmount: 100000, savedAmount: 0, status: 'active', accountId: 'goal_g2', regionId: OTHER_REGION },
    });
    const edit = (id) => update(`savings_goals/${id}`, { name: 'Holiday', schedule: { frequency: 'monthly', amount: 5000 }, updatedAt: SERVER_TIME });
    allowed(await as(ALICE).commit(batchOf([edit('g1')])), 'its region allows a monthly schedule');
    denied(await as(ALICE).commit(batchOf([edit('g2')])), 'its region has no savings settings');
  });
});
