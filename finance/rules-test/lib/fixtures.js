// Shared set-up of the finance rules tests: the rules under test, the seed
// data, and a port of the app's ledger helper (customer/lib/service/
// finance_ledger.dart FinanceLedger.plan) so each test builds the batch the
// app builds, then breaks one thing.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { Batch, Client, SERVER_TIME, inc, seed, clear, loadRules, admin } from './firestore-rest.js';

export { Batch, Client, SERVER_TIME, inc, seed, clear, admin };
export { union, DELETE, ts, dbl } from './firestore-rest.js';

const here = dirname(fileURLToPath(import.meta.url));
export const RULES_FILE = resolve(here, '../../../firestore.rules.draft');

let loaded = false;
/** Loads firestore.rules.draft into the emulator (once per test file) and clears the data. */
export async function setUp() {
  if (!loaded) {
    await loadRules(readFileSync(RULES_FILE, 'utf8'));
    loaded = true;
  }
  await clear();
  await seed(baseDocs());
}

// ---- people --------------------------------------------------------------

export const ALICE = 'alice';
export const BOB = 'bob';
export const CAROL = 'carol';
export const DAVE = 'dave';
export const EVE = 'eve'; // restricted for loans
export const MALLORY = 'mallory'; // a stranger

/** A signed-in user; [authAgeSeconds]: how long ago they signed in (re-auth checks). */
export function as(uid, authAgeSeconds = 0) {
  return new Client(uid, { auth_time: Math.floor(Date.now() / 1000) - authAgeSeconds });
}
/** Signed in more than 5 minutes ago (no recent re-authentication). */
export function stale(uid) {
  return as(uid, 600);
}

export const day = 24 * 3600 * 1000;
export const later = (ms) => new Date(Date.now() + ms);

function user(uid, extra = {}) {
  return { id: uid, role: 'customer', active: true, firstName: uid, email: `${uid}@example.test`, wallet_amount: 0, ...extra };
}

export function walletDoc(uid, cur, balance) {
  return { id: `wallet_${uid}_${cur}`, kind: 'wallet', userId: uid, currency: cur, balance, normalSide: 'credit', status: 'active', lastTxId: '', createdAt: new Date(), updatedAt: new Date() };
}

