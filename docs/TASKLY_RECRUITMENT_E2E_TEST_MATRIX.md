# Recruitment acceptance matrix — 32 cases

2026-10-09. PASS below means the specified automated layer passed, not three-application device E2E. PARTIAL means code or regression coverage exists but the full scenario is not certified. Main backend evidence: `backend/src/test/java/com/taskly/recruitment/RecruitmentIntegrationTest.java` (MockMvc/H2, persisted records). Flutter: `test/recruitment_shell_test.dart`, existing recruitment domain and Customer/auth/Tasker journey tests. Admin: Node regression tests and production build, not browser E2E.

| # | Scenario | Evidence / actual scope | Status |
|---|---|---|---|
| 1 | New account, four tabs, no accept | Flutter recruitment shell API/widget test, backend non-ACTIVE 403 | PASS automated |
| 2 | Missing name/province | Flutter blank form validation and backend incomplete submission | PASS automated |
| 3 | Area closed → waitlist, no KYC | Backend state guards; complete waitlist UI case still needed | PARTIAL |
| 4 | Area/service persisted | Registration/save/submit/reload API+DB test | PASS automated |
| 5 | 20 questions/4 options/no answer leak | Exam API snapshot test | PASS automated |
| 6 | Expire/submit once | Server deadlines/idempotent submission; mobile deadline/offline UI test outstanding | PARTIAL |
| 7 | Failure/retry limits | Real API test: two failed attempts, remaining0, review topics and third attempt blocked; mobile timer QA pending | PARTIAL |
| 8 | Edit bank retains attempt | Exam API+DB snapshot test | PASS automated |
| 9 | One lesson cannot unlock all | Academy integration progress test | PASS automated |
| 10 | Insufficient watch/quiz | Server continuous-time/quiz guards exercised | PASS automated |
| 11 | All lessons complete | Academy test and full service flow A | PASS automated |
| 12 | Required agreements | Current terms/consent guards; manual unchecked UI QA pending | PARTIAL |
| 13 | Missing/invalid KYC | Flutter private multipart upload and Admin CLEAN-only preview implemented; unsafe/missing evidence approval blocked in integration test; scanner integration/device upload pending | PARTIAL |
| 14 | Changes retain achievements | Preliminary decision/retry test; exact field/evidence revision UI incomplete | PARTIAL |
| 15 | Preliminary unlocks uniform, not jobs | Uniform prereq test + APPPROVED/non-ACTIVE job denial | PASS automated |
| 16 | Three live packages/price/stock | Repeatable development seed + catalog/version code; new cross-app UI test pending | PARTIAL |
| 17 | Online sandbox failure | Integration asserts simulated failure leaves uniform_resolved false; subsequent success, exchange/handover/refund stocks and role guards verified | PARTIAL |
| 18 | Office payment remains pending | Uniform integration test: staff confirm/idempotent, no self-payment | PASS automated |
| 19 | Cancel/change/full slot | Full slot test, cancel API; concurrency/cancel UI QA pending | PARTIAL |
| 20 | Check-in/receipt/original returned | Integration requires original-return confirmation; scoped receipt API tested | PASS automated |
| 21 | Missing physical docs/resubmit | Backend integration: missing receipt→ACTION_REQUIRED→rebook→complete receipt, qualifications preserved; device UI QA pending | PARTIAL |
| 22 | SLA anchored to valid receipt | SLA working-hour/calendar API plus weekend, holiday, before-opening and24-hour boundary tests; automatic escalation not implemented | PARTIAL |
| 23 | Notifications/email retry | IN_APP delivered; template snapshot + FAILED→SIMULATED manual retry integration tested; real provider unavailable | PARTIAL |
| 24 | Approved insufficient activation | Integration denies missing selections; full flow activates only after availability | PASS automated |
| 25 | ACTIVE only, suspend blocks | Real tasks feed/accept and suspend integration tests | PASS automated |
| 26 | Role/private files | Finance review 403, CLEAN-only signed read unit tests, audited KYC read code | PARTIAL |
| 27 | Audit actors/actions | Decision/payment/config audit code; comprehensive action audit assertions pending | PARTIAL |
| 28 | Reload/offline/idempotency | Registration reload, exam snapshot, office payment retry, Flutter offline regressions | PARTIAL |
| 29 | Reject/appeal | Appeal API integration: unauthorized 403, reopen→PRELIMINARY_REVIEW, no job grant | PASS automated |
| 30 | 320/375/430/accessibility | Registration widget tests320/375/430 pass; screenreader/Admin keyboard/reduced-motion/device QA pending | PARTIAL |
| 31 | State guards/idempotency | Registration/exam/officepayment/accept/appeal tests, full concurrent transition matrix pending | PARTIAL |
| 32 | Admin→same backend→Flutter | Actual shared API architecture + reload test + resumed polling; browser/device integration not executed | PARTIAL |

## Mandatory combined flows

- A: backend service/DB integration passes registration→exam→Academy→terms→DEMO KYC→existing verification approval→preliminary→WAIVED uniform→office→valid receipt→final→activation→actual CustomerTask assignment. It uses H2 and a single free package fixture; three-package paid UI flow on PostgreSQL remains unverified.
- B: achievements preserved; amendment route now retains existing service/area qualification and prevents physical supplementation from incorrectly returning to preliminary review. Full exact-field/evidence revision test outstanding.
- C/D: exam snapshot and training watching/quiz guards automated; mobile video player and offline timer require device QA.
- E: stock/pending office confirmation automated; sandbox failure/exchange/handover/refund API and DB integration now verified; full browser/device/payment UI acceptance pending.
- F: suspension and appeal reopening automated; SMTP currently fails, EMAIL mock retries remain SIMULATED; real sender unavailable.
- G: Flutter existing Customer/auth/Tasker journey tests pass; authenticated Partner now reuses task activity/history/chat and guarded actual lifecycle API; complete device execution still unverified.

No real identity images/numbers, payment charges or externally sent recruitment email were used.




Latest validation: Backend104 PASS; Flutter97 PASS plus analyze/Partner x64 APK; Admin21 PASS plus type checking/build. Local PostgreSQL migration29 and two append-only Audit guards verified. This matrix remains layer-specific; it is not proof that all32 three-app E2E cases passed.