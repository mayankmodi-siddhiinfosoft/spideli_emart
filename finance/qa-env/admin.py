#!/usr/bin/env python3
"""Simulates the admin panel's steps in the QA emulator, as
docs/SPIDELI_FINANCE_ADMIN_WEB_SPEC.md describes them (owner access, like the
panel's Admin SDK: the rules are bypassed, so every check is made here).

    python3 admin.py withdrawal-complete OP_ID
    python3 admin.py withdrawal-fail OP_ID "reason"
    python3 admin.py reverse TX_ID "reason"
    ... (see the commands at the end)

Each money step is a balanced posting: platform and customer accounts move by
the same amount, and a wallet never goes below zero.
"""

import datetime
import json
import os
import random
import string
import sys
import urllib.error
import urllib.request

PROJECT = 'spideli-870b0'
FS = f'http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents'
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from seed import enc  # noqa: E402
from verify import dec  # noqa: E402

ADMIN = 'admin:qa'


def now():
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)


def call(method, url, body=None):
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(), headers={'Content-Type': 'application/json', 'Authorization': 'Bearer owner'}, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise SystemExit(f'{method} {url} -> {e.code}: {e.read().decode()[:300]}')


def get(path):
    d = call('GET', f'{FS}/{path}')
    return None if d is None else {k: dec(v) for k, v in d.get('fields', {}).items()}


def patch(path, fields):
    """Updates only the given fields (like the panel's update())."""
    mask = '&'.join(f'updateMask.fieldPaths={k}' for k in fields)
    call('PATCH', f'{FS}/{path}?{mask}', {'fields': {k: enc(v) for k, v in fields.items()}})


def put(path, data):
    call('PATCH', f'{FS}/{path}', {'fields': {k: enc(v) for k, v in data.items()}})


def rid(n=8):
    return ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(n))


def reference():
    a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    return 'SPF-' + now().strftime('%y%m%d') + '-' + ''.join(random.choice(a) for _ in range(6))


def post(type_, cur, frm, to, amount, user_ids, source, description, fee=0, reversal_of=None):
    """The panel's posting helper (admin spec 5.2): plan (reads, checks), then write."""
    assert amount > 0 and fee >= 0 and frm != to
    platform = f'platform_{cur}'
    lines = [{'accountId': frm, 'direction': 'debit', 'amount': amount + fee}, {'accountId': to, 'direction': 'credit', 'amount': amount}]
    if fee > 0 and platform not in (frm, to):
        lines.append({'accountId': platform, 'direction': 'credit', 'amount': fee})
    accounts = {}
    for l in lines:
        a = get(f'financial_accounts/{l["accountId"]}')
        if a is None:
            if l['direction'] == 'debit' or not l['accountId'].startswith('wallet_'):
                raise SystemExit(f'missing account {l["accountId"]}')
            uid = l['accountId'][len('wallet_'):].rsplit('_', 1)[0]
            a = {'id': l['accountId'], 'kind': 'wallet', 'userId': uid, 'currency': cur, 'balance': 0, 'normalSide': 'credit', 'status': 'active', '_new': True}
        if a.get('status') != 'active':
            raise SystemExit(f'account {l["accountId"]} is {a.get("status")}')
        delta = -l['amount'] if l['direction'] == 'debit' else l['amount']
        if a['balance'] + delta < 0 and a.get('kind') != 'platform':
            raise SystemExit(f'insufficient funds on {l["accountId"]}: {a["balance"]} < {l["amount"]}')
        accounts[l['accountId']] = (a, delta)
    tx = f'tx_{int(now().timestamp() * 1000)}_{rid()}'
    t = now()
    doc = {'id': tx, 'type': type_, 'status': 'posted', 'reference': reference(), 'currency': cur, 'lines': lines, 'userIds': sorted(set(user_ids)),
           'accountIds': [l['accountId'] for l in lines], 'source': source, 'funding': 'wallet', 'description': description, 'createdBy': ADMIN, 'createdAt': t}
    if reversal_of:
        doc['reversalOf'] = reversal_of
    put(f'ledger_transactions/{tx}', doc)
    for acc_id, (a, delta) in accounts.items():
        if a.get('_new'):
            put(f'financial_accounts/{acc_id}', {'id': acc_id, 'kind': 'wallet', 'userId': a['userId'], 'currency': cur, 'balance': delta, 'normalSide': 'credit', 'status': 'active', 'lastTxId': tx, 'createdAt': t, 'updatedAt': t})
        else:
            patch(f'financial_accounts/{acc_id}', {'balance': a['balance'] + delta, 'lastTxId': tx, 'updatedAt': t})
    return tx, doc['reference']


