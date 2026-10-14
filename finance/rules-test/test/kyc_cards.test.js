// Identity verification (the customer never approves) and virtual cards
// (requests, freeze / unfreeze, re-authenticated steps).

import { describe, it, beforeEach } from 'node:test';
import {
  setUp, as, stale, ALICE, BOB, MALLORY, plan, batchOf, create, update, patch, read, newKey, walletId, platformId, SERVER_TIME, seed, DELETE,
} from '../lib/fixtures.js';
import { allowed, denied, assert } from '../lib/expect.js';

const APP = 'app1';

function kycApplication(uid = ALICE, extra = {}) {
  return create(`kyc_applications/${APP}`, { id: APP, userId: uid, level: 'basic', accountType: 'individual', status: 'draft', revision: 1, personal: {}, reason: null, createdAt: SERVER_TIME, updatedAt: SERVER_TIME, ...extra });
}

const review = (action, uid = ALICE) => create(`kyc_reviews/${newKey()}`, { applicationId: APP, userId: uid, action, reason: null, at: SERVER_TIME });

describe('identity verification (KYC)', () => {
  beforeEach(setUp);

  it('the owner creates a draft; never another status, revision or level', async () => {
    allowed(await as(ALICE).commit(batchOf([kycApplication()])));
    await setUp();
    denied(await as(ALICE).commit(batchOf([kycApplication(ALICE, { status: 'approved' })])));
    denied(await as(ALICE).commit(batchOf([kycApplication(ALICE, { level: 'premium' })])), 'a level that is not offered');
    denied(await as(MALLORY).commit(batchOf([kycApplication(ALICE)])), 'for someone else');
  });

  it('details while draft; documents under kyc/{uid}/{app}/; submit with its history entry', async () => {
    allowed(await as(ALICE).commit(batchOf([kycApplication()])));
    allowed(await as(ALICE).commit(batchOf([update(`kyc_applications/${APP}`, { personal: { fullName: 'Alice A', country: 'CM' }, updatedAt: SERVER_TIME })])));
    denied(await as(ALICE).commit(batchOf([update(`kyc_applications/${APP}`, { personal: { fullName: 'x'.repeat(201) }, updatedAt: SERVER_TIME })])), 'longer than 200');
    const doc = (side, path) => create(`kyc_documents/${APP}_national_id_${side}_1`, { id: `${APP}_national_id_${side}_1`, applicationId: APP, userId: ALICE, type: 'national_id', side, status: 'uploaded', storagePath: path, contentType: 'image/jpeg', size: 1000, revision: 1, createdAt: SERVER_TIME });
    allowed(await as(ALICE).commit(batchOf([doc('front', `kyc/${ALICE}/${APP}/national_id-front-1.jpg`)])));
    denied(await as(ALICE).commit(batchOf([doc('back', `kyc/${BOB}/${APP}/national_id-back-1.jpg`)])), 'someone else\'s Storage folder');
    denied(await as(ALICE).commit(batchOf(patch([doc('back', `kyc/${ALICE}/${APP}/x.jpg`)], `kyc_documents/${APP}_national_id_back_1`, (d) => ({ ...d, status: 'accepted' })))), 'self-accepted document');
    denied(await as(ALICE).commit(batchOf([update(`kyc_applications/${APP}`, { status: 'submitted', submittedAt: SERVER_TIME, updatedAt: SERVER_TIME }), review('approve')])), 'a history entry the customer may not write');
    allowed(await as(ALICE).commit(batchOf([update(`kyc_applications/${APP}`, { status: 'submitted', submittedAt: SERVER_TIME, updatedAt: SERVER_TIME }), review('submit')])));
    denied(await as(ALICE).commit(batchOf([update(`kyc_applications/${APP}`, { personal: { fullName: 'Changed' }, updatedAt: SERVER_TIME })])), 'editing after submit');
  });

  it('the customer cannot approve, review or reject; can reopen after a rejection', async () => {
    await seed({ [`kyc_applications/${APP}`]: { id: APP, userId: ALICE, level: 'basic', accountType: 'individual', status: 'submitted', revision: 1, personal: { fullName: 'A' }, reason: null } });
    for (const status of ['under_review', 'approved', 'rejected', 'additional_info_required', 'draft']) {
      denied(await as(ALICE).commit(batchOf([update(`kyc_applications/${APP}`, { status, updatedAt: SERVER_TIME })])), `submitted -> ${status}`);
    }
    await seed({ [`kyc_applications/${APP}`]: { id: APP, userId: ALICE, level: 'basic', accountType: 'individual', status: 'rejected', revision: 1, personal: { fullName: 'A' }, reason: 'blurred' } });
    denied(await as(ALICE).commit(batchOf([update(`kyc_applications/${APP}`, { status: 'approved', updatedAt: SERVER_TIME })])));
    denied(await as(ALICE).commit(batchOf([update(`kyc_applications/${APP}`, { status: 'draft', revision: 5, reason: null, updatedAt: SERVER_TIME }), review('reopen')])), 'revision jump');
    allowed(await as(ALICE).commit(batchOf([update(`kyc_applications/${APP}`, { status: 'draft', revision: 2, reason: null, updatedAt: SERVER_TIME }), review('reopen')])));
  });

  it('the owner reads its applications; nobody else does', async () => {
    allowed(await as(ALICE).commit(batchOf([kycApplication()])));
    allowed(await as(ALICE).query('kyc_applications', { where: [['userId', '==', ALICE]] }));
    denied(await as(MALLORY).get(`kyc_applications/${APP}`));
    denied(await as(MALLORY).query('kyc_applications', { where: [['userId', '==', ALICE]] }));
  });

  it('kycLevel / kycStatus / financeRestriction are never written by the user; notification preferences are', async () => {
    for (const f of ['kycLevel', 'kycStatus']) denied(await as(ALICE).commit(batchOf([update(`users/${ALICE}`, { [f]: 'basic' })])), f);
    denied(await as('eve').commit(batchOf([update('users/eve', { financeRestriction: DELETE })])), 'lifting one\'s own restriction');
    denied(await as(BOB).commit(batchOf([update(`users/${ALICE}`, { financeRestriction: { status: 'restricted', scopes: ['all'] } })])), 'blacklisting someone else');
    const prefs = { push: { payments: true, groups: false }, sms: { payments: true }, email: { news: false } };
    allowed(await as(ALICE).commit(batchOf([update(`users/${ALICE}`, { financeNotificationPrefs: prefs })])));
    denied(await as(ALICE).commit(batchOf([update(`users/${ALICE}`, { financeNotificationPrefs: { push: { payments: 'yes' } } })])), 'not a bool');
    denied(await as(BOB).commit(batchOf([update(`users/${ALICE}`, { financeNotificationPrefs: { push: { payments: false } } })])), 'someone else\'s preferences');
    denied(await new (await import('../lib/firestore-rest.js')).Client('newbie').commit(batchOf([create('users/newbie', { role: 'customer', active: true, wallet_amount: 0, kycLevel: 'full' })])), 'sign-up with a KYC level');
    allowed(await new (await import('../lib/firestore-rest.js')).Client('newbie2').commit(batchOf([create('users/newbie2', { role: 'customer', active: true, wallet_amount: 0 })])), 'ordinary sign-up still works');
  });
});

