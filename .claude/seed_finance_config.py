# Creates the admin-level Spideli Finance configuration in the live Firestore
# (project spideli-870b0), as listed in .claude/FINANCE-APP-CONTRACT.md:
#   - platform_settings/kyc, /savings, /tontines, /lending  (sections 2.1, 8.1, 9.1, 11.1)
#   - dynamic_notification templates                        (sections 6, 10, 11.5)
# CREATE-ONLY: a document or template type that already exists is skipped,
# never overwritten. DRY RUN by default; writes only with --apply.
#
#   python3 .claude/seed_finance_config.py            # show what it would create
#   python3 .claude/seed_finance_config.py --apply    # create it
import datetime
import json
import random
import string
import sys
import urllib.error
import urllib.parse
import urllib.request

KEY = 'AIzaSyDzPw53B4IC7ghgwjSdng4FmBg860V9zPs'  # the apps' public web API key
BASE = 'https://firestore.googleapis.com/v1/projects/spideli-870b0/databases/(default)/documents'
APPLY = '--apply' in sys.argv

KYC = {
    'documentTypes': {
        'national_id': {'sides': ['front', 'back']},
        'passport': {'sides': ['front']},
        'selfie': {'sides': ['front']},
        'proof_of_address': {'sides': ['front']},
        'business_registration': {'sides': ['front']},
    },
    'levels': {
        'basic': {'accountTypes': ['individual'], 'requiredDocuments': [{'anyOf': ['national_id', 'passport']}, {'anyOf': ['selfie']}]},
        'full': {'accountTypes': ['individual'], 'requiredDocuments': [{'anyOf': ['national_id', 'passport']}, {'anyOf': ['selfie']}, {'anyOf': ['proof_of_address']}]},
        'business': {'accountTypes': ['business'], 'requiredDocuments': [{'anyOf': ['national_id', 'passport']}, {'anyOf': ['business_registration']}]},
    },
    'allowedContentTypes': ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
    'maxFileBytes': 10 * 1024 * 1024,
}

SAVINGS = {
    'purposes': ['real_estate', 'education', 'travel', 'healthcare', 'business', 'other'],
    'currencies': ['XAF'],
    'frequencies': ['weekly', 'biweekly', 'monthly'],
    'groupGoals': True,
    'maxMembers': 10,
    'earlyWithdrawal': {'allowed': True},
    'paymentMethods': ['wallet', 'mobile_money', 'wave'],
}

TONTINES = {
    'currencies': ['XAF'],
    'frequencies': ['weekly', 'biweekly', 'monthly'],
    'minMembers': 3,
    'maxMembers': 30,
    'payoutOrderMethods': ['fixed', 'random'],
    'paymentMethods': ['wallet', 'mobile_money', 'wave'],
    'minContribution': {'XAF': 1000},
}

LENDING = {
    'currencies': ['XAF'],
    'minAmount': {'XAF': 10000},
    'maxAmount': {'XAF': 1000000},
    'durationsMonths': [3, 6, 12],
    'repaymentFrequencies': ['weekly', 'monthly'],
    'purposes': ['business', 'education', 'healthcare', 'real_estate', 'other'],
    'interest': {'method': 'declining', 'annualPercent': 12},
    'feePercent': 2,
    'latePenaltyPercent': 5,
    'voting': {'quorumPercent': 50, 'approvalPercent': 60, 'durationHours': 48},
    'paymentMethods': ['wallet', 'mobile_money', 'wave'],
}

SETTINGS = {'kyc': KYC, 'savings': SAVINGS, 'tontines': TONTINES, 'lending': LENDING}

