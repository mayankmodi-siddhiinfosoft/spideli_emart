// Chat membership, catalogs (published only), investments, insurance,
// project financing, intelligence, and the restriction scopes.

import { describe, it, beforeEach } from 'node:test';
import {
  setUp, as, ALICE, BOB, CAROL, MALLORY, plan, batchOf, create, update, merge, patch, read, newKey, walletId, platformId,
  SERVER_TIME, seed, union, later, day, DELETE,
} from '../lib/fixtures.js';
import { allowed, denied, assert } from '../lib/expect.js';

// FinanceChatRules.send
function send(chatId, uid, text, { memberIds, tontineId } = {}) {
  const messageId = newKey();
  return [
    create(`finance_chats/${chatId}/messages/${messageId}`, { id: messageId, senderId: uid, senderName: uid, text, createdAt: SERVER_TIME }),
    merge(`finance_chats/${chatId}`, {
      id: chatId, type: tontineId ? 'tontine' : 'direct', ...(tontineId ? { tontineId } : { memberIds: [...memberIds].sort() }),
      lastMessage: { text, senderId: uid, at: SERVER_TIME }, updatedAt: SERVER_TIME, lastReadAt: { [uid]: SERVER_TIME },
    }),
  ];
}
const dm = (a, b) => `dm_${[a, b].sort()[0]}_${[a, b].sort()[1]}`;

describe('chat', () => {
  beforeEach(async () => {
    await setUp();
    await seed({ 'tontines/club': { id: 'club', status: 'active', adminIds: [ALICE], memberIds: [ALICE, BOB], currency: 'XAF', contributionAmount: 5000, membersLimit: 5, currentCycle: 1 } });
  });

  it('a direct conversation: its two members only', async () => {
    const id = dm(ALICE, BOB);
    allowed(await as(ALICE).commit(batchOf(send(id, ALICE, 'Hello', { memberIds: [ALICE, BOB] }))));
    allowed(await as(BOB).commit(batchOf(send(id, BOB, 'Hi', { memberIds: [ALICE, BOB] }))));
    denied(await as(MALLORY).commit(batchOf(send(id, MALLORY, 'Hey', { memberIds: [ALICE, BOB] }))), 'not a member');
    denied(await as(MALLORY).commit(batchOf(send(dm(ALICE, BOB) + 'x', MALLORY, 'Hey', { memberIds: [ALICE, MALLORY] }))), 'an id that is not dm_{sorted members}');
    allowed(await as(BOB).get(`finance_chats/${id}`));
    allowed(await as(BOB).query('messages', { orderBy: [['createdAt', 'desc']] }, `finance_chats/${id}`));
    denied(await as(MALLORY).get(`finance_chats/${id}`));
    denied(await as(MALLORY).query('messages', {}, `finance_chats/${id}`));
    allowed(await as(ALICE).query('finance_chats', { where: [['memberIds', 'array-contains', ALICE]] }));
    // read receipts: own only
    allowed(await as(BOB).commit(batchOf([update(`finance_chats/${id}`, { [`lastReadAt.${BOB}`]: SERVER_TIME })])));
    denied(await as(BOB).commit(batchOf([update(`finance_chats/${id}`, { [`lastReadAt.${ALICE}`]: SERVER_TIME })])), 'someone else\'s read time');
    denied(await as(BOB).commit(batchOf([update(`finance_chats/${id}`, { memberIds: [BOB, MALLORY].sort() })])), 'changing the members');
  });

  it('messages: own sender, 1..1000 characters, never edited or deleted', async () => {
    const id = dm(ALICE, BOB);
    const first = send(id, ALICE, 'Hello', { memberIds: [ALICE, BOB] });
    allowed(await as(ALICE).commit(batchOf(first)));
    denied(await as(ALICE).commit(batchOf(send(id, ALICE, 'x'.repeat(1001), { memberIds: [ALICE, BOB] }))));
    denied(await as(ALICE).commit(batchOf(send(id, ALICE, '', { memberIds: [ALICE, BOB] }))));
    denied(await as(ALICE).commit(batchOf(patch(send(id, ALICE, 'Hi', { memberIds: [ALICE, BOB] }), first[0].path, (d) => d).map((w, i) => (i === 0 ? { ...w, data: { ...w.data, senderId: BOB } } : w)))), 'as someone else');
    denied(await as(ALICE).commit(batchOf([update(first[0].path, { text: 'edited' })])));
    denied(await as(ALICE).commit(batchOf([{ path: first[0].path, op: 'delete' }])));
  });

  it('a tontine group: its active members only (the first message creates the conversation)', async () => {
    allowed(await as(BOB).commit(batchOf(send('tontine_club', BOB, 'Cycle 1 is due', { tontineId: 'club' }))));
    allowed(await as(ALICE).get('finance_chats/tontine_club'));
    denied(await as(CAROL).commit(batchOf(send('tontine_club', CAROL, 'Let me in', { tontineId: 'club' }))));
    denied(await as(CAROL).get('finance_chats/tontine_club'));
    denied(await as(CAROL).commit(batchOf(send('tontine_other', CAROL, 'x', { tontineId: 'club' }))), 'id and tontine do not match');
  });
});

