# TaskLy Partner — kế hoạch tích hợp tuyển dụng

Ngày audit: 09/10/2026 (Asia/Bangkok). Đặc tả: `TASKLY_PARTNER_ONBOARDING_RECRUITMENT_MASTER_PROMPT.md` đã đọc toàn bộ A–M.

## Trạng thái bàn giao

- PHASE 00: audit nguồn và kế hoạch tích hợp; kết quả baseline ở `TASKLY_PARTNER_RECRUITMENT_CHECKLIST.md`.
- PHASE 01: đã lập trình foundation application/eligibility/status policy, role guards, repository interfaces, persisted mock snapshot và 15 mẫu hư cấu; chưa hoàn tất toàn bộ entities/CMS contracts và bridge Admin.
- PHASE 02–13: chưa triển khai; không đánh dấu hệ thống tuyển dụng hoàn tất.
- Không thay đổi Login/Register, Customer booking, schema database hay Partner UI trong PHASE 00.

## Stack và điểm tích hợp

| Thành phần | Hiện trạng | Điểm tích hợp giữ lại |
|---|---|---|
| Flutter | Flutter/Dart, ChangeNotifier controllers, repository interfaces, Android flavors customer/partner | `lib/app/tasker_controller.dart`, `lib/domain/tasker_repositories.dart`, `lib/features/tasker_view.dart` |
| Auth | Session API, secure token storage, email OTP; brand Partner xanh dương ở màn auth | `lib/auth/entry.dart`, `lib/auth/api.dart`, `lib/main.dart`; không viết lại form auth |
| Partner nghiệp vụ | `MockTaskerRepository` trên `MockDataStore` dùng chung Customer trong test harness | Thêm repository tuyển dụng riêng; không sao chép task/ledger |
| Admin | Next.js 15.5.27/React 19/TypeScript, API proxy dùng cookie httpOnly | `src/components/AdminApp.tsx`, `AdminPortal.tsx`, `src/lib/admin-api.ts` |
| Backend | Spring Boot 4.1.1/Java 21/PostgreSQL/Flyway/JWT permissions/MinIO/Redis/SMTP adapter | Thêm resources recruitment; giữ auth, verification, storage APIs |
| Kiểm thử | Flutter unit/widget journeys; Node pure-domain tests; Spring integration/service tests H2 | Bổ sung tests theo từng phase, giữ baseline cũ |
| Build | Flutter flavors, Gradle backend, Next build | `.next-dev` riêng với `.next`; không chạy build ghi đè cache dev |

## Feature map trước triển khai

DONE chỉ nghĩa là phần chức năng cụ thể đã có trong code, không đồng nghĩa được xác nhận production.