def reverse(tx_id, reason):
    o = get(f'ledger_transactions/{tx_id}')
    if o is None or o['status'] == 'reversed':
        raise SystemExit('nothing to reverse')
    debit, credit = o['lines'][0], o['lines'][1]
    ids = [post('reversal', o['currency'], credit['accountId'], debit['accountId'], credit['amount'], o['userIds'], o['source'], reason, reversal_of=tx_id)[0]]
    if len(o['lines']) > 2:
        ids.append(post('reversal', o['currency'], o['lines'][2]['accountId'], debit['accountId'], o['lines'][2]['amount'], o['userIds'], o['source'], reason, reversal_of=tx_id)[0])
    patch(f'ledger_transactions/{tx_id}', {'status': 'reversed', 'reversedBy': ids, 'reversedAt': now()})
    return ids


# ---------------------------------------------------------------- queues
def withdrawal_complete(op_id):
    op = get(f'wallet_operations/{op_id}')
    assert op and op['type'] == 'withdrawal' and op['status'] == 'pending', op
    patch(f'wallet_operations/{op_id}', {'status': 'completed', 'payoutReference': 'OM-QA-' + rid(6).upper(), 'completedAt': now(), 'processedBy': ADMIN})


def withdrawal_fail(op_id, reason):
    op = get(f'wallet_operations/{op_id}')
    assert op and op['type'] == 'withdrawal' and op['status'] == 'pending', op
    reverse(op['txId'], reason)
    patch(f'wallet_operations/{op_id}', {'status': 'reversed', 'reason': reason, 'completedAt': now(), 'processedBy': ADMIN})


def transfer_lock(tid):
    patch(f'money_transfers/{tid}', {'adminLockedAt': now()})


def transfer_complete(tid):
    t = get(f'money_transfers/{tid}')
    assert t and t['status'] == 'processing' and not t.get('cancelRequested'), t
    patch(f'money_transfers/{tid}', {'status': 'completed', 'providerReference': 'MM-QA-' + rid(6).upper(), 'completedAt': now(), 'recipientVerified': True})


def transfer_cancel(tid):
    """A cancel request not yet paid: refund, then cancelled."""
    t = get(f'money_transfers/{tid}')
    assert t and t['status'] == 'processing' and t.get('cancelRequested') is True, t
    reverse(t['txId'], 'Cancelled at your request')
    patch(f'money_transfers/{tid}', {'status': 'cancelled', 'reason': 'cancelled_by_sender', 'completedAt': now()})


def transfer_reverse(tid, reason):
    t = get(f'money_transfers/{tid}')
    assert t and t['status'] == 'processing', t
    reverse(t['txId'], reason)
    patch(f'money_transfers/{tid}', {'status': 'reversed', 'reason': reason, 'completedAt': now()})


def bill_complete(rid_, token=None):
    r = get(f'utility_payment_requests/{rid_}')
    assert r and r['status'] == 'processing', r
    fields = {'status': 'completed', 'billerReference': 'CP-QA-' + rid(6).upper(), 'customerName': 'A. DIALLO', 'completedAt': now(), 'processedBy': ADMIN}
    if token:
        fields.update({'token': token, 'tokenLabel': 'Your electricity code', 'units': '48.5 kWh'})
    patch(f'utility_payment_requests/{rid_}', fields)


