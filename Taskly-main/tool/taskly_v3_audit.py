"""Generate a reviewable Customer-first route audit from the provided master prompt."""
from pathlib import Path
import re
import shutil

root = Path(__file__).resolve().parent.parent
reference = root / 'design-reference'
reference.mkdir(exist_ok=True)
for name in ['TASKLY_ULTIMATE_MOBILE_INTERACTIVE_V3.html', 'TASKLY_ULTIMATE_V3_FULL_FLUTTER_BUILD_MASTER_PROMPT.md']:
    source = root.parent / name
    if source.exists():
        shutil.copyfile(source, reference / name)
prompt = (reference / 'TASKLY_ULTIMATE_V3_FULL_FLUTTER_BUILD_MASTER_PROMPT.md').read_text(encoding='utf-8')
section = prompt.split('# PHẦN C')[1].split('# PHẦN D')[0]
rows = re.findall(r'^\| `([A-Za-z]+)` \| ([^|]+) \| ([^|]+) \| ([^|]+) \|', section, re.M)
assert len(rows) == 94, len(rows)
real = {
    'splash': ('EXISTS', 'TasklyEntry / Session.restore', 'auth/mobile/refresh; users/me', 'session_test.dart'),
    'login': ('EXISTS / PROTECTED', 'AuthPage', 'auth/mobile/login; auth/mobile/login-phone', 'phone_login_test.dart'),
    'register': ('EXISTS / PROTECTED', 'AuthPage', 'auth/register', 'api_test.dart'),
    'emailOtp': ('EXISTS', 'AuthPage OTP', 'auth/verify-otp; auth/resend-otp', 'Backend AuthSecurityTest'),
    'forgot': ('EXISTS', 'AuthPage recovery', 'auth/forgot-password', 'Backend AuthSecurityTest'),
    'resetOtp': ('PARTIAL', 'AuthPage reset flow (combined)', 'auth/reset-password', 'Backend AuthSecurityTest'),
    'newPassword': ('EXISTS', 'AuthPage reset', 'auth/reset-password', 'Backend AuthSecurityTest'),
    'home': ('PARTIAL', 'PageId.home / TaskLyCustomerHome', 'public/services; users/me/*', 'home_design_test.dart'),
    'services': ('EXISTS', 'PageId.services / serviceList', 'public/services', 'account_api_test.dart'),
    'serviceDetail': ('PARTIAL', 'PageId.serviceDetail / serviceDetail', 'public/services (loaded catalogue)', 'account_api_test.dart'),
    'search': ('PARTIAL', 'PageId.services / local catalogue search', 'public/services', 'home_design_test.dart'),
    'booking': ('PARTIAL', 'PageId.create / CustomerBooking', 'public/booking-schemas; users/me/booking-draft', 'customer_v3_booking_test.dart; BookingDraftControllerTest'),
    'quote': ('EXISTS', 'CustomerBooking review / server quote', 'POST users/me/booking-quotes', 'BookingDraftControllerTest; customer_v3_booking_test.dart'),
    'priceBreakdown': ('EXISTS', 'CustomerBooking review / fee breakdown and expiry', 'GET users/me/booking-quotes/{id}', 'BookingDraftControllerTest; customer_v3_booking_test.dart'),
    'addresses': ('EXISTS', 'PageId.addresses / address list', 'users/me/addresses', 'Backend user tests'),
    'addressEdit': ('EXISTS', 'Address editor bottom sheet', 'users/me/addresses', 'Backend user tests'),
    'account': ('PARTIAL', 'PageId.profile / accountScreens', 'users/me; users/me/statistics', 'account_api_test.dart'),
    'profileEdit': ('EXISTS', 'PageId.editProfile', 'PATCH users/me/profile', 'account_api_test.dart'),
    'notificationPrefs': ('EXISTS', 'PageId.settings', 'users/me/settings', 'account_api_test.dart'),
    'settings': ('PARTIAL', 'PageId.settings', 'users/me/settings', 'account_api_test.dart'),
    'review': ('PARTIAL', 'PageId.rating (task lifecycle unavailable)', 'POST users/me/reviews/{taskId}', 'AccountControllerTest'),
    'support': ('PARTIAL', 'PageId.help / static help', 'No support ticket API', 'customer_journey_test.dart (demo only)'),
    'about': ('PARTIAL', 'PageId.help / static terms', 'Account deletion API missing', 'customer_journey_test.dart (demo only)'),
}
mock = {'activities':'tasks','taskDetail':'task','taskEdit':'task','cancelTask':'task',
    'matching':'recommendations','completeConfirm':'payment','bookAgain':'create','aiDraft':'ai',
    'inbox':'messages','chat':'chat','notifications':'notifications','ticketCreate':'complaint',
    'dispute':'complaint','disputeDetail':'complaintStatus'}
debug = {'testGuide','developer','screenIndex','uiStates','diagnostics'}
partner = {r for r, _, _, _ in rows[48:67]} | {'availabilityPro','partnerTraining','partnerAgreement','bankAccounts','bankAdd','payoutDetail'}
# Use source section headings instead of relying solely on row offsets.
partner = set()
group = ''
for line in section.splitlines():
    if line.startswith('## '): group = line
    match = re.match(r'^\| `([A-Za-z]+)`', line)
    if match and 'Partner' in group: partner.add(match.group(1))
lines = ['# TaskLy V3 route mapping — Customer first', '',
    'Source: the 94 routes in the supplied master prompt, cross-checked against SCREEN_GROUPS in the HTML. Date: 2026-10-09.', '',
    'EXISTS means an existing feature/API, not full beta certification. PARTIAL and MISSING remain open. Demo-only UI tests do not establish live API support. Partner is OUT_OF_SCOPE for this Customer-first change.', '',
    '| HTML route | Screen | Status | Flutter mapping | API (prefix /api/v1/) | Evidence / limitation |',
    '|---|---|---|---|---|---|']
for route, name, behavior, source in rows:
    if route in real: status, widget, api, evidence = real[route]
    elif route in partner: status, widget, api, evidence = 'OUT_OF_SCOPE', 'Existing Partner UI / later phase', 'Not modified', 'Customer requested first'
    elif route in debug: status, widget, api, evidence = 'OUT_OF_SCOPE', 'Dev only; no release route', 'None', 'No production demo controls'
    elif route in mock: status, widget, api, evidence = 'PARTIAL', 'PageId.'+mock[route]+' (existing demo UI)', 'Missing or guarded unavailable', 'No live E2E; explicit API gap'
    else: status, widget, api, evidence = 'MISSING', 'No dedicated production route', 'Missing', 'See API gaps; not claimed implemented'
    lines.append(f'| `{route}` | {name.strip()} | {status} | {widget} | {api} | {evidence} |')
(root/'docs/taskly-v3-route-mapping.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
print(f'Mapped {len(rows)} reference routes; copied the two source files into design-reference/.')