| Yêu cầu | Trạng thái | Bằng chứng và phần thiếu |
|---|---|---|
| Login/Register/email OTP | DONE/PARTIAL | `auth/entry.dart`, backend auth và `OtpMailSender`; giữ lại. Chưa có tạo PartnerApplication sau xác thực |
| Partner 4 tab | BUG | `tasker_view.dart`: hiện 5 tab Việc làm/Bản đồ/Việc của tôi/Ví/Hồ sơ; cần 4 tab Công việc/Hộp thư/Phúc lợi/Tài khoản |
| Partner xanh dương | PARTIAL | Auth #2563EB; `main.dart` vẫn dùng AppTheme.light Emerald; nhiều AppColors.primary hardcode trong Partner |
| Job/feed/thực hiện/chat/wallet | PARTIAL | Journeys hiện có hoạt động với shared mock session; chưa phải Partner API jobs/earnings |
| Chặn tài khoản chưa ACTIVE | BUG | `MockTaskerRepository.accept` chỉ kiểm tra login/online; `MockDataStore.assign` không kiểm tra tuyển dụng. Direct controller routes chưa có recruitment gate |
| Trạng thái mới đăng ký | BUG | MockDataStore mặc định verification verified, sample Partner profile; backend user đăng nhập được đưa vào projection mock, không có application mới |
| Resume tuyển dụng | MISSING | MockDataStore reset theo vòng đời app; secure token storage không phải onboarding persistence |
| Registration/areas/waitlist | MISSING | Chưa có RecruitmentArea, PartnerApplication, age/service/area validation |
| Thi 20 câu/question CMS | MISSING | Chưa có ngân hàng câu hỏi, attempt, timer, snapshot, config, daily retry |
| Academy/player/progress/quiz | MISSING | Không có video player dependency/assets hay training CMS |
| Cam kết/version consent | MISSING | KYC backend có consent đơn lẻ; không có từng tài liệu/version/effective date |
| KYC private upload | PARTIAL | Backend verification + MinIO private objects, JPEG/PNG magic/size/dimensions, masked document number, signed URL TTL; app Partner chưa dùng API này |
| KYC sơ bộ/bổ sung | PARTIAL | Backend approve/reject/begin-review/history; chưa có recruitment preliminary state/action-required/resubmit/appeal |
| Private document security | PARTIAL/BUG | Upload scan status PENDING; signedReadUrl chỉ chặn INFECTED, chưa chặn PENDING. Chưa thấy scanner thực thi, retention worker, audit từng read hay chứng cứ cấu hình encryption-at-rest |
| Admin KYC UI | PARTIAL | Admin cũ dùng demo kycs/changeKyc/localStorage; chưa nối verification queue API |
| Đồng phục/gói/đơn/kho | MISSING | Không có uniform model/catalog/order/payment flow; tiền đảm bảo mock cũ không được dùng thay đồng phục |
| Office/appointment/check-in | MISSING | Không có văn phòng/slot/capacity/receipt/checklist hồ sơ |
| Final review/SLA/activation | MISSING | Không có DOCUMENTS_RECEIVED timestamp, business calendar SLA hay ACTIVE gate |
| Notifications/email | PARTIAL | Task notifications mock và SMTP OTP có sẵn; không có recruitment outbox/templates/delivery worker. Không xác nhận SMTP gửi thành công trong audit |
| RBAC tuyển dụng | MISSING/PARTIAL | Backend có KYC_REVIEW và roles nền tảng; chưa có ma trận roles tuyển dụng. Admin portal chỉ cho ADMIN/SUPER_ADMIN; cần mở đúng staff permissions, không đơn giản thêm role dropdown |
| Audit | PARTIAL | SQL audit_logs/outbox_events tồn tại; mock Admin record mutable, chưa có recruitment audit immutable/redaction |
| Partner/Admin đồng bộ | MISSING | Flutter MockDataStore và Admin localStorage là hai store độc lập; DataLab import hiện chỉ tasks, không phải recruitment |
| Customer/Admin các module hiện có | DONE/PARTIAL | Catalogue/icons/banners/community/account dùng API; task/finance Admin phần lớn demo. Giữ phạm vi này nguyên trạng |

## Data flow hiện tại và mục tiêu

Hiện tại:
- Flutter auth → Session API → main.dart profile → Partner MockTaskerRepository → in-memory MockDataStore.
- Admin auth → Next proxy → backend users/catalogue; KYC/task/finance demo → localStorage.
- Backend KYC riêng tồn tại nhưng chưa nối hai UI tuyển dụng.

PHASE 01: tạo `PartnerOnboardingRepository` + `RecruitmentRepository`, models/status policy, snapshot contract `taskly.partner-recruitment/v1`. Mock chỉ metadata và file mẫu. Import/export có validation/version/concurrency, không khẳng định realtime giữa hai app.

PHASE 02–13: UI chỉ gọi repository; mock persistence account-scoped, atomic save và reset chỉ dev. API adapter đi cùng resource server khi được triển khai/test, không âm thầm fallback API failure thành thành công mock. Hồ sơ thật không được nhập vào localStorage hay snapshot JSON; tận dụng private KYC API sau khi hardening.

Không dùng `user.status == ACTIVE` của tài khoản đăng nhập thay `PartnerApplication.status == ACTIVE`. Hai trạng thái có ý nghĩa khác nhau.