def bill_reverse(rid_, reason):
    r = get(f'utility_payment_requests/{rid_}')
    assert r and r['status'] == 'processing', r
    reverse(r['txId'], reason)
    patch(f'utility_payment_requests/{rid_}', {'status': 'reversed', 'reason': reason, 'completedAt': now(), 'processedBy': ADMIN})


def card_issue(card_id):
    c = get(f'virtual_cards/{card_id}')
    assert c and c['status'] == 'requested', c
    u = get(f'users/{c["userId"]}')
    exp = now() + datetime.timedelta(days=3 * 365)
    patch(f'virtual_cards/{card_id}', {'status': 'active', 'last4': str(random.randint(1000, 9999)), 'expiryMonth': exp.month, 'expiryYear': exp.year,
                                        'cardholderName': f'{u["firstName"]} {u["lastName"]}'.upper(), 'network': 'visa', 'balance': 0, 'updatedAt': now()})


def card_request_complete(req_id):
    r = get(f'card_funding_requests/{req_id}')
    assert r and r['status'] == 'pending', r
    c = get(f'virtual_cards/{r["cardId"]}')
    t = now()
    if r['type'] == 'fund':
        patch(f'virtual_cards/{r["cardId"]}', {'balance': c.get('balance', 0) + r['amount'], 'updatedAt': t})
        kind = 'funding'
    elif r['type'] == 'withdraw':
        assert c.get('balance', 0) >= r['amount']
        post('card_withdrawal', r['currency'], f'platform_{r["currency"]}', f'wallet_{r["userId"]}_{r["currency"]}', r['amount'], [r['userId']], {'kind': 'card_funding_requests', 'id': req_id}, 'Card balance back to the wallet')
        patch(f'virtual_cards/{r["cardId"]}', {'balance': c['balance'] - r['amount'], 'updatedAt': t})
        kind = 'withdrawal'
    else:
        raise SystemExit('card to card: not simulated')
    put(f'card_transactions/{req_id}', {'userId': r['userId'], 'cardId': r['cardId'], 'type': kind, 'status': 'completed', 'amount': r['amount'], 'currency': r['currency'], 'createdAt': t})
    patch(f'card_funding_requests/{req_id}', {'status': 'succeeded', 'completedAt': t, 'processedBy': ADMIN, 'updatedAt': t})


def card_limits_apply(card_id):
    patch(f'card_limit_settings/{card_id}', {'status': 'applied', 'appliedAt': now()})


def card_purchase(card_id, amount, merchant):
    """An issuer webhook: a card payment (the card's own money, no ledger posting)."""
    c = get(f'virtual_cards/{card_id}')
    assert c['balance'] >= amount
    t = now()
    patch(f'virtual_cards/{card_id}', {'balance': c['balance'] - amount, 'updatedAt': t})
    put(f'card_transactions/qa_{rid()}', {'userId': c['userId'], 'cardId': card_id, 'type': 'purchase', 'status': 'completed', 'amount': amount, 'currency': c['currency'], 'merchantName': merchant, 'merchantCountry': 'FR', 'createdAt': t})


def savings_withdrawal_complete(wid):
    w = get(f'savings_withdrawals/{wid}')
    assert w and w['status'] == 'requested', w
    g = get(f'savings_goals/{w["goalId"]}')
    assert g['status'] == 'active' and w['amount'] <= g['savedAmount']
    tx, _ = post('savings_withdrawal', w['currency'], f'goal_{w["goalId"]}', f'wallet_{w["userId"]}_{w["currency"]}', w['amount'], [w['userId']], {'kind': 'savings_withdrawals', 'id': wid}, f'Withdrawal from {g["name"]}')
    patch(f'savings_goals/{w["goalId"]}', {'savedAmount': g['savedAmount'] - w['amount'], 'lastTxId': tx, 'updatedAt': now()})
    patch(f'savings_withdrawals/{wid}', {'status': 'completed', 'txId': tx, 'completedAt': now(), 'processedBy': ADMIN})