TEMPLATES = [
    ('kyc_submitted', 'Verification received', 'We received your documents. Our team will review them shortly.'),
    ('kyc_additional_info_required', 'More information needed', 'Please update your identity verification: {reason}'),
    ('kyc_approved', 'Identity verified', 'Your identity is verified. You can now use Spideli Finance services.'),
    ('kyc_rejected', 'Verification not approved', 'Your identity verification was not approved: {reason}. You can submit it again.'),
    ('savings_invite', 'Savings goal invitation', '{inviterName} invited you to save together for "{goalName}".'),
    ('savings_contribution_received', 'Savings received', '{amount} was added to "{goalName}".'),
    ('savings_contribution_failed', 'Savings payment failed', 'Your payment of {amount} to "{goalName}" did not go through.'),
    ('savings_contribution_due', 'Savings reminder', 'Your contribution of {amount} to "{goalName}" is due on {dueDate}.'),
    ('savings_goal_completed', 'Goal reached', 'Congratulations! "{goalName}" has reached its target.'),
    ('savings_withdrawal_completed', 'Withdrawal completed', '{amount} was withdrawn from "{goalName}".'),
    ('savings_withdrawal_rejected', 'Withdrawal not possible', 'Your withdrawal of {amount} from "{goalName}" was refused: {reason}'),
    ('tontine_invite', 'Tontine invitation', '{inviterName} invited you to join the tontine "{tontineName}".'),
    ('tontine_started', 'Tontine started', 'The tontine "{tontineName}" has started. First contribution due on {firstDueDate}.'),
    ('tontine_contribution_due', 'Tontine reminder', 'Your contribution of {amount} to "{tontineName}" is due on {dueDate}.'),
    ('tontine_contribution_received', 'Contribution received', 'Your contribution of {amount} to "{tontineName}" was received.'),
    ('tontine_contribution_overdue', 'Contribution overdue', 'Your contribution of {amount} to "{tontineName}" is overdue.'),
    ('tontine_payout_pending_approval', 'Payout to approve', 'The payout of {amount} to {beneficiaryName} in "{tontineName}" is waiting for your approval.'),
    ('tontine_payout_paid', 'Tontine payout', '{amount} was paid out from "{tontineName}".'),
    ('tontine_dispute_raised', 'New dispute', 'A dispute was raised in "{tontineName}": {subject}'),
    ('loan_submitted', 'Loan request received', 'Your loan request of {amount} was received. We will review it shortly.'),
    ('loan_vote_requested', 'Vote on a loan request', '{borrowerName} asks {groupName} for a loan of {amount}. Vote before {votingEndsAt}.'),
    ('loan_approved', 'Loan approved', 'Your loan request of {amount} was approved by your group.'),
    ('loan_rejected', 'Loan not approved', 'Your loan request of {amount} was not approved: {reason}'),
    ('loan_funding_open', 'Loan open for funding', '{borrowerName} in {groupName} needs {amount}. You can lend part of it.'),
    ('loan_funded', 'Loan fully funded', 'Your loan of {amount} is fully funded. Please accept the agreement.'),
    ('loan_agreement_ready', 'Agreement to accept', 'Your loan agreement for {amount} is ready. Read and accept it to receive the money.'),
    ('loan_disbursed', 'Loan paid out', 'The loan of {amount} was paid out.'),
    ('loan_repayment_due', 'Repayment reminder', 'Your loan repayment of {amount} is due on {dueDate}.'),
    ('loan_repayment_received', 'Repayment received', 'Your repayment of {amount} was received.'),
    ('loan_repayment_overdue', 'Repayment overdue', 'Your loan repayment of {amount} is overdue.'),
    ('loan_lender_repayment', 'Repayment received', 'You received {amount} from {borrowerName}\'s loan repayment.'),
    ('loan_repaid', 'Loan repaid', 'The loan of {amount} is fully repaid.'),
]
# The admin panel groups templates by service_type; account-level customer
# templates already use this group.
SERVICE_TYPE = 'Multivendor Delivery Service'


def enc(v):
    if isinstance(v, bool):
        return {'booleanValue': v}
    if isinstance(v, int):
        return {'integerValue': str(v)}
    if isinstance(v, str):
        return {'stringValue': v}
    if isinstance(v, datetime.datetime):
        return {'timestampValue': v.strftime('%Y-%m-%dT%H:%M:%S.%fZ')}
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
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, json.load(e)


def exists(path):
    return request('GET', f'{BASE}/{path}?key={KEY}')[0] == 200


def template_types():
    status, body = request('GET', f'{BASE}/dynamic_notification?key={KEY}&pageSize=500')
    if status != 200:
        sys.exit(f'Could not read dynamic_notification: {body}')
    return {d['fields'].get('type', {}).get('stringValue') for d in body.get('documents', [])}


def create(collection, doc_id, data):
    url = f'{BASE}/{collection}?documentId={urllib.parse.quote(doc_id)}&key={KEY}'
    status, body = request('POST', url, {'fields': {k: enc(v) for k, v in data.items()}})
    return 'created' if status == 200 else f'FAILED ({status}): {body.get("error", {}).get("message", body)}'


now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
print('APPLY' if APPLY else 'DRY RUN (add --apply to write)')

for doc_id, data in SETTINGS.items():
    if exists(f'platform_settings/{doc_id}'):
        print(f' - platform_settings/{doc_id}: already exists, skipped')
    else:
        print(f' - platform_settings/{doc_id}:', create('platform_settings', doc_id, {**data, 'createdAt': now}) if APPLY else 'would create')

have = template_types()
for type_, subject, message in TEMPLATES:
    if type_ in have:
        print(f' - dynamic_notification {type_}: already exists, skipped')
        continue
    doc_id = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(20))
    data = {'id': doc_id, 'type': type_, 'subject': subject, 'message': message, 'service_type': SERVICE_TYPE, 'createdAt': now}
    print(f' - dynamic_notification {type_}:', create('dynamic_notification', doc_id, data) if APPLY else 'would create')