## Domain và invariant bắt buộc

- Application tổng hợp các sub-state exam, training, consent, documents, preliminary, order, payment, appointment, final, activation; không reset phần đã đạt khi cần bổ sung.
- Attempt giữ version/snapshot, đúng 20 câu/4 options/1 answer; timer và daily retry dựa clock inject được; submit idempotent.
- Progress dựa watched milestones và quiz; không đánh dấu completed chỉ bằng mở video.
- Sơ bộ phải đạt trước order và appointment. AT_OFFICE luôn PENDING cho đến authorized reception/finance receipt.
- DocumentsReceived chỉ khi check-in và checklist đầy đủ; SLA lấy mốc này, calendar/config 24–48h dự kiến.
- APPROVED chưa ACTIVE: phải đủ skill/service training/area/availability. SUSPENDED chặn feed/accept ngay ở domain, repository và API.
- Purchase tier không tham gia job ranking hay activation eligibility.
- Quyết định duyệt có actor/role/reason/version/idempotency/audit, không cho applicant tự duyệt.

## Design và routing

- Partner tokens: primary #2563EB, dark #1D4ED8, soft #EFF6FF; surface white/text #0F172A/#667085.
- Không đổi AppColors chung khiến Customer bị đổi màu; tạo Partner theme/tokens scoped và chuyển widget Partner dùng Theme.
- Shell 4 tab: Công việc(home hub/feed), Hộp thư(onboarding inbox/task chat), Phúc lợi(policy/rewards), Tài khoản(profile).
- Map/jobs/wallet/KYC/academy/exam/order/appointment là routes con; giữ existing IDs/callbacks/task lifecycle.
- New account hub là default; route guard không chỉ ẩn tab. Reduce motion + 320/375/430 + keyboard avoidance kiểm thử.

## Roadmap và phase gates

| Phase | Tích hợp/code chính | Gate trước khi chuyển phase |
|---|---|---|
| 00 | Audit, inventory, feature map, risks, baseline, kế hoạch này | Không thay behavior; công cụ/kiểm tra được ghi rõ |
| 01 | Domain typed models/status machine, repositories, safe mock seed >=15 scenarios, account persistence, schema import/export, RBAC | Unit tests illegal transitions/roles/idempotency/roundtrip/corrupt snapshot/preservation pass |
| 02 | 4-tab shell, auth application initialization, blue theme, hub/form/draft/waitlist | Validation age/contact/areas/services, new identity no jobs, resume, 4-tab tests |
| 03 | Admin recruitment sidebar/areas/applications/detail/search/filter | CRUD permission và snapshot bridge; existing Admin auth preserved |
| 04 | Questions/config/attempts + 20-question exam | Timer/retry/shuffle/hidden answers/snapshot/double-submit tests |
| 05 | Courses/lesson CMS/video/progress/quiz | Milestone validation/resume/no skip/service-specific training tests |
| 06 | Agreement versions/consents/KYC sample metadata; private storage hardening design | Required consent, files, read audit/privacy, no real IDs in mock/export |
| 07 | Preliminary decisions/actions/resubmit/outbox | Staff roles, retain exam/training, applicant can't approve |
| 08 | Uniform 3 configurable packages/inventory/order/refund/exchange/demo payment | Atomic inventory; office PENDING; fail/retry/refund audit |
| 09 | Offices/slots/appointments/check-in/physical docs/receipt | Capacity/concurrency/reschedule/missing-docs/originals returned |
| 10 | Final/SLA/business calendar/appeals/outbox | Docs timestamp, final gates/dual approval if configured, retries |
| 11 | ACTIVE domain/API gates/service training/availability, post-approval tabs | Every feed/accept/direct/deep-link denied before ACTIVE/suspended |
| 12 | RBAC/audit/redaction/offline/retry/accessibility/reduced motion | Role-matrix and 320–430 responsive tests, immutable audit |
| 13 | E2E/smoke/build/manual QA/docs/handoff | 32 cases J mapped with actual evidence; report unresolved items |

## Phạm vi dữ liệu demo và cấu hình

