// Acts as a sample customer against the QA emulator THROUGH the security
// rules (an emulator ID token, like the app's), reusing the rules-test
// library: the batches are the app's (fixtures.js plan() is a port of
// FinanceLedger.plan). Used for the other party of a multi-person flow while
// the app under test stays open on the device.
//
//   node customer.mjs transfer jean amina 10000 "Thanks for the groceries"
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'spideli-870b0';
import { readFileSync } from 'node:fs';
const uids = JSON.parse(readFileSync(new URL('./uids.json', import.meta.url)));
const { Client, SERVER_TIME } = await import('../rules-test/lib/firestore-rest.js');
const { plan, batchOf, create } = await import('../rules-test/lib/fixtures.js');

const key = () => `${Date.now()}-${Math.random().toString(36).slice(2, 14)}`;
const [cmd, ...args] = process.argv.slice(2);

if (cmd === 'transfer') {
  const [fromKey, toKey, amountText, note = ''] = args;
  const from = uids[fromKey], to = uids[toKey], amount = Number(amountText);
  const id = key();
  const p = plan({ type: 'transfer', from: `wallet_${from}_XAF`, to: `wallet_${to}_XAF`, amount, userIds: [from, to], sourceKind: 'money_transfers', sourceId: id, createdBy: from, description: note });
  const names = { amina: 'Amina Diallo', jean: 'Jean Mbarga', fatou: 'Fatou Ndiaye' };
  const rec = create(`money_transfers/${id}`, {
    id, senderId: from, senderName: names[fromKey], recipientId: to, participantIds: [from, to], channel: 'internal',
    recipient: { email: `${toKey}@spideli.test` }, recipientName: names[toKey], recipientVerified: true, currency: 'XAF',
    amount, fee: 0, total: amount, receiveAmount: amount, note, funding: { method: 'wallet' },
    createdAt: SERVER_TIME, status: 'completed', reference: p.reference, txId: p.txId, completedAt: SERVER_TIME,
  });
  const r = await new Client(from).commit(batchOf(p.writes, rec));
  console.log(r.ok ? `ok ${p.reference}` : `refused ${r.status} ${r.body.slice(0, 300)}`);
} else if (cmd === 'goal-join') {
  // The invitee accepts: memberIds += uid (appended), invitedIds -= uid.
  const [who, goalId] = args;
  const uid = uids[who];
  const c = new Client(uid);
  const g = (await c.get(`savings_goals/${goalId}`)).data;
  const b = new (await import('../rules-test/lib/firestore-rest.js')).Batch();
  b.update(`savings_goals/${goalId}`, { invitedIds: g.invitedIds.filter((x) => x !== uid), memberIds: [...g.memberIds, uid], updatedAt: SERVER_TIME });
  const r = await c.commit(b);
  console.log(r.ok ? 'ok' : `refused ${r.status} ${r.body.slice(0, 300)}`);
} else if (cmd === 'tontine-join') {
  // The invitee accepts (TontineWrites.respond): own member doc active + tontine memberIds += uid.
  const [who, tid] = args;
  const uid = uids[who];
  const c = new Client(uid);
  // An invitee cannot read the tontine (rules): like the app, arrayUnion.
  const { Batch, union } = await import('../rules-test/lib/firestore-rest.js');
  const b = new Batch();
  b.update(`tontine_members/${tid}_${uid}`, { status: 'active', respondedAt: SERVER_TIME, joinedAt: SERVER_TIME });
  b.update(`tontines/${tid}`, { memberIds: union(uid), updatedAt: SERVER_TIME });
  const r = await c.commit(b);
  console.log(r.ok ? 'ok' : `refused ${r.status} ${r.body.slice(0, 300)}`);
} else if (cmd === 'tontine-pay') {
  // A member's contribution to the collecting cycle (TontineWrites.contribute), from the wallet.
  const [who, tid] = args;
  const uid = uids[who];
  const c = new Client(uid);
  const { Batch, inc } = await import('../rules-test/lib/firestore-rest.js');
  const t = (await c.get(`tontines/${tid}`)).data;
  const cid = `${tid}_${t.currentCycle}`;
  const cycle = (await c.get(`tontine_cycles/${cid}`)).data;
  const amount = t.contributionAmount;
  const completes = cycle.collectedAmount + amount >= cycle.expectedAmount;
  const id = `${cid}_${uid}`;
  const p = plan({ type: 'tontine_contribution', currency: t.currency, from: `wallet_${uid}_${t.currency}`, to: `tontine_${tid}`, amount, userIds: [uid], sourceKind: 'tontine_contributions', sourceId: id, createdBy: uid, description: t.name });
  const writes = [
    create(`tontine_contributions/${id}`, { id, tontineId: tid, cycleId: cid, cycleNumber: cycle.number, userId: uid, amount, currency: t.currency, status: 'paid', reference: p.reference, txId: p.txId, funding: 'wallet', paidAt: SERVER_TIME, createdAt: SERVER_TIME }),
    ...p.writes,
    { path: `tontine_cycles/${cid}`, op: 'update', data: { collectedAmount: inc(amount), ...(completes ? { status: 'payout_pending' } : {}), lastTxId: p.txId, updatedAt: SERVER_TIME } },
    ...(completes ? [create(`tontine_payouts/${cid}`, { id: cid, tontineId: tid, cycleId: cid, cycleNumber: cycle.number, beneficiaryUserId: cycle.beneficiaryUserId, amount: cycle.expectedAmount, currency: t.currency, status: 'pending_approval', createdAt: SERVER_TIME })] : []),
  ];
  const r = await c.commit(batchOf(writes));
  console.log(r.ok ? `ok ${p.reference}${completes ? ' (pot complete)' : ''}` : `refused ${r.status} ${r.body.slice(0, 300)}`);
} else if (cmd === 'loan-apply') {
  // LoanWrites.apply: the borrower asks the group (a tontine) for a loan.
  const [who, tid, amountText, months, freq, purpose, ...desc] = args;
  const uid = uids[who];
  const c = new Client(uid);
  const t = (await c.get(`tontines/${tid}`)).data;
  const id = key();
  const { Batch } = await import('../rules-test/lib/firestore-rest.js');
  const b = new Batch();
  b.set(`loan_applications/${id}`, {
    id, borrowerId: uid, groupId: tid, groupName: t.name, status: 'submitted', currency: t.currency, amount: Number(amountText),
    fundedAmount: 0, outstandingAmount: 0, repaidAmount: 0, durationMonths: Number(months), repaymentFrequency: freq, purpose,
    description: desc.join(' '), eligibleVoterIds: t.memberIds.filter((m) => m !== uid), lenderIds: [], votes: { yes: 0, no: 0 }, documents: [],
    createdAt: SERVER_TIME, updatedAt: SERVER_TIME,
  });
  const r = await c.commit(b);
  console.log(r.ok ? `ok ${id}` : `refused ${r.status} ${r.body.slice(0, 300)}`);
} else if (cmd === 'loan-vote') {
  // LoanWrites.vote: the voter's vote + the loan's counter.
  const [who, loanId, choice, ...comment] = args;
  const uid = uids[who];
  const approve = choice === 'yes';
  const { Batch, inc } = await import('../rules-test/lib/firestore-rest.js');
  const b = new Batch();
  b.set(`loan_votes/${loanId}_${uid}`, { loanId, voterId: uid, approve, comment: comment.join(' '), at: SERVER_TIME });
  b.update(`loan_applications/${loanId}`, { [approve ? 'votes.yes' : 'votes.no']: inc(1), updatedAt: SERVER_TIME });
  const r = await new Client(uid).commit(b);
  console.log(r.ok ? 'ok' : `refused ${r.status} ${r.body.slice(0, 300)}`);
} else if (cmd === 'tontine-chat') {
  // FinanceChatRules.send for a tontine group chat: the message + the chat's last message.
  const [who, tid, ...words] = args;
  const uid = uids[who];
  const names = { amina: 'Amina Diallo', jean: 'Jean Mbarga', fatou: 'Fatou Ndiaye' };
  const text = words.join(' ');
  const chat = `tontine_${tid}`;
  const id = `qa${Date.now()}`;
  const { Batch } = await import('../rules-test/lib/firestore-rest.js');
  const b = new Batch();
  b.set(`finance_chats/${chat}/messages/${id}`, { id, senderId: uid, senderName: names[who], text, createdAt: SERVER_TIME });
  b.update(`finance_chats/${chat}`, { lastMessage: { text, senderId: uid, at: SERVER_TIME }, updatedAt: SERVER_TIME });
  const r = await new Client(uid).commit(b);
  console.log(r.ok ? 'ok' : `refused ${r.status} ${r.body.slice(0, 300)}`);
} else {
  console.log('usage: node customer.mjs transfer FROM TO AMOUNT [NOTE] | goal-join WHO GOAL_ID | tontine-join WHO TID | tontine-pay WHO TID');
}