// ---- cards: CardWrites ----------------------------------------------------

function card(id, status, extra = {}) {
  return { [`virtual_cards/${id}`]: { id, userId: ALICE, label: 'Main', currency: 'XAF', network: 'visa', status, balance: 20000, termsVersion: 2, createdAt: new Date(), ...extra } };
}

function cardRequest(uid = ALICE, key = newKey()) {
  const p = plan({ type: 'card_fee', from: walletId(uid), to: platformId(), amount: 1000, userIds: [uid], sourceKind: 'virtual_cards', sourceId: key, createdBy: uid });
  return [
    create(`virtual_cards/${key}`, { id: key, userId: uid, label: 'Online', currency: 'XAF', network: 'visa', status: 'requested', balance: 0, termsVersion: 2, acceptedAt: SERVER_TIME, issuanceFee: 1000, feeTxId: p.txId, payment: { method: 'wallet' }, reference: p.reference, createdAt: SERVER_TIME, updatedAt: SERVER_TIME }),
    ...p.writes,
  ];
}

describe('virtual cards', () => {
  beforeEach(setUp);

  it('a card request pays its issuance fee; never active, funded or free', async () => {
    allowed(await as(ALICE).commit(batchOf(cardRequest())));
    const k = newKey();
    const w = cardRequest(ALICE, k);
    denied(await as(ALICE).commit(batchOf(patch(w, `virtual_cards/${k}`, (d) => ({ ...d, status: 'active' })))));
    denied(await as(ALICE).commit(batchOf(patch(w, `virtual_cards/${k}`, (d) => ({ ...d, balance: 50000 })))));
    denied(await as(ALICE).commit(batchOf([w[0]])), 'without the fee posting');
    denied(await as(ALICE).commit(batchOf(patch(w, `virtual_cards/${k}`, (d) => ({ ...d, termsVersion: 1 })))), 'outdated terms');
  });

  it('freeze: instant; unfreeze: only the user\'s own freeze, re-authenticated', async () => {
    await seed({ ...card('c1', 'active'), ...card('c2', 'frozen', { frozenBy: 'admin' }) });
    const freeze = update('virtual_cards/c1', { status: 'frozen', frozenBy: 'user', frozenAt: SERVER_TIME, updatedAt: SERVER_TIME });
    denied(await as(MALLORY).commit(batchOf([freeze])), 'someone else\'s card');
    allowed(await stale(ALICE).commit(batchOf([freeze])), 'freezing needs no re-authentication');
    const unfreeze = (id) => update(`virtual_cards/${id}`, { status: 'active', frozenBy: null, unfrozenAt: SERVER_TIME, updatedAt: SERVER_TIME });
    denied(await stale(ALICE).commit(batchOf([unfreeze('c1')])), 'unfreeze without re-authentication');
    allowed(await as(ALICE).commit(batchOf([unfreeze('c1')])));
    denied(await as(ALICE).commit(batchOf([unfreeze('c2')])), 'an admin freeze');
    denied(await as(ALICE).commit(batchOf([update('virtual_cards/c1', { balance: 999999, updatedAt: SERVER_TIME })])), 'the balance is the issuer\'s');
    denied(await as(ALICE).commit(batchOf([update('virtual_cards/c1', { status: 'active', last4: '4242', updatedAt: SERVER_TIME })])));
  });

  it('termination and limits need a recent re-authentication; limits stay within the ceilings', async () => {
    await seed(card('c1', 'active'));
    const terminate = update('virtual_cards/c1', { status: 'termination_requested', statusBefore: 'active', terminationRequestedAt: SERVER_TIME, updatedAt: SERVER_TIME });
    denied(await stale(ALICE).commit(batchOf([terminate])));
    const limits = (perTransaction, daily, monthly) => ({ path: 'card_limit_settings/c1', op: 'merge', data: { userId: ALICE, cardId: 'c1', perTransaction, daily, monthly, status: 'pending', updatedAt: SERVER_TIME } });
    denied(await stale(ALICE).commit(batchOf([limits(1000, 5000, 10000)])));
    allowed(await as(ALICE).commit(batchOf([limits(1000, 5000, 10000)])));
    denied(await as(ALICE).commit(batchOf([limits(400000, 500000, 600000)])), 'above maxPerTransaction');
    denied(await as(ALICE).commit(batchOf([limits(9000, 5000, 10000)])), 'per transaction above daily');
    allowed(await as(ALICE).commit(batchOf([terminate])));
  });

  it('a top-up posts amount + fee to the platform; a card withdrawal is a re-authenticated request within the balance', async () => {
    await seed(card('c1', 'active'));
    const key = newKey();
    const p = plan({ type: 'card_funding', from: walletId(ALICE), to: platformId(), amount: 10150, userIds: [ALICE], sourceKind: 'card_funding_requests', sourceId: key, createdBy: ALICE });
    const fund = [create(`card_funding_requests/${key}`, { id: key, userId: ALICE, cardId: 'c1', type: 'fund', amount: 10000, fee: 150, total: 10150, currency: 'XAF', status: 'pending', txId: p.txId, reference: p.reference, payment: { method: 'wallet' }, createdAt: SERVER_TIME, updatedAt: SERVER_TIME }), ...p.writes];
    denied(await as(ALICE).commit(batchOf(patch(fund, `card_funding_requests/${key}`, (d) => ({ ...d, fee: 0, total: 10000 })))), 'fee below fundingFeePercent');
    allowed(await as(ALICE).commit(batchOf(fund)));
    const wd = (amount) => create(`card_funding_requests/${newKey()}`, { userId: ALICE, cardId: 'c1', type: 'withdraw', amount, fee: 0, currency: 'XAF', destination: { method: 'wallet' }, status: 'pending', reference: 'SPF-1', createdAt: SERVER_TIME, updatedAt: SERVER_TIME });
    denied(await stale(ALICE).commit(batchOf([wd(5000)])));
    denied(await as(ALICE).commit(batchOf([wd(50000)])), 'more than the card balance');
    allowed(await as(ALICE).commit(batchOf([wd(5000)])));
    denied(await as(MALLORY).get(`card_funding_requests/${key}`));
  });

  it('a renewal is requested once (no fee configured here)', async () => {
    await seed(card('c1', 'active'));
    const renew = update('virtual_cards/c1', { renewalRequestedAt: SERVER_TIME, renewalFee: 0, updatedAt: SERVER_TIME });
    allowed(await as(ALICE).commit(batchOf([renew])));
    denied(await as(ALICE).commit(batchOf([renew])), 'asked already');
  });
});