describe('catalogs and owner-only records', () => {
  beforeEach(setUp);

  it('published documents only; list queries must filter on published', async () => {
    allowed(await as(ALICE).get('market_securities/pub'));
    denied(await as(ALICE).get('market_securities/draft'));
    allowed(await as(ALICE).query('market_securities', { where: [['published', '==', true]] }));
    denied(await as(ALICE).query('market_securities', {}), 'an unfiltered query would include drafts');
    denied(await new (await import('../lib/firestore-rest.js')).Client(null).get('market_securities/pub'), 'signed out');
    allowed(await as(ALICE).get('platform_settings/wallet'));
    allowed(await as(ALICE).query('exchange_rate_snapshots', { where: [['pair', '==', 'EUR_XAF']], orderBy: [['observedAt', 'desc']] }));
    denied(await as(ALICE).commit(batchOf([update('platform_settings/wallet', { deposit: { enabled: true, max: { XAF: 999999999 } } })])), 'settings are the admin\'s');
    denied(await as(ALICE).commit(batchOf([create('market_securities/x', { published: true })])));
    denied(await as(ALICE).get('insurance_partners/p1'), 'admin only');
  });

  it('an admin (role) writes and reads everything through the admin wildcard', async () => {
    await seed({ 'users/root': { role: 'admin' } });
    allowed(await as('root').commit(batchOf([update('platform_settings/wallet', { 'deposit.enabled': false }), update(`users/${ALICE}`, { kycLevel: 'basic', kycStatus: 'approved' })])));
    allowed(await as('root').get('market_securities/draft'));
  });
});