export function baseDocs() {
  return {
    [`users/${ALICE}`]: user(ALICE),
    [`users/${BOB}`]: user(BOB),
    [`users/${CAROL}`]: user(CAROL),
    [`users/${DAVE}`]: user(DAVE),
    [`users/${EVE}`]: user(EVE, { financeRestriction: { status: 'restricted', reason: 'insolvency', since: new Date(), scopes: ['loans'] } }),
    [`users/${MALLORY}`]: user(MALLORY),

    'platform_settings/wallet': {
      currencies: ['XAF', 'EUR'],
      deposit: { enabled: true, min: { XAF: 100 }, max: { XAF: 5000000 } },
      withdraw: { enabled: true, methods: ['mobile_money', 'wave', 'bank'], min: { XAF: 500 }, max: { XAF: 1000000 }, feePercent: 1, feeFixed: { XAF: 0 }, feeMax: { XAF: 5000 } },
      convert: { enabled: true, currencies: ['XAF', 'EUR'], feePercent: 1, maxRateAgeHours: 48 },
      security: { reauthAbove: { XAF: 50000 } },
    },
    'platform_settings/transfers': {
      currencies: ['XAF'],
      sourceMethods: ['wallet', 'mobile_money'],
      security: { reauthAbove: { XAF: 50000 } },
      channels: {
        internal: { enabled: true, feePercent: 1, min: { XAF: 100 }, max: { XAF: 1000000 } },
        mobile_money: { enabled: true, operators: ['Orange Money'], feePercent: 1, feeFixed: { XAF: 0 }, feeMax: { XAF: 5000 }, min: { XAF: 500 }, max: { XAF: 500000 } },
      },
    },
    'platform_settings/bills': { currencies: ['XAF'], categories: ['electricity'], paymentMethods: ['wallet'], security: { reauthAbove: { XAF: 100000 } } },
    'platform_settings/savings': { purposes: ['travel', 'other'], currencies: ['XAF'], frequencies: ['monthly'], groupGoals: true, maxMembers: 5, earlyWithdrawal: { allowed: true }, paymentMethods: ['wallet'] },
    'platform_settings/tontines': { currencies: ['XAF'], frequencies: ['monthly'], minMembers: 2, maxMembers: 10, payoutOrderMethods: ['fixed', 'random'], paymentMethods: ['wallet'], minContribution: { XAF: 1000 } },
    'platform_settings/lending': {
      currencies: ['XAF'], minAmount: { XAF: 10000 }, maxAmount: { XAF: 1000000 }, durationsMonths: [3, 6], repaymentFrequencies: ['monthly'],
      purposes: ['business', 'other'], interest: { method: 'flat', annualPercent: 12 }, feePercent: 2, latePenaltyPercent: 5,
      voting: { quorumPercent: 50, approvalPercent: 60, durationHours: 48 }, paymentMethods: ['wallet'],
    },
    'platform_settings/cards': {
      currencies: ['XAF'], issuerName: 'Issuer', network: 'visa', maxCardsPerUser: 3, issuanceFee: { XAF: 1000 }, renewalFee: { XAF: 0 },
      fundingMethods: ['wallet'], minFunding: { XAF: 1000 }, maxFunding: { XAF: 500000 }, fundingFeePercent: 1.5,
      limits: { maxPerTransaction: { XAF: 300000 }, maxDaily: { XAF: 500000 }, maxMonthly: { XAF: 2000000 } },
      capabilities: { withdraw: true, renew: true, secureDetails: 'none' }, terms: 'Terms', termsVersion: 2,
    },
    'platform_settings/kyc': {
      documentTypes: { national_id: { sides: ['front', 'back'] }, selfie: { sides: ['front'] } },
      levels: { basic: { accountTypes: ['individual'], requiredDocuments: [{ anyOf: ['national_id'] }] } },
      allowedContentTypes: ['image/jpeg', 'application/pdf'], maxFileBytes: 10485760,
    },

    // Accounts: the platform's (admin-made) and two wallets.
    'financial_accounts/platform_XAF': { id: 'platform_XAF', kind: 'platform', currency: 'XAF', balance: 0, normalSide: 'credit', status: 'active', lastTxId: '' },
    'financial_accounts/platform_EUR': { id: 'platform_EUR', kind: 'platform', currency: 'EUR', balance: 0, normalSide: 'credit', status: 'active', lastTxId: '' },
    [`financial_accounts/wallet_${ALICE}_XAF`]: walletDoc(ALICE, 'XAF', 100000),
    [`financial_accounts/wallet_${BOB}_XAF`]: walletDoc(BOB, 'XAF', 50000),
    [`financial_accounts/wallet_${CAROL}_XAF`]: walletDoc(CAROL, 'XAF', 50000),
    [`financial_accounts/wallet_${DAVE}_XAF`]: walletDoc(DAVE, 'XAF', 50000),

    // Published / unpublished catalog entries.
    'market_securities/pub': { published: true, name: 'SONATEL', price: 1 },
    'market_securities/draft': { published: false, name: 'DRAFT', price: 1 },
    'exchange_rate_snapshots/eur_xaf': { from: 'EUR', to: 'XAF', pair: 'EUR_XAF', rate: 655.957, source: 'BEAC', kind: 'official', observedAt: new Date() },
  };
}

// ---- the ledger helper, as the app writes it -------------------------------

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const code = (n) => Array.from({ length: n }, () => ALPHABET[Math.floor(Math.random() * ALPHABET.length)]).join('');
export const newTxId = () => `tx_${Date.now()}_${code(8)}`;
export const newRef = () => `SPF-261014-${code(6)}`;
export const newKey = () => `${Date.now()}-${code(12).toLowerCase()}`;

export const walletId = (uid, cur = 'XAF') => `wallet_${uid}_${cur}`;
export const platformId = (cur = 'XAF') => `platform_${cur}`;
export const walletFields = (uid, cur) => ({ kind: 'wallet', userId: uid, currency: cur });
export const poolFields = (kind, refId, cur, memberIds) => ({ kind, refId, currency: cur, ...(memberIds ? { memberIds } : {}) });

