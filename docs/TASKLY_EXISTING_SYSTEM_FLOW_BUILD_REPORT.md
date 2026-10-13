# TaskLy — fullstack recruitment implementation evidence

Updated 2026-10-09. Requirements: `TASKLY_PARTNER_14_PHASES_ONE_SHOT_EXISTING_FULLSTACK_FLOW.md`, read in full. This report records implemented code and acceptance gaps; it does not certify all 14 phases complete.

## Integration

Existing Spring Boot auth/users/roles, terms/consents, private KYC/storage, tasks/history/chat are reused. Next Admin keeps its shell, login/cookie session and same-origin proxy. Flutter keeps Login/Register, Customer and Android flavors. The authenticated Partner uses Session and real `/api/v1/partner/**` APIs; Admin uses `/api/v1/admin/recruitment/**` against the same backend/database. No new project, JSON import bridge or mock repository is used as the live recruitment source. Partner polls while resumed every 30 seconds with backoff/manual refresh; this is not realtime synchronization.

## Required phase evidence

Paths below are relative to this workspace; the complete file inventory is `TASKLY_RECRUITMENT_CHANGED_FILES.md`.

| Phase | Status | Changed files / actual implementation | Test evidence | Remaining acceptance gaps |
|---|---|---|---|---|
| 00 | DONE | Existing-system audit, reuse/add mapping and inventory; all three sources inspected | Existing routes/tables/auth and baseline checks examined | — |
| 01 | PARTIAL | `backend/src/main/java/com/taskly/recruitment/RecruitmentService.java`, DTO/controller; migrations V19–V29, PostgreSQL Java migration V28 | DB/API integration, optimistic versions, request hashes, quota locks; local PostgreSQL persisted fixtures | Complete transition/concurrency/retention coverage |
| 02 | PARTIAL | `Taskly-main/lib/features/partner/recruitment_shell.dart`, `partner_account.dart`, `partner_benefits.dart`, `main.dart`, `core/theme.dart` | Exact Công việc/Hộp thư/Phúc lợi/Tài khoản; registration 320/375/430 tests; profile PATCH test | Bank/payout/deactivation/support and full device/accessibility QA |
| 03 | PARTIAL | RecruitmentService area/quota/page API, `RecruitmentDashboardController.java`, `frondend/src/components/RecruitmentAdmin.tsx` | Capacity1 waitlists second applicant; masked paginated queue, filters/RBAC/escaped query; DB-wide aggregates | Date filters/export and concurrent load tests; browser↔device acceptance |
| 04 | PARTIAL | RecruitmentExamService/Controller, RecruitmentExamAdmin, `recruitment_exam.dart` | 20×4 server snapshot/shuffle/scoring; no answer leak; bank edits safe; daily retry limit, remaining attempts/review topics | Service-weighted bank/tags/import and mobile deadline/offline boundary tests |
| 05 | PARTIAL | RecruitmentTrainingService/Controller, RecruitmentAcademyAdmin, `recruitment_academy.dart` | Continuous-time watching, sequential mandatory lessons/quiz; changed lesson version blocks final approval/activation/jobs; Academy remains reachable | Service-specific courses/certificates, seven configured videos/subtitles and configurable retake policy |
| 06 | PARTIAL | RecruitmentReviewService/Controller, VerificationService, PrivateObjectStorageService, RecruitmentKycAdmin, `recruitment_identity.dart`, `auth/api.dart` | Versioned terms/consents; explicit dev-only DEMO metadata; real private multipart upload with size/magic checks; KYC approval/signing requires CLEAN; audited preview | Scanner/provider unconnected; retention/withdrawal controls, real-device upload QA |
| 07 | PARTIAL | RecruitmentReviewService, RecruitmentAdmin review popup, shell amendments/notifications | Required reasons/changes, request idempotency, preserved exam/training; physical supplements cannot re-enter preliminary stage | Exact field/evidence revision history and full cross-app flow B |
| 08 | PARTIAL | RecruitmentUniformService/Controller, V23/V26, RecruitmentConfigAdmin/ReceptionAdmin, `recruitment_followup.dart` | Three repeatable dev packages; frozen prices/stock; online DEMO failure/success, AT_OFFICE confirm; exchange/handover/refund stock and retry tests | Partner adjustment requests, package images/items, stress tests; real payments deliberately not enabled |
| 09 | PARTIAL | RecruitmentOfficeService/Controller, V24, Reception/Config Admin, followup receipts | Slot capacity/check-in/original return; scoped receipts; same receive retry returns original receipt, changed payload409; missing→rebook→complete preserves qualifications; ACTIVE cannot rewind onboarding | QR rendering, no-show and complete browser/device appointment QA |
| 10 | PARTIAL | RecruitmentActivation/Communications/Sla services/controllers; V25/V29; Oversight/Communications/Sla Admin; followup SLA | Final prerequisites/current KYC/terms/training; appeals; immutable notification snapshots/mock failed retry; weekday/hour/holiday SLA24–48 with unit/integration tests | Automated escalation/reminders/preferences; real SMTP credentials unavailable |
| 11 | PARTIAL | RecruitmentActivationService, followup + shared `task_activity.dart` | ACTIVE-only real task feed/accept, service/city/full-duration matching; assignment/lifecycle/idempotency/chat API integration; rejected KYC or updated training blocks jobs | Service certificates, online/offline/decline/evidence/no-show/dispute/payout business rules |
| 12 | PARTIAL | SecurityConfig, scoped Admin role/session/proxy; V28 Audit append-only triggers; private-read audit; themes/loading/retry | Staff isolation403, signed read CLEAN tests; PostgreSQL audit write rollback test PASS; Customer/Auth regressions | Comprehensive retention/PII/concurrent state/accessibility matrix; DB-owner DDL protection is not claimed |
| 13 | PARTIAL | Integration/widget/unit tests, restart/count scripts, this report and32-case matrix | Backend104 PASS; Flutter97 PASS + analyze/APK; Admin21 PASS + lint/build | All32 browser/device acceptance cases and complete PostgreSQL Web↔Mobile E2E not executed |

