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
} else {
  console.log('usage: node customer.mjs transfer FROM TO AMOUNT [NOTE]');
}