def savings_withdrawal_reject(wid, reason):
    patch(f'savings_withdrawals/{wid}', {'status': 'rejected', 'rejectionReason': reason, 'processedBy': ADMIN})


def tontine_payout_approve(cycle_id):
    """Admin approves the payout of a sole-admin beneficiary (admin spec 6.8)."""
    p = get(f'tontine_payouts/{cycle_id}')
    assert p and p['status'] == 'pending_approval', p
    t = get(f'tontines/{p["tontineId"]}')
    assert p['cycleNumber'] == t['currentCycle']
    tx, ref = post('tontine_payout', p['currency'], f'tontine_{p["tontineId"]}', f'wallet_{p["beneficiaryUserId"]}_{p["currency"]}', p['amount'], [p['beneficiaryUserId']], {'kind': 'tontine_payouts', 'id': cycle_id}, f'{t["name"]} - cycle {p["cycleNumber"]}')
    ts = now()
    patch(f'tontine_payouts/{cycle_id}', {'status': 'paid', 'txId': tx, 'reference': ref, 'approvedBy': ADMIN, 'approvedAt': ts, 'paidAt': ts, 'updatedAt': ts})
    patch(f'tontine_cycles/{cycle_id}', {'status': 'paid', 'paidAt': ts, 'updatedAt': ts})
    n = p['cycleNumber']
    count = len(t['memberIds'])
    if n < count:
        nxt = get(f'tontine_cycles/{p["tontineId"]}_{n + 1}')
        patch(f'tontine_cycles/{p["tontineId"]}_{n + 1}', {'status': 'collecting', 'updatedAt': ts})
        due = datetime.datetime.strptime(nxt['dueDate'][:19], '%Y-%m-%dT%H:%M:%S')
        patch(f'tontines/{p["tontineId"]}', {'currentCycle': n + 1, 'nextDueAt': due, 'updatedAt': ts})
    else:
        patch(f'tontines/{p["tontineId"]}', {'status': 'completed', 'completedAt': ts, 'updatedAt': ts})


def loan_review(loan_id):
    l = get(f'loan_applications/{loan_id}')
    assert l and l['status'] == 'submitted', l
    patch(f'loan_applications/{loan_id}', {'status': 'under_review', 'updatedAt': now()})


def loan_open_vote(loan_id, hours=48):
    l = get(f'loan_applications/{loan_id}')
    assert l and l['status'] == 'under_review', l
    patch(f'loan_applications/{loan_id}', {'status': 'voting', 'votingEndsAt': now() + datetime.timedelta(hours=hours), 'updatedAt': now()})


def loan_assess(loan_id):
    l = get(f'loan_applications/{loan_id}')
    put(f'credit_assessments/{loan_id}', {'loanId': loan_id, 'borrowerId': l['borrowerId'], 'score': 712, 'band': 'good', 'assessedAt': now(),
        'factors': [{'label': 'Regular tontine contributions', 'impact': 'positive', 'detail': 'Every contribution paid on time.'},
                    {'label': 'Short history with Spideli Finance', 'impact': 'negative', 'detail': 'Less than 3 months of activity.'}]})