Defaults từ đặc tả chỉ là demo: age 18+, exam 20/25min/pass16/retry2, 3 packages, SLA24–48h. Phí, sizes, inventory, offices, policies, agreements, documents, retention và videos đều CMS-configurable/versioned. Không chọn chính sách pháp lý thay người quản lý. Production rollout cần xác nhận chính sách hợp tác, thu phí, giấy tờ và privacy trước khi thu dữ liệu thật.

Seed hư cấu: registered; city-missing; exam-failed; exam-passed; training-partial; profile-incomplete; prelim-review; action-required; prelim-approved; office-payment-pending; docs-received; final-review; active; rejected; suspended. Dùng `.example.test`, không ID/ảnh CCCD thật; metadata document dùng `demo-document-*`.

## Regression và chạy kiểm tra

Flutter (cwd Taskly-main):
```powershell
& C:\flutter\bin\dart.bat format lib test
& C:\flutter\bin\flutter.bat analyze --no-pub
& C:\flutter\bin\flutter.bat test --no-pub
& C:\flutter\bin\flutter.bat build apk --debug --flavor partner --target-platform android-x64 --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```
Admin (cwd frondend): `npm run lint`, `npm test`, `npm run build`, `npm run dev`.
Backend (cwd backend): JAVA_HOME Java21; `./gradlew.bat test --rerun-tasks`. Integration tests H2 chứng minh domain/API trong test, không chứng minh SMTP/MinIO production đang hoạt động.

Không tự launch APK hay thay bản Customer trong phase audit. Backend/frontend đang chạy giữ nguyên.

## Files PHASE 00

- `docs/TASKLY_PARTNER_RECRUITMENT_IMPLEMENTATION_PLAN.md`: tài liệu này.
- `docs/TASKLY_PARTNER_RECRUITMENT_CHECKLIST.md`: từng phase và baseline/known risks.
- `docs/TASKLY_PARTNER_RECRUITMENT_SOURCE_INVENTORY.json`: danh sách source đã scan + master checksum để đối chiếu.
- Chưa có migration/model/UI/repository tuyển dụng mới ở PHASE 00.

## PHASE 01 — code foundation đã kiểm tra

Files mới:
- `Taskly-main/lib/domain/recruitment/recruitment_models.dart`
- `Taskly-main/lib/domain/recruitment/recruitment_policy.dart`
- `Taskly-main/lib/domain/recruitment/recruitment_repository.dart`
- `Taskly-main/lib/data/recruitment/mock_recruitment_repository.dart`
- `Taskly-main/lib/data/recruitment/secure_recruitment_persistence.dart`
- `Taskly-main/lib/data/recruitment/recruitment_seed.dart`
- `Taskly-main/test/recruitment_foundation_test.dart`

8 test mới kiểm tra: hồ sơ mới/resume/account separation; Finance/applicant không duyệt sơ bộ; request-changes giữ exam/training; idempotency; corrupt snapshot không ghi; ACTIVE prerequisites/suspension; sơ bộ duyệt ghi eligibility nhưng chưa active; failed persistence/stale version không ghi đè; seed15 và roundtrip (một số test gộp nhiều assertions).

Kết quả sau chỉnh code: Flutter analyze sạch; toàn bộ91 tests pass; Partner APK build8s pass. Các kiểm tra Admin16 tests/lint/build và backend rerun49s đã chạy ở baseline; PHASE01 không chỉnh những source đó.

Giới hạn hiện tại: đây là adapter demo metadata chưa được bind vào production TaskerController. `PartnerApplication.canAcceptJob` đã có test nhưng chưa thay runtime accept cũ; việc nối gate UI/repository/task assignment phải thực hiện trước khi rollout. Enrollment/exam/training/agreements/uniform/appointment typed entities và CMS chưa được thực thi; bridge import/export Admin và phase02 UI chưa có. Chưa có recruitment API/realtime, immutable server audit hay gửi email tuyển dụng thật. Không tự dùng snapshot demo làm bằng chứng KYC/activation production.