## Verification actually completed

- Backend Java21: `gradlew.bat test bootJar --console=plain` PASS. JUnit XML totals104, failures0, errors0, skipped0. Recruitment uses H2/MockMvc integration and pure SLA tests; this does not prove all PostgreSQL concurrency/mobile scenarios.
- Flutter: analyze no issues;97 tests PASS, including Customer/Auth/legacy Tasker regressions, responsive onboarding and live Partner task/profile/multipart tests. Partner debug Android x64 APK built successfully at `Taskly-main/build/app/outputs/flutter-apk/app-partner-debug.apk`. Latest APK has not been installed or launched for full device acceptance.
- Admin: `npm run lint`, `npm test`, `npm run build` PASS;21 Node regression tests. Lint script is TypeScript type checking; these are not browser tests of every new CMS screen.
- Local PostgreSQL:15 DEMO queue applicants,20 DEMO questions,3 DEMO uniform packages verified. Migration28 append-only Audit triggers enabled; no-op UPDATE was rejected with SQLStateP0001 and rolled back. Backend restarted PID2424; migration29 applied successfully in PostgreSQL. The audit write rollback check passed again after restart.
- Full backend service flow uses a normally registered fictional account: registration→20-question exam→Academy→five terms→DEMO KYC→existing verification approval→preliminary→WAIVED uniform→office/receipt→final→activation→real CustomerTask assignment→four lifecycle transitions→shared chat visible to Customer. This is automated backend/H2 evidence, not a three-app device E2E.
- No real identity numbers/images, payment charges or recruitment emails were used.

## Run and safe configuration

From `backend`, set JAVA_HOME to `C:\Program Files\Java\jdk-21.0.10`, then run `gradlew.bat test bootJar --console=plain`. Existing `backend/scripts/restart-current-backend.ps1 -SkipBuild` reads local .env internally and starts an immutable runtime JAR on8080. Credentials are never printed.

From `frondend`: `npm run lint`, `npm test`, `npm run build`; `npm run dev` serves3000. Next dev/production output remains separated. Existing login is retained; recruitment staff get only scoped recruitment capabilities.

From `Taskly-main`: `flutter analyze --no-pub`, `flutter test --no-pub`, `flutter build apk --debug --flavor partner --target-platform android-x64 --no-pub`. Emulator run base: `flutter run --flavor partner --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1`.

DEMO seed requires APP_ENV development/test and explicit RECRUITMENT_DEMO_SEED=true, default false. Production rejects seed/sandbox. Stable IDs prevent duplicate seed records; random undisclosed fixture passwords mean fixtures are not test login accounts. ACTIVE label alone never grants job eligibility. Use normal auth to register a fictional applicant, not a seed login.

## External dependencies and unfinished implementation

SMTP authentication failed; recruitment EMAIL remains SIMULATED/FAILED with no delivered timestamp. Payments/refunds are explicitly DEMO or staff-confirmed office records; no provider charges. Identity scanner is unconnected: PENDING documents cannot be approved or publicly previewed. Actual Academy videos, legal policies, holidays and uniform business content must be configured with usable content; placeholder test URLs are not real training.

Unfinished code is listed separately in the phase table. It is not labeled externally blocked, and not every phase is DONE. Notifications/workflows share actual persisted backend state, but complete Web↔Backend↔Flutter acceptance remains unverified.

Manual E2E: register a fictional account normally, configure a live recruitment area/service and valid content in Admin, follow onboarding/20 questions/videos/terms, use explicit development DEMO identity or private fictional uploads with a configured scanner, review using scoped staff, choose one of three packages/sandbox or office payment, book/check in/receive/return originals, verify SLA and notifications, approve/activate, post a fictional Customer task, accept/progress/chat from Partner, confirm history/chat in Customer. Repeat rejection/supplement/retry/payment failure/suspension and forbidden-role paths per `TASKLY_RECRUITMENT_E2E_TEST_MATRIX.md`.