def subscription_execute(sid):
    """Admin spec 6.10: units at the unit price, the full holding, a transaction."""
    sub = get(f'investment_subscriptions/{sid}')
    assert sub and sub['status'] == 'paid', sub
    f = get(f'investment_funds/{sub["fundId"]}')
    nav = float(f['navPerUnit'])
    fee = round(sub['amount'] * f['fees']['subscriptionPercent'] / 100)
    net = sub['amount'] - fee
    units = int(net / nav * 10000) / 10000
    t = now()
    hid = f'{sub["userId"]}_{sub["fundId"]}'
    h = get(f'investment_holdings/{hid}') or {'units': 0, 'investedAmount': 0, 'realizedGains': 0}
    tot_units = round(h['units'] + units, 4)
    invested = h['investedAmount'] + sub['amount']
    value = round(tot_units * nav)
    put(f'investment_holdings/{hid}', {'userId': sub['userId'], 'fundId': sub['fundId'], 'fundName': f['name'], 'assetClass': f['assetClass'], 'currency': f['currency'],
        'units': tot_units, 'redeemableUnits': tot_units, 'redeemableValue': value, 'investedAmount': invested, 'currentValue': value,
        'realizedGains': h.get('realizedGains', 0), 'unrealizedGains': value - invested, 'lockedUntil': None, 'valuedAt': t})
    put(f'investment_transactions/{sid}', {'userId': sub['userId'], 'fundId': sub['fundId'], 'type': 'subscription', 'amount': sub['amount'], 'units': units, 'navPerUnit': nav, 'currency': f['currency'], 'reference': sub['reference'], 'createdAt': t})
    patch(f'investment_subscriptions/{sid}', {'status': 'completed', 'units': units, 'navPerUnit': nav, 'netAmount': net, 'fee': fee, 'tradeDate': t, 'updatedAt': t})


def redemption_settle(rid_):
    r = get(f'investment_redemptions/{rid_}')
    assert r and r['status'] == 'submitted', r
    f = get(f'investment_funds/{r["fundId"]}')
    hid = f'{r["userId"]}_{r["fundId"]}'
    h = get(f'investment_holdings/{hid}')
    nav = float(f['navPerUnit'])
    gross = round(h['units'] * nav) if r.get('full') else r['amount']
    units = round(h['units'], 4) if r.get('full') else int(gross / nav * 10000) / 10000
    fee = round(gross * f['fees']['redemptionPercent'] / 100)
    net = gross - fee
    t = now()
    tx, _ = post('investment_redemption', r['currency'], f'platform_{r["currency"]}', f'wallet_{r["userId"]}_{r["currency"]}', net, [r['userId']], {'kind': 'investment_redemptions', 'id': rid_}, f'Redemption - {f["name"]}')
    left = round(h['units'] - units, 4)
    cost = round(h['investedAmount'] * units / h['units'])
    invested = h['investedAmount'] - cost
    value = round(left * nav)
    patch(f'investment_holdings/{hid}', {'units': left, 'redeemableUnits': left, 'redeemableValue': value, 'investedAmount': invested, 'currentValue': value,
        'realizedGains': h.get('realizedGains', 0) + (net - cost), 'unrealizedGains': value - invested, 'valuedAt': t})
    put(f'investment_transactions/{rid_}', {'userId': r['userId'], 'fundId': r['fundId'], 'type': 'redemption', 'amount': net, 'units': units, 'navPerUnit': nav, 'currency': r['currency'], 'reference': r['reference'], 'createdAt': t})
    patch(f'investment_redemptions/{rid_}', {'status': 'settled', 'units': units, 'navPerUnit': nav, 'fee': fee, 'netAmount': net, 'tradeDate': t, 'expectedSettlementDate': t, 'settledAt': t, 'txId': tx, 'updatedAt': t})


def quote_price(qid, premium=171600, instalment=15015):
    q = get(f'insurance_quotes/{qid}')
    assert q and q['status'] == 'requested', q
    p = get(f'insurance_products/{q["productId"]}')
    start = datetime.datetime.strptime(q['coverStart'][:19], '%Y-%m-%dT%H:%M:%S')
    patch(f'insurance_quotes/{qid}', {'status': 'quoted', 'premium': premium, 'installmentAmount': instalment, 'deductible': p['deductible'],
        'coverEnd': start + datetime.timedelta(days=365), 'validUntil': now() + datetime.timedelta(days=14), 'terms': p['terms'], 'termsVersion': p['termsVersion'],
        'coverages': p['coverages'], 'insurerReference': 'DI-QA-' + rid(5).upper(), 'updatedAt': now()})