/** FinanceFunding: wallet, or a gateway payment. */
export const WALLET = { method: 'wallet' };
export const gateway = (method = 'stripe', reference = `pi_${code(10)}`) => ({ method, reference });
export const receiptIdOf = (g) => `${g.method}_${g.reference.replace(/\//g, '_')}`;

/**
 * FinanceLedger.plan: the writes [{path, op, data}] of a posting of [amount]
 * from [from] to [to] (+ [fee] to the platform from a non-platform account).
 */
export function plan({ type, currency = 'XAF', from, to, amount, fee = 0, newAccounts = {}, userIds, sourceKind, sourceId, createdBy, funding = WALLET, description = '', txId, reference }) {
  const id = txId || newTxId();
  const ref = reference || newRef();
  const platform = platformId(currency);
  const feeLine = fee > 0 && from !== platform && to !== platform;
  const debit = amount + (feeLine ? fee : 0);
  const lines = [
    { accountId: from, direction: 'debit', amount: debit },
    { accountId: to, direction: 'credit', amount },
    ...(feeLine ? [{ accountId: platform, direction: 'credit', amount: fee }] : []),
  ];
  const isWallet = funding.method === 'wallet';
  const writes = [
    {
      path: `ledger_transactions/${id}`,
      op: 'create',
      data: {
        id, type, status: 'posted', reference: ref, currency, lines,
        userIds: [...new Set(userIds)], accountIds: lines.map((l) => l.accountId),
        source: { kind: sourceKind, id: sourceId }, funding: isWallet ? 'wallet' : 'gateway',
        ...(isWallet ? {} : { gateway: { method: funding.method, reference: funding.reference } }),
        description, createdBy, createdAt: SERVER_TIME,
      },
    },
  ];
  for (const l of lines) {
    const delta = l.direction === 'debit' ? -l.amount : l.amount;
    const create = newAccounts[l.accountId];
    if (create) {
      writes.push({ path: `financial_accounts/${l.accountId}`, op: 'create', data: { ...create, id: l.accountId, currency, balance: delta, normalSide: 'credit', status: 'active', lastTxId: id, createdAt: SERVER_TIME, updatedAt: SERVER_TIME } });
    } else {
      writes.push({ path: `financial_accounts/${l.accountId}`, op: 'update', data: { balance: inc(delta), lastTxId: id, updatedAt: SERVER_TIME } });
    }
  }
  if (!isWallet) {
    writes.push({
      path: `payment_receipts/${receiptIdOf(funding)}`,
      op: 'create',
      data: { method: funding.method, reference: funding.reference, txId: id, amount: amount + fee, currency, userId: createdBy, verified: false, createdAt: SERVER_TIME },
    });
  }
  return { txId: id, reference: ref, writes };
}

/** The writes as a batch (create = set, update = update, merge = set merge). */
export function batchOf(...groups) {
  const b = new Batch();
  for (const w of groups.flat()) {
    if (w.op === 'create') b.set(w.path, w.data);
    else if (w.op === 'update') b.update(w.path, w.data);
    else if (w.op === 'merge') b.merge(w.path, w.data);
    else if (w.op === 'delete') b.delete(w.path);
    else throw new Error(`unknown op ${w.op}`);
  }
  return b;
}

export const create = (path, data) => ({ path, op: 'create', data });
export const update = (path, data) => ({ path, op: 'update', data });
export const merge = (path, data) => ({ path, op: 'merge', data });

/** Replaces the data of the write at [path] (a test breaking one thing). */
export function patch(writes, path, fn) {
  return writes.map((w) => (w.path === path ? { ...w, data: fn(structuredCloneSafe(w.data)) } : w));
}
export function without(writes, path) {
  return writes.filter((w) => w.path !== path);
}
function structuredCloneSafe(d) {
  // Sentinels (symbols / marker objects) survive a shallow copy of each level.
  if (Array.isArray(d)) return d.map(structuredCloneSafe);
  if (d && typeof d === 'object' && !(d instanceof Date) && d.__inc === undefined && d.__union === undefined && d.__ts === undefined && d.__double === undefined) {
    const out = {};
    for (const [k, v] of Object.entries(d)) out[k] = structuredCloneSafe(v);
    return out;
  }
  return d;
}

/** The current data of [path] (rules bypassed). */
export async function read(path) {
  return (await admin.get(path)).data;
}