describe('investments, insurance, financing, intelligence', () => {
  beforeEach(async () => {
    await setUp();
    await seed({
      'investment_funds/f1': { published: true, status: 'open', name: 'Money market', currency: 'XAF', minInvestment: 10000, minAdditional: 5000, termsVersion: 3, redemption: { allowed: true, partial: false } },
      [`investment_holdings/${ALICE}_f1`]: { userId: ALICE, fundId: 'f1', units: 10, redeemableValue: 20000 },
      'insurance_products/p1': { published: true, status: 'open', name: 'Health', currency: 'XAF', partnerName: 'Insurer', category: 'health', rating: { frequencies: { annual: 0 } } },
      'insurance_quotes/q1': { id: 'q1', userId: ALICE, productId: 'p1', currency: 'XAF', status: 'quoted', premium: 60000, installmentAmount: 60000, frequency: 'annual', termsVersion: 1, validUntil: later(day) },
      'platform_settings/financing': { currencies: ['XAF'], financingTypes: ['loan'], sectors: ['commerce'], stages: ['startup'], documentTypes: ['business_plan'], minAmount: { XAF: 500000 }, maxAmount: { XAF: 50000000 }, durationsMonths: [12], allowedContentTypes: ['application/pdf'], maxFileBytes: 20971520 },
      'investment_opportunities/o1': { published: true, status: 'open', title: 'Farm', currency: 'XAF' },
    });
  });

  function subscribe(uid, amount, extra = {}) {
    const key = newKey();
    const p = plan({ type: 'investment_subscription', from: walletId(uid), to: platformId(), amount, userIds: [uid], sourceKind: 'investment_subscriptions', sourceId: key, createdBy: uid });
    return [create(`investment_subscriptions/${key}`, { id: key, userId: uid, fundId: 'f1', fundName: 'Money market', assetClass: 'money_market', currency: 'XAF', amount, fee: 0, termsVersion: 3, signatureName: 'Alice A', riskAcknowledged: true, acceptedAt: SERVER_TIME, status: 'paid', txId: p.txId, reference: p.reference, payment: { method: 'wallet' }, createdAt: SERVER_TIME, updatedAt: SERVER_TIME, ...extra }), ...p.writes];
  }

  it('a subscription is paid by its posting, under the current terms, above the minimum; never completed by the client', async () => {
    allowed(await as(ALICE).commit(batchOf(subscribe(ALICE, 6000))), 'a holder: minAdditional');
    denied(await as(BOB).commit(batchOf(subscribe(BOB, 6000))), 'below minInvestment for a new investor');
    denied(await as(ALICE).commit(batchOf(subscribe(ALICE, 6000, { termsVersion: 2 }))), 'outdated terms');
    denied(await as(ALICE).commit(batchOf(subscribe(ALICE, 6000, { status: 'completed', units: 100 }))));
    const r = (extra = {}) => create(`investment_redemptions/${newKey()}`, { userId: ALICE, fundId: 'f1', fundName: 'MM', currency: 'XAF', full: true, amount: null, destination: { method: 'wallet' }, status: 'submitted', reference: 'R', createdAt: SERVER_TIME, updatedAt: SERVER_TIME, ...extra });
    allowed(await as(ALICE).commit(batchOf([r()])));
    denied(await as(ALICE).commit(batchOf([r({ full: false, amount: 1000 })])), 'partial redemption not allowed by the fund');
    denied(await as(BOB).commit(batchOf([{ ...r(), data: { ...r().data, userId: BOB } }])), 'no holding');
  });

  it('insurance: request a quote; accept it with the first premium paid; never activate it', async () => {
    allowed(await as(ALICE).commit(batchOf([create(`insurance_quotes/${newKey()}`, { userId: ALICE, productId: 'p1', productName: 'Health', partnerName: 'Insurer', category: 'health', currency: 'XAF', answers: { age: 30 }, frequency: 'annual', coverStart: new Date(), termMonths: 12, status: 'requested', createdAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
    denied(await as(ALICE).commit(batchOf([create(`insurance_quotes/${newKey()}`, { userId: ALICE, productId: 'p1', currency: 'XAF', answers: {}, frequency: 'annual', coverStart: new Date(), status: 'quoted', premium: 1, createdAt: SERVER_TIME })])), 'self-priced quote');
    const p = plan({ type: 'insurance_premium', from: walletId(ALICE), to: platformId(), amount: 60000, userIds: [ALICE], sourceKind: 'insurance_premiums', sourceId: 'q1_1', createdBy: ALICE });
    const acceptBatch = (policyStatus = 'pending_activation') => [
      update('insurance_quotes/q1', { status: 'accepted', acceptedAt: SERVER_TIME, signatureName: 'Alice A', policyId: 'q1', updatedAt: SERVER_TIME }),
      create('insurance_policies/q1', { id: 'q1', userId: ALICE, quoteId: 'q1', productId: 'p1', currency: 'XAF', premium: 60000, frequency: 'annual', installmentAmount: 60000, termsVersion: 1, signatureName: 'Alice A', acceptedAt: SERVER_TIME, autoRenew: false, status: policyStatus, createdAt: SERVER_TIME, updatedAt: SERVER_TIME }),
      create('insurance_premiums/q1_1', { id: 'q1_1', userId: ALICE, policyId: 'q1', amount: 60000, currency: 'XAF', dueDate: SERVER_TIME, status: 'paid', paidAt: SERVER_TIME, txId: p.txId, reference: p.reference, payment: { method: 'wallet' }, createdAt: SERVER_TIME, updatedAt: SERVER_TIME }),
      ...p.writes,
    ];
    denied(await as(ALICE).commit(batchOf(acceptBatch('active'))), 'policy active without the insurer');
    denied(await as(ALICE).commit(batchOf(acceptBatch().slice(0, 2))), 'accepted without paying');
    allowed(await as(ALICE).commit(batchOf(acceptBatch())));
    denied(await as(MALLORY).get('insurance_policies/q1'));
  });

  it('financing: a project, a draft application, its documents under the owner\'s folder; submit with the declaration', async () => {
    allowed(await as(ALICE).commit(batchOf([create('financing_projects/pr1', { id: 'pr1', ownerId: ALICE, name: 'Shop', sector: 'commerce', country: 'CM', city: 'Douala', description: 'A shop', createdAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
    allowed(await as(ALICE).commit(batchOf([create('financing_applications/a1', { id: 'a1', ownerId: ALICE, projectId: 'pr1', projectName: 'Shop', financingType: 'loan', amount: 1000000, currency: 'XAF', durationMonths: 12, useOfFunds: 'Stock', status: 'draft', reviewerIds: [], createdAt: SERVER_TIME, updatedAt: SERVER_TIME })])));
    denied(await as(BOB).commit(batchOf([create('financing_applications/a2', { id: 'a2', ownerId: BOB, projectId: 'pr1', projectName: 'Shop', financingType: 'loan', amount: 1000000, currency: 'XAF', useOfFunds: 'x', status: 'draft', reviewerIds: [], createdAt: SERVER_TIME, updatedAt: SERVER_TIME })])), 'someone else\'s project');
    const doc = (path) => create('financing_documents/d1', { id: 'd1', ownerId: ALICE, applicationId: 'a1', type: 'business_plan', name: 'plan.pdf', storagePath: path, contentType: 'application/pdf', size: 1000, status: 'received', note: '', uploadedAt: SERVER_TIME });
    denied(await as(ALICE).commit(batchOf([doc(`financing_documents/${BOB}/a1/plan.pdf`)])));
    allowed(await as(ALICE).commit(batchOf([doc(`financing_documents/${ALICE}/a1/plan.pdf`)])));
    denied(await as(ALICE).commit(batchOf([update('financing_applications/a1', { status: 'approved', updatedAt: SERVER_TIME })])));
    allowed(await as(ALICE).commit(batchOf([update('financing_applications/a1', { status: 'submitted', declarationAccepted: true, declarationAcceptedAt: SERVER_TIME, submittedAt: SERVER_TIME, ownerMessage: '', reason: null, updatedAt: SERVER_TIME })])));
    denied(await as(ALICE).commit(batchOf([{ path: 'financing_documents/d1', op: 'delete' }])), 'removing a document once submitted');
  });

  it('intelligence: own profile, watchlist and interest only', async () => {
    allowed(await as(ALICE).commit(batchOf([merge(`investor_profiles/${ALICE}`, { currency: 'XAF', sectors: ['agriculture'], countries: ['CM'], types: ['equity'], minTicket: 1000, maxTicket: 50000, maxRisk: 4, maxHorizonMonths: 24, updatedAt: SERVER_TIME })])));
    denied(await as(BOB).commit(batchOf([merge(`investor_profiles/${ALICE}`, { currency: 'XAF', sectors: [], countries: [], types: [], minTicket: 1, maxTicket: 2, maxRisk: 1, maxHorizonMonths: 0, updatedAt: SERVER_TIME })])));
    denied(await as(BOB).get(`investor_profiles/${ALICE}`));
    allowed(await as(ALICE).commit(batchOf([merge(`investor_watchlists/${ALICE}`, { securityIds: ['pub'], updatedAt: SERVER_TIME })])));
    allowed(await as(ALICE).commit(batchOf([merge(`opportunity_interests/o1_${ALICE}`, { opportunityId: 'o1', userId: ALICE, interested: true, message: 'Hi', name: 'Alice', email: 'a@x.test', createdAt: SERVER_TIME })])));
    allowed(await as(ALICE).commit(batchOf([merge(`opportunity_interests/o1_${ALICE}`, { opportunityId: 'o1', userId: ALICE, interested: false, message: '', name: DELETE, email: DELETE, createdAt: SERVER_TIME })])));
    denied(await as(ALICE).commit(batchOf([merge(`opportunity_interests/o1_${BOB}`, { opportunityId: 'o1', userId: BOB, interested: true, message: '', createdAt: SERVER_TIME })])));
  });
});

describe('restriction scopes (users.financeRestriction, admin only)', () => {
  beforeEach(async () => {
    await setUp();
    await seed({
      'users/frank': { role: 'customer', active: true, financeRestriction: { status: 'restricted', reason: 'x', scopes: ['all'] } },
      'users/gina': { role: 'customer', active: true, financeRestriction: { status: 'restricted', reason: 'x' } }, // no scopes = all
      'savings_goals/g9': { id: 'g9', ownerId: ALICE, memberIds: [ALICE], invitedIds: ['frank', BOB], name: 'G', purpose: 'travel', currency: 'XAF', targetAmount: 1000, savedAmount: 0, status: 'active' },
      'tontine_members/tz_gina': { id: 'tz_gina', tontineId: 'tz', userId: 'gina', role: 'member', status: 'invited' },
      'tontines/tz': { id: 'tz', status: 'forming', adminIds: [ALICE], memberIds: [ALICE], membersLimit: 5, currency: 'XAF', contributionAmount: 5000 },
    });
  });

  const goal = (uid, id) => [
    create(`savings_goals/${id}`, { id, ownerId: uid, memberIds: [uid], invitedIds: [], name: 'Trip', purpose: 'travel', description: '', currency: 'XAF', targetAmount: 1000, savedAmount: 0, status: 'active', accountId: `goal_${id}`, createdAt: SERVER_TIME, updatedAt: SERVER_TIME }),
    create(`financial_accounts/goal_${id}`, { kind: 'savings_goal', refId: id, currency: 'XAF', memberIds: [uid], id: `goal_${id}`, balance: 0, normalSide: 'credit', status: 'active', createdAt: SERVER_TIME, updatedAt: SERVER_TIME }),
  ];
  const join = (uid) => [update('savings_goals/g9', { invitedIds: ['frank', BOB].filter((x) => x !== uid), memberIds: union(uid), updatedAt: SERVER_TIME })];

  it('savings: a restricted user (all / no scopes) cannot create or join a goal; others can; declining stays possible', async () => {
    denied(await as('frank').commit(batchOf(goal('frank', 'gf'))));
    denied(await as('gina').commit(batchOf(goal('gina', 'gg'))));
    allowed(await as('eve').commit(batchOf(goal('eve', 'ge'))), 'restricted for loans only');
    denied(await as('frank').commit(batchOf(join('frank'))));
    allowed(await as('frank').commit(batchOf([update('savings_goals/g9', { invitedIds: [BOB], updatedAt: SERVER_TIME })])), 'declining');
    allowed(await as(BOB).commit(batchOf([update('savings_goals/g9', { invitedIds: [], memberIds: union(BOB), updatedAt: SERVER_TIME })])));
  });

  it('tontines: a restricted user cannot join', async () => {
    denied(await as('gina').commit(batchOf([update('tontine_members/tz_gina', { status: 'active', respondedAt: SERVER_TIME, joinedAt: SERVER_TIME }), update('tontines/tz', { memberIds: union('gina'), updatedAt: SERVER_TIME })])));
    allowed(await as('gina').commit(batchOf([update('tontine_members/tz_gina', { status: 'declined', respondedAt: SERVER_TIME })])), 'declining');
  });
});
