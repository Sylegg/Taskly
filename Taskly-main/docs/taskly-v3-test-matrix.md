# Customer V3 verification — 2026-10-09

| Check | Actual result | Evidence |
|---|---|---|
| flutter analyze | PASS: no issues | Tool output after final formatting |
| flutter test | PASS: 62 tests | customer-flutter-test.log |
| backend gradlew.bat test --no-daemon | PASS: 37 tests, 0 failures/errors/skips | backend/build/test-results/test/TEST-*.xml |
| flutter build apk --debug --flavor customer | PASS | customer-apk-build.log; app-customer-debug.apk |
| Live Customer/Partner API/device E2E | NOT RUN | Core task/payment/assignment APIs absent |
| Physical device smoke test / production DB migration | NOT RUN | No device/deployment performed |

New backend suite `BookingDraftControllerTest` contains 11 tests: public schema access; unauthenticated 401 and non-Customer 403; each of eight schemas persists valid partial details, rejects unknown fields and inactive services, isolates users and prevents another user's deletion; invalid quantity and foreign address rejection. Admin permission checks, server quote calculation, owner isolation, repricing invalidation and expiry also passed. Flyway V8/V9 ran successfully against test H2 in PostgreSQL mode. Real PostgreSQL execution is not claimed.

New Flutter suite `customer_v3_booking_test.dart` verifies empty/negative/fractional quantity and invalid-choice validation, server draft restoration, 360dp rendering, edited fields saved to the authenticated API, visible server save errors without a success message, and review-step rendering of a server quote/TTL. Existing account API test now supplies actual catalogue data. Home tests cover all sections at 360/390/430dp, loading/error/offline, safe areas and enlarged text.

Existing native authentication tests passed. Customer/Partner demo journey tests also passed; those tests use mock repositories and do not establish live task/payment readiness. No claim of eight complete live booking happy/error E2Es is made.

Earlier failures included pre-existing FavoritePartnerCard overflow and lazy-list test visibility after adding detailed error text. Both were corrected before final passing runs. Backend wrappers print deprecated API warnings but Java compilation/tests succeeded.