def policy_activate(pid):
    pol = get(f'insurance_policies/{pid}')
    assert pol and pol['status'] == 'pending_activation', pol
    t = now()
    due = t + datetime.timedelta(days=30)
    for n in (2, 3):
        put(f'insurance_premiums/{pid}_{n}', {'id': f'{pid}_{n}', 'userId': pol['userId'], 'policyId': pid, 'amount': pol['installmentAmount'], 'currency': pol['currency'],
            'dueDate': t + datetime.timedelta(days=30 * (n - 1)), 'status': 'upcoming', 'createdAt': t, 'updatedAt': t})
    patch(f'insurance_policies/{pid}', {'status': 'active', 'policyNumber': 'POL-QA-' + rid(6).upper(), 'nextPremiumDue': due, 'updatedAt': t})


def claim_request_info(cid, question):
    t = now()
    patch(f'insurance_claims/{cid}', {'status': 'info_requested', 'reason': question, 'updatedAt': t})
    put(f'insurance_claims/{cid}/events/admin_{rid()}', {'type': 'info_requested', 'authorId': ADMIN, 'message': question, 'createdAt': t})


def claim_approve_pay(cid, amount):
    c = get(f'insurance_claims/{cid}')
    t = now()
    post('insurance_claim_payout', c['currency'], f'platform_{c["currency"]}', f'wallet_{c["userId"]}_{c["currency"]}', amount, [c['userId']], {'kind': 'insurance_claims', 'id': cid}, 'Insurance claim payment')
    patch(f'insurance_claims/{cid}', {'status': 'paid', 'approvedAmount': amount, 'paidAmount': amount, 'paidAt': t, 'updatedAt': t})


if __name__ == '__main__':
    cmd, args = sys.argv[1], sys.argv[2:]
    {
        'withdrawal-complete': lambda: withdrawal_complete(args[0]),
        'withdrawal-fail': lambda: withdrawal_fail(args[0], args[1]),
        'reverse': lambda: print(reverse(args[0], args[1])),
        'transfer-lock': lambda: transfer_lock(args[0]),
        'quote-price': lambda: quote_price(args[0]),
        'policy-activate': lambda: policy_activate(args[0]),
        'claim-info': lambda: claim_request_info(args[0], args[1]),
        'claim-pay': lambda: claim_approve_pay(args[0], int(args[1])),
        'redemption-settle': lambda: redemption_settle(args[0]),
        'subscription-execute': lambda: subscription_execute(args[0]),
        'loan-review': lambda: loan_review(args[0]),
        'loan-open-vote': lambda: loan_open_vote(args[0]),
        'loan-assess': lambda: loan_assess(args[0]),
        'tontine-payout-approve': lambda: tontine_payout_approve(args[0]),
        'savings-withdrawal-complete': lambda: savings_withdrawal_complete(args[0]),
        'savings-withdrawal-reject': lambda: savings_withdrawal_reject(args[0], args[1]),
        'card-issue': lambda: card_issue(args[0]),
        'card-request-complete': lambda: card_request_complete(args[0]),
        'card-limits-apply': lambda: card_limits_apply(args[0]),
        'card-purchase': lambda: card_purchase(args[0], int(args[1]), args[2]),
        'bill-complete': lambda: bill_complete(args[0], args[1] if len(args) > 1 else None),
        'bill-reverse': lambda: bill_reverse(args[0], args[1]),
        'transfer-complete': lambda: transfer_complete(args[0]),
        'transfer-cancel': lambda: transfer_cancel(args[0]),
        'transfer-reverse': lambda: transfer_reverse(args[0], args[1]),
    }[cmd]()
    print('done')
