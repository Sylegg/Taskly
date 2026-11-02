# TaskLy fullstack recruitment checkpoint

Updated2026-10-09. Workspace: C:\Users\Lenovo\Downloads\workspace-01a0ec6a-b57f-7296-95e5-b304596acf5a.
Master `TASKLY_PARTNER_14_PHASES_ONE_SHOT_EXISTING_FULLSTACK_FLOW.md` was read in full. User authorizes continuous implementation in existing Backend/Admin/Flutter; no request to create background tasks or agents. Preserve auth and Customer.

## Current evidence

Phase00 DONE;01–13 have actual code but remain PARTIAL against full acceptance. Authoritative five-column phase report: `TASKLY_EXISTING_SYSTEM_FLOW_BUILD_REPORT.md`;32-case evidence: `TASKLY_RECRUITMENT_E2E_TEST_MATRIX.md`; source inventory: `TASKLY_RECRUITMENT_CHANGED_FILES.md`.

Latest full checks PASS: Backend104 tests (failures/errors/skips0) and bootJar; Admin21 tests + TypeScript lint + Next build; Flutter97 tests + analyze + Partner debug Android x64 APK. Existing Customer/Auth/legacy Tasker journeys pass. No complete Web+PostgreSQL+device E2E was executed. Latest APK has not been installed/launched for acceptance.

Backend runtime PID2424 from immutable latest JAR, port8080. PostgreSQL migration29 verified applied;15 DEMO applicants/20 MCQs/3 uniform packages persisted. Audit guards2 enabled; rollback no-op UPDATE attempt rejected as SQLStateP0001. Never print .env. Seed disabled by default and not permanently enabled. Fixture passwords are random/undisclosed; ACTIVE labels lack eligibility.

## Latest code

Backend22 recruitment Java files, SQL V19–V27/V29 and Java PostgreSQL V28 append-only audit migration. Shared real APIs persist registration/quotas/exam snapshot and retries/Academy progress/terms/private KYC/preliminary/uniform stock and DEMO refund-exchange-handover/office reception+idempotent receipts/final/SLA-calendar/appeals/templates and mock outbox/ACTIVE gating/real jobs+lifecycle/benefits. Scoped staff roles enforced.

Admin Recruitment components implement queue/server paging50 and status/name/area/service filters, DB-wide KPI aggregates, areas/question config/Academy/terms/uniform/slots/checklist/benefits/CLEAN KYC preview/reception/payment adjustments/audit/appeals/message snapshots/mock retry and SLA calendar popup. Proxy forwards GET query parameters and role-isolates general Admin routes.

Flutter exact four tabs: Công việc/Hộp thư/Phúc lợi/Tài khoản. Uses existing Session and true APIs. Actual private KYC PNG/JPEG multipart picker with magic/size/auth validation; dev metadata mock separate. Academy video_player and current-version eligibility at final/activation/jobs; Academy stays reachable after exam. Remaining attempts/review topics from server. Followup has live uniform/appointment/receipt/SLA24–48-working-hour data. Shared task_activity shows assigned Partner jobs, guarded transitions/history/chat; profile/password and benefit content use actual APIs. Demo email remains SIMULATED; no actual provider charge/send.

SLA weekdays9–18 by default Asia/Bangkok, Admin timezone/hours/holiday config, min24/max48. Weekend/holiday/before-opening/spanning-day unit tests and config/RBAC integration passed. No automated escalation yet.

Receipt retry returns original record for same payload,409 if changed; missing→new appointment→complete preserves exam/training. ACTIVE cannot book a new onboarding appointment. Reception/payment locks take applicant account before appointment/order to avoid inverse-lock deadlocks; full concurrent stress tests remain.

## Remaining implementation

1. Service-specific Academy courses/certification, seven configured videos/subtitles and retake policy. Do not seed fictional videos/legal URLs as real content.
2. Question service weights/tags/import/export and mobile deadline/offline boundary tests.
3. Exact field/evidence revision history, retention/withdrawal/privacy operations. Existing PENDING KYC cannot be approved/read until scanner marks CLEAN; production rejects DEMO.
4. Partner uniform adjustment requests, package images/items, QR/no-show office experience.
5. SLA escalation/reminder jobs/notification preferences; real sender only when configured. SMTP authentication previously failed; health may503 for mail.
6. Online/offline job availability edits, decline/evidence/no-show/dispute/payout/bank/deactivation/support; certificates for matching.
7. Additional queue date filters/report exports and analytics; all32 full browser/device E2E/RBAC/private-data/accessibility/concurrency scenarios.

These are unfinished code/QA, not all external blockers. Do not mark all14 phases complete or claim realtime synchronization.

## Commands

Backend: JAVA_HOME=C:\Program Files\Java\jdk-21.0.10; gradlew.bat test bootJar --console=plain.
Admin: npm run lint; npm test; npm run build.
Flutter: C:\flutter\bin\flutter.bat analyze --no-pub; test --no-pub; build apk --debug --flavor partner --target-platform android-x64 --no-pub.
Runtime restart: backend/scripts/restart-current-backend.ps1 -SkipBuild after passed build.
Android emulator API base must include /api/v1: http://10.0.2.2:8080/api/v1.
Local counts/audit guard: Java source backend/scripts/VerifyRecruitmentSeed.java with cached PostgreSQL driver, optional --test-audit-write-guard (local dev/test only, transaction always rolled back).

No running test/build sessions remain at checkpoint. No task automation was created. Continue from these files rather than restarting audit or rewriting Login/Register. Browser getTab was attempted but documentation output exceeded context; if browser automation resumes, call cua.rewriteDocumentation first. No browser E2E result is claimed.