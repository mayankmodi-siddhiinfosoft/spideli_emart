# Demo data for ONE test account, so every Spideli Finance screen can be seen
# filled in before the backend exists. Everything is marked `demo: true` and
# has a `demo_...` id; nothing is visible to other users (the demo fund,
# insurance product and biller are created UNPUBLISHED, so no catalog lists
# them). No economic indicator, exchange rate or opportunity is created:
# those must come from approved sources and are shown to every user.
#
# CREATE-ONLY (an existing document is skipped). DRY RUN by default.
#   python3 .claude/seed_finance_demo.py --uid <uid>             # show the plan
#   python3 .claude/seed_finance_demo.py --uid <uid> --apply     # create it
#   python3 .claude/seed_finance_demo.py --uid <uid> --delete    # remove it again
#   python3 .claude/seed_finance_demo.py --uid <uid> --fix-monthly  # rewrite only the dashboard chart months
#   python3 .claude/seed_finance_demo.py --uid <uid> --region <id> --set-region [--apply]
#       # give the existing demo records their Finance region (only the
#       # `regionId` field, only on documents with demo: true)
#
# Finance is per region (APP-SPEC-FINANCE-REGION-SETTINGS): the requests and
# postings below carry `regionId`, the XAF region with Finance on
# (Yaounde-Cameroun on live) unless --region names another.
import datetime
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

KEY = 'AIzaSyDzPw53B4IC7ghgwjSdng4FmBg860V9zPs'  # the apps' public web API key
BASE = 'https://firestore.googleapis.com/v1/projects/spideli-870b0/databases/(default)/documents'
APPLY = '--apply' in sys.argv
DELETE = '--delete' in sys.argv
if '--uid' not in sys.argv:
    sys.exit('Usage: seed_finance_demo.py --uid <uid> [--apply | --delete]')
UID = sys.argv[sys.argv.index('--uid') + 1]
REGION = sys.argv[sys.argv.index('--region') + 1] if '--region' in sys.argv else 'RANln1qefPEoOuqlT0vy'  # Yaounde-Cameroun (XAF)
SET_REGION = '--set-region' in sys.argv
# The documents that carry their region (the app's FinanceRegionRules.regionCollections).
REGION_COLLECTIONS = {
    'wallet_operations', 'money_transfers', 'utility_payment_requests', 'virtual_cards', 'card_funding_requests',
    'savings_goals', 'tontines', 'loan_applications', 'investment_subscriptions', 'insurance_quotes',
    'financing_projects', 'financing_applications', 'kyc_applications', 'ledger_transactions',
}
NOW = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None, microsecond=0)
CUR = 'XAF'


def days(n):
    return NOW + datetime.timedelta(days=n)


def enc(v):
    if v is None:
        return {'nullValue': None}
    if isinstance(v, bool):
        return {'booleanValue': v}
    if isinstance(v, int):
        return {'integerValue': str(v)}
    if isinstance(v, float):
        return {'doubleValue': v}
    if isinstance(v, str):
        return {'stringValue': v}
    if isinstance(v, datetime.datetime):
        return {'timestampValue': v.strftime('%Y-%m-%dT%H:%M:%SZ')}
    if isinstance(v, list):
        return {'arrayValue': {'values': [enc(x) for x in v]}}
    if isinstance(v, dict):
        return {'mapValue': {'fields': {k: enc(x) for k, x in v.items()}}}
    raise TypeError(v)


def request(method, url, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'}, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, (json.loads(raw) if raw else {})


def get(path):
    status, body = request('GET', f'{BASE}/{path}?key={KEY}')
    return body if status == 200 else None


def error(body):
    return body.get('error', {}).get('message', body) if isinstance(body, dict) else body


# ---------------------------------------------------------------- the data
DOCS = []  # (collection, id, data)


def add(collection, doc_id, data):
    regional = {'regionId': REGION} if collection in REGION_COLLECTIONS else {}
    DOCS.append((collection, doc_id, {**data, **regional, 'demo': True}))


WALLET = 'demo_wallet'
add('financial_accounts', WALLET, {'id': WALLET, 'userId': UID, 'kind': 'wallet', 'currency': CUR, 'balance': 245000, 'status': 'active', 'normalSide': 'credit'})

for i, (typ, direction, amount, ago, text) in enumerate([
    ('deposit', 'credit', 300000, 30, 'Mobile Money deposit'),
    ('transfer', 'debit', 25000, 12, 'Transfer to Amina N. (demo)'),
    ('withdrawal', 'debit', 15000, 8, 'Bill payment - DEMO Electricity'),
    ('deposit', 'credit', 50000, 5, 'Transfer from Demo member A'),
    ('transfer', 'debit', 65000, 2, 'Savings goal - New laptop'),
], start=1):
    add('ledger_transactions', f'demo_tx{i}', {
        'id': f'demo_tx{i}', 'userIds': [UID], 'type': typ, 'status': 'posted', 'currency': CUR, 'description': text,
        'reference': f'SPL-DEMO-{i:04d}', 'lines': [{'accountId': WALLET, 'direction': direction, 'amount': amount}], 'createdAt': days(-ago),
    })

add('kyc_applications', 'demo_kyc', {
    'id': 'demo_kyc', 'userId': UID, 'level': 'full', 'accountType': 'individual', 'status': 'approved', 'revision': 1,
    'personal': {'fullName': 'Test Customer'}, 'createdAt': days(-45), 'submittedAt': days(-44), 'decidedAt': days(-43),
})

# -- savings
GOAL = 'demo_goal'
add('savings_goals', GOAL, {
    'id': GOAL, 'name': 'New laptop', 'purpose': 'education', 'description': 'Demo savings goal', 'ownerId': UID, 'memberIds': [UID], 'invitedIds': [],
    'currency': CUR, 'targetAmount': 400000, 'savedAmount': 65000, 'deadline': days(180), 'status': 'active',
    'schedule': {'frequency': 'monthly', 'amount': 50000}, 'createdAt': days(-40),
})
add('savings_contributions', 'demo_goal_c1', {'id': 'demo_goal_c1', 'goalId': GOAL, 'userId': UID, 'amount': 15000, 'currency': CUR, 'status': 'succeeded', 'reference': 'SPS-DEMO-0001', 'createdAt': days(-35)})
add('savings_contributions', 'demo_goal_c2', {'id': 'demo_goal_c2', 'goalId': GOAL, 'userId': UID, 'amount': 50000, 'currency': CUR, 'status': 'succeeded', 'reference': 'SPS-DEMO-0002', 'createdAt': days(-2)})

# -- tontine (the two other members are fictitious, not real users)
TON, A, B = 'demo_tontine', 'demo_member_a', 'demo_member_b'
add('tontines', TON, {
    'id': TON, 'name': 'Family tontine (demo)', 'description': 'Demo tontine', 'rules': 'Pay before the due date. Demo only.', 'currency': CUR,
    'contributionAmount': 10000, 'frequency': 'monthly', 'membersLimit': 5, 'payoutOrderMethod': 'fixed', 'status': 'active', 'adminIds': [UID],
    'memberIds': [A, UID, B], 'currentCycle': 2, 'startDate': days(-25), 'nextDueAt': days(5), 'createdAt': days(-40),
})
for pos, (uid, name, role) in enumerate([(A, 'Demo member A', 'member'), (UID, 'Test Customer', 'admin'), (B, 'Demo member B', 'member')], start=1):
    add('tontine_members', f'demo_tm{pos}', {'id': f'demo_tm{pos}', 'tontineId': TON, 'userId': uid, 'displayName': name, 'role': role, 'status': 'active', 'payoutPosition': pos})
for n, (ben, due, status) in enumerate([(A, -25, 'paid'), (UID, 5, 'collecting'), (B, 35, 'upcoming')], start=1):
    add('tontine_cycles', f'demo_cycle{n}', {'id': f'demo_cycle{n}', 'tontineId': TON, 'number': n, 'dueDate': days(due), 'beneficiaryUserId': ben, 'status': status})
for i, (uid, status) in enumerate([(A, 'paid'), (UID, 'paid'), (B, 'pending')], start=1):
    add('tontine_contributions', f'demo_tc{i}', {'id': f'demo_tc{i}', 'tontineId': TON, 'cycleId': 'demo_cycle2', 'userId': uid, 'amount': 10000, 'currency': CUR, 'status': status, 'createdAt': days(-3)})
add('tontine_payouts', 'demo_payout1', {'id': 'demo_payout1', 'tontineId': TON, 'cycleNumber': 1, 'beneficiaryUserId': A, 'amount': 30000, 'currency': CUR, 'status': 'paid', 'reference': 'SPP-DEMO-0001', 'createdAt': days(-24)})

# -- loan (declining balance, 12 % a year, 6 monthly installments)
LOAN, P, N, R = 'demo_loan', 60000, 6, 0.01
pay = P * R / (1 - (1 + R) ** -N)
bal, inst = P, []
for k in range(1, N + 1):
    interest = round(bal * R)
    principal = bal if k == N else round(pay - interest)
    bal -= principal
    inst.append({'number': k, 'dueDate': days(-20 + 30 * (k - 1)), 'principal': principal, 'interest': interest, 'amount': principal + interest,
                 'amountDue': 0 if k == 1 else principal + interest, 'penalty': 0, 'status': 'paid' if k == 1 else ('due' if k == 2 else 'upcoming')})
total = sum(i['amount'] for i in inst)
outstanding = total - inst[0]['amount']
add('loan_applications', LOAN, {
    'id': LOAN, 'borrowerId': UID, 'groupId': TON, 'groupName': 'Family tontine (demo)', 'status': 'active', 'currency': CUR, 'amount': P,
    'fundedAmount': P, 'outstandingAmount': outstanding, 'durationMonths': N, 'repaymentFrequency': 'monthly', 'purpose': 'education',
    'description': 'Demo loan for a training course', 'eligibleVoterIds': [A, B], 'lenderIds': [A, B], 'votes': {'yes': 2, 'no': 0},
    'votingEndsAt': days(-45), 'createdAt': days(-50),
})
add('loan_agreements', LOAN, {
    'loanId': LOAN, 'version': 1, 'principal': P, 'currency': CUR, 'interestMethod': 'declining', 'annualInterestPercent': 12, 'fee': 1200,
    'totalRepayable': total, 'latePenaltyPercent': 5, 'terms': 'Demo agreement - not a real loan.', 'createdAt': days(-44), 'acceptedAt': days(-43),
})
add('loan_schedules', LOAN, {'loanId': LOAN, 'installments': inst})
add('loan_repayments', 'demo_repay1', {'id': 'demo_repay1', 'loanId': LOAN, 'borrowerId': UID, 'amount': inst[0]['amount'], 'currency': CUR, 'status': 'succeeded', 'reference': 'SPR-DEMO-0001', 'createdAt': days(-21)})
add('credit_assessments', LOAN, {
    'loanId': LOAN, 'borrowerId': UID, 'score': 712, 'band': 'Good', 'assessedAt': days(-48), 'factors': [
        {'label': 'Regular tontine contributions', 'impact': 'positive', 'detail': 'All contributions paid on time (demo).'},
        {'label': 'Short history', 'impact': 'negative', 'detail': 'Less than a year of activity (demo).'},
    ],
})

# -- investment (the fund is UNPUBLISHED: no catalog shows it)
FUND = 'demo_fund'
add('investment_funds', FUND, {
    'id': FUND, 'published': False, 'name': 'DEMO Money Market Fund', 'manager': 'Demo Asset Management', 'objective': 'Preserve capital with a small return (demo).',
    'description': 'Demo fund for testing the app - not a real product.', 'assetClass': 'money_market', 'riskLevel': 2, 'currency': CUR, 'minInvestment': 25000,
    'fees': {'subscriptionPercent': 2, 'managementPercent': 1, 'redemptionPercent': 0}, 'navPerUnit': 1043.0, 'navDate': days(-1), 'lockUpDays': 30,
    'settlementDays': 3, 'redemption': {'allowed': True, 'partial': True}, 'terms': 'Demo terms - not a real product.', 'termsVersion': 1,
    'performance': {'ytd': 3.1, 'oneYear': 4.3}, 'status': 'open',
})
for i in range(10):
    add('investment_valuations', f'demo_nav{i}', {'fundId': FUND, 'date': days(-90 + i * 10), 'navPerUnit': round(1000 + i * 4.8, 1)})
add('investment_holdings', f'{UID}_{FUND}', {
    'userId': UID, 'fundId': FUND, 'fundName': 'DEMO Money Market Fund', 'assetClass': 'money_market', 'currency': CUR, 'units': 100.0, 'redeemableUnits': 100.0,
    'investedAmount': 100000, 'currentValue': 104300, 'redeemableValue': 104300, 'realizedGains': 0, 'unrealizedGains': 4300, 'valuedAt': days(-1),
})
add('investment_subscriptions', 'demo_sub1', {
    'userId': UID, 'fundId': FUND, 'fundName': 'DEMO Money Market Fund', 'currency': CUR, 'amount': 102000, 'fee': 2000, 'netAmount': 100000,
    'units': 100.0, 'navPerUnit': 1000.0, 'termsVersion': 1, 'status': 'completed', 'tradeDate': days(-88), 'reference': 'SPI-DEMO-0001', 'createdAt': days(-90),
})
add('investment_transactions', 'demo_itx1', {'userId': UID, 'fundId': FUND, 'type': 'subscription', 'amount': 100000, 'units': 100.0, 'navPerUnit': 1000.0, 'currency': CUR, 'reference': 'SPI-DEMO-0001', 'createdAt': days(-88)})

# -- insurance (the product is UNPUBLISHED)
cover = [{'name': 'Hospital stays', 'limit': 2000000, 'description': 'Demo cover'}, {'name': 'Consultations', 'limit': 300000, 'description': 'Demo cover'}]
add('insurance_products', 'demo_health', {
    'id': 'demo_health', 'published': False, 'name': 'DEMO Health Essentials', 'partnerName': 'Demo Insurer', 'category': 'health', 'currency': CUR,
    'summary': 'Demo product - not a real insurance.', 'coverages': cover, 'exclusions': ['Demo exclusion'], 'deductible': 10000, 'termMonths': 12,
    'terms': 'Demo terms.', 'termsVersion': 1, 'status': 'open',
})
add('insurance_policies', 'demo_policy', {
    'userId': UID, 'quoteId': 'demo_quote1', 'productId': 'demo_health', 'productName': 'DEMO Health Essentials', 'partnerName': 'Demo Insurer', 'category': 'health',
    'policyNumber': 'DEMO-0001', 'status': 'active', 'currency': CUR, 'premium': 60000, 'frequency': 'monthly', 'installmentAmount': 5250, 'deductible': 10000,
    'coverages': cover, 'coverStart': days(-60), 'coverEnd': days(305), 'nextPremiumDue': days(10), 'autoRenew': False, 'documents': [], 'createdAt': days(-61),
})
for i, (due, status) in enumerate([(-50, 'paid'), (-20, 'paid'), (10, 'upcoming')], start=1):
    add('insurance_premiums', f'demo_prem{i}', {'userId': UID, 'policyId': 'demo_policy', 'amount': 5250, 'currency': CUR, 'dueDate': days(due), 'status': status, 'reference': f'SPN-DEMO-{i:04d}'})
add('insurance_quotes', 'demo_quote1', {
    'userId': UID, 'productId': 'demo_health', 'productName': 'DEMO Health Essentials', 'partnerName': 'Demo Insurer', 'category': 'health', 'frequency': 'monthly',
    'currency': CUR, 'premium': 60000, 'installmentAmount': 5250, 'status': 'accepted', 'policyId': 'demo_policy', 'createdAt': days(-63),
})
add('insurance_claims', 'demo_claim', {
    'userId': UID, 'policyId': 'demo_policy', 'policyNumber': 'DEMO-0001', 'productName': 'DEMO Health Essentials', 'currency': CUR, 'incidentDate': days(-12),
    'description': 'Demo claim: consultation and medicines.', 'amountClaimed': 35000, 'status': 'under_review', 'documents': [], 'createdAt': days(-10),
})

# -- transfers (the recipient and the sender are fictitious)
add('money_transfers', 'demo_transfer_out', {
    'senderId': UID, 'senderName': 'Test Customer', 'participantIds': [UID], 'channel': 'mobile_money',
    'recipient': {'operator': 'MTN Mobile Money', 'number': '+237690000000'}, 'recipientName': 'Amina N. (demo)', 'recipientVerified': True,
    'currency': CUR, 'amount': 25000, 'fee': 250, 'total': 25250, 'receiveAmount': 25000, 'note': 'Demo transfer', 'status': 'completed',
    'reference': 'SPT-DEMO-0001', 'createdAt': days(-12), 'completedAt': days(-12),
})
add('money_transfers', 'demo_transfer_in', {
    'senderId': A, 'senderName': 'Demo member A', 'recipientId': UID, 'participantIds': [A, UID], 'channel': 'internal', 'recipientName': 'Test Customer',
    'currency': CUR, 'amount': 50000, 'fee': 0, 'total': 50000, 'receiveAmount': 50000, 'note': 'Demo transfer', 'status': 'completed',
    'reference': 'SPT-DEMO-0002', 'createdAt': days(-5), 'completedAt': days(-5),
})
add('transfer_beneficiaries', 'demo_benef', {
    'userId': UID, 'channel': 'mobile_money', 'displayName': 'Amina N. (demo)', 'detail': 'MTN Mobile Money · +237690000000',
    'recipient': {'operator': 'MTN Mobile Money', 'number': '+237690000000', 'name': 'Amina N. (demo)'}, 'lastUsedAt': days(-12),
})

# -- bills (the biller is UNPUBLISHED)
add('utility_billers', 'demo_biller', {
    'published': False, 'name': 'DEMO Electricity', 'category': 'electricity', 'country': 'CM', 'currency': CUR, 'accountLabel': 'Meter number',
    'accountPattern': '\\d{11}', 'amountType': 'open', 'min': 500, 'max': 200000,
})
add('utility_payment_requests', 'demo_bill', {
    'userId': UID, 'billerId': 'demo_biller', 'billerName': 'DEMO Electricity', 'category': 'electricity', 'account': '12345678901', 'customerName': 'TEST CUSTOMER',
    'currency': CUR, 'amount': 15000, 'fee': 0, 'total': 15000, 'status': 'completed', 'reference': 'SPB-DEMO-0001', 'billerReference': 'ELEC-DEMO-77',
    'token': '1234 5678 9012 3456 7890', 'tokenLabel': 'Electricity token (demo)', 'units': '98.4 kWh', 'createdAt': days(-8), 'completedAt': days(-8),
})
add('utility_saved_accounts', 'demo_saved', {'userId': UID, 'billerId': 'demo_biller', 'billerName': 'DEMO Electricity', 'category': 'electricity', 'account': '12345678901', 'nickname': 'Home', 'lastUsedAt': days(-8)})

# -- project financing
add('financing_projects', 'demo_project', {
    'ownerId': UID, 'name': 'Demo bakery', 'sector': 'commerce', 'stage': 'growth', 'country': 'Cameroon', 'city': 'Douala',
    'description': 'Demo project: a neighbourhood bakery that wants a second oven and a delivery bike.', 'employees': 4, 'foundedYear': 2022, 'createdAt': days(-20),
})
add('financing_applications', 'demo_application', {
    'ownerId': UID, 'projectId': 'demo_project', 'projectName': 'Demo bakery', 'financingType': 'loan', 'amount': 5000000, 'currency': CUR, 'durationMonths': 24,
    'useOfFunds': 'Second oven (3 500 000), delivery bike (900 000), working capital (600 000). Demo data.', 'status': 'under_review', 'reviewerIds': [],
    'submittedAt': days(-15), 'createdAt': days(-18),
})
add('financing_reviews', 'demo_review1', {'ownerId': UID, 'applicationId': 'demo_application', 'toStatus': 'submitted', 'publicNote': 'Application received (demo).', 'at': days(-15)})
add('financing_reviews', 'demo_review2', {'ownerId': UID, 'applicationId': 'demo_application', 'toStatus': 'under_review', 'publicNote': 'A reviewer is looking at your file (demo).', 'at': days(-9)})

# -- investor preferences
add('investor_profiles', UID, {'currency': CUR, 'sectors': ['agriculture', 'technology'], 'countries': ['CM'], 'types': [], 'minTicket': 100000, 'maxTicket': 1000000, 'maxRisk': 5, 'maxHorizonMonths': 36, 'updatedAt': NOW})

# -- dashboard totals
def month_ago(k):
    y, m = NOW.year, NOW.month - k
    while m < 1:
        y, m = y - 1, m + 12
    return f'{y}-{m:02d}'


MONTHLY = [
    {'month': month_ago(k), 'moneyIn': m_in, 'moneyOut': m_out}
    for k, (m_in, m_out) in reversed(list(enumerate([(350000, 105000), (120000, 90000), (80000, 60000), (150000, 140000), (60000, 45000), (90000, 70000)])))
]
if '--fix-monthly' in sys.argv:
    st, body = request('PATCH', f'{BASE}/finance_summaries/{UID}?updateMask.fieldPaths=monthly&key={KEY}', {'fields': {'monthly': enc(MONTHLY)}})
    print(f"monthly: {[m['month'] for m in MONTHLY]} -> {'patched' if st == 200 else error(body)}")
    sys.exit(0 if st == 200 else 1)

add('finance_summaries', UID, {
    'currency': CUR, 'updatedAt': NOW,
    'investments': {'investedCapital': 100000, 'currentValuation': 104300, 'realizedGains': 0, 'unrealizedGains': 4300, 'allocation': {'money_market': 104300}},
    'savings': {'activeGoals': 1, 'savedAmount': 65000, 'targetAmount': 400000},
    'tontines': {'active': 1, 'nextContributionAmount': 10000, 'nextContributionDate': days(5), 'nextPayoutDate': days(5)},
    'loans': {'borrowedOutstanding': outstanding, 'lentOutstanding': 0, 'nextRepaymentAmount': inst[1]['amount'], 'nextRepaymentDate': inst[1]['dueDate'], 'overdueCount': 0},
    'insurance': {'activePolicies': 1, 'nextRenewalDate': days(305), 'openClaims': 1},
    'payments': {'last30Days': {'deposits': 350000, 'withdrawals': 15000, 'transfers': 90000, 'cardPayments': 0, 'billPayments': 15000}},
    'monthly': MONTHLY,
})

KYC_FIELDS = {'kycStatus': 'approved', 'kycLevel': 'full', 'demoKyc': True}

# ------------------------------------------------------------------- run
mode = 'DELETE' if DELETE else ('APPLY' if APPLY else 'DRY RUN (add --apply to write, --delete to remove)')
print(f'{mode} for user {UID}')

user = get(f'users/{UID}')
if user is None:
    sys.exit('No users/{uid} document: check the uid.')
fields = user.get('fields', {})
mask = '&'.join(f'updateMask.fieldPaths={k}' for k in KYC_FIELDS)
if SET_REGION:
    print(f' - users/{{uid}}: left as is (only the demo records get regionId={REGION})')
elif DELETE:
    if fields.get('demoKyc', {}).get('booleanValue'):
        status, body = request('PATCH', f'{BASE}/users/{UID}?{mask}&key={KEY}', {'fields': {}})
        print(' - users/{uid} kycStatus/kycLevel:', 'removed' if status == 200 else f'FAILED ({status}): {error(body)}')
    else:
        print(' - users/{uid}: verification not set by this script, left as is')
elif 'kycLevel' in fields and not fields.get('demoKyc', {}).get('booleanValue'):
    print(' - users/{uid}: already has a real verification, left as is')
elif APPLY:
    status, body = request('PATCH', f'{BASE}/users/{UID}?{mask}&key={KEY}', {'fields': {k: enc(v) for k, v in KYC_FIELDS.items()}})
    print(' - users/{uid} kycStatus=approved, kycLevel=full:', 'set' if status == 200 else f'FAILED ({status}): {error(body)}')
else:
    print(' - users/{uid}: would set kycStatus=approved, kycLevel=full (only these fields)')

if SET_REGION:
    # Only `regionId`, only on an existing demo record (precondition: it exists).
    done = failed = 0
    for collection, doc_id, _ in DOCS:
        if collection not in REGION_COLLECTIONS:
            continue
        path = f'{collection}/{doc_id}'
        existing = get(path)
        fields = (existing or {}).get('fields', {})
        if not fields.get('demo', {}).get('booleanValue'):
            print(f' - {path}: {"missing" if existing is None else "not a demo record"}, skipped')
            continue
        now = fields.get('regionId', {}).get('stringValue')
        if now == REGION:
            print(f' - {path}: regionId already {REGION}')
            continue
        if not APPLY:
            print(f' - {path}: would set regionId={REGION} (now {now or "none"})')
            continue
        status, body = request('PATCH', f'{BASE}/{path}?updateMask.fieldPaths=regionId&currentDocument.exists=true&key={KEY}', {'fields': {'regionId': enc(REGION)}})
        if status == 200:
            done += 1
            print(f' - {path}: regionId={REGION}')
        else:
            failed += 1
            print(f' - {path}: FAILED ({status}): {error(body)}')
    if APPLY:
        print(f'Done: {done} updated, {failed} failed.')
    sys.exit(0)

created = skipped = failed = 0
for collection, doc_id, data in DOCS:
    path = f'{collection}/{doc_id}'
    existing = get(path)
    if DELETE:
        if existing and existing.get('fields', {}).get('demo', {}).get('booleanValue'):
            status, body = request('DELETE', f'{BASE}/{path}?key={KEY}')
            print(f' - {path}:', 'deleted' if status == 200 else f'FAILED ({status}): {error(body)}')
        continue
    if existing:
        skipped += 1
        print(f' - {path}: already exists, skipped')
        continue
    if not APPLY:
        print(f' - {path}: would create')
        continue
    status, body = request('POST', f'{BASE}/{collection}?documentId={urllib.parse.quote(doc_id)}&key={KEY}', {'fields': {k: enc(v) for k, v in data.items()}})
    if status == 200:
        created += 1
    else:
        failed += 1
        print(f' - {path}: FAILED ({status}): {error(body)}')
if APPLY:
    print(f'Done: {created} created, {skipped} skipped, {failed} failed.')
