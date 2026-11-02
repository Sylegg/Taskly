# TASKLY ULTIMATE V3 → FLUTTER + SPRING BOOT — MASTER BUILD PROMPT

> **Loại tài liệu:** Prompt triển khai toàn diện để đưa trực tiếp vào AI Coding Agent ở VS Code / Cursor / Codex / Antigravity.  
> **Nguồn tham chiếu thực tế:** `TASKLY_ULTIMATE_MOBILE_INTERACTIVE_V3.html` và `TASKLY_ULTIMATE_V3_TEST_AND_INTEGRATION_GUIDE.md`.  
> **Phạm vi trích từ HTML:** 94 routes/điểm truy cập: 73 màn cơ sở + 21 route V3 mở rộng.  
> **Phạm vi phát triển:** TaskLy Mobile Flutter (Customer + Partner) + các API/backend tương ứng; Admin là **web riêng**.  
> **Không làm lại:** Login và Register của Flutter project hiện có.  
> **LƯU Ý:** HTML mô phỏng bằng JS + `localStorage`, không phải code mobile production. Các API/model/test bên dưới là **đề xuất để hiện thực hóa**, phải đối chiếu backend trước khi chốt.

---

# PHẦN A — LỆNH MASTER PROMPT CHO AI CODING AGENT

## A1. Vai trò và mục tiêu

Bạn là **Principal Flutter Engineer, Spring Boot Backend Architect, Product/UX Designer, App Security Engineer, QA Automation Engineer và Release Engineer**.

Bạn đang làm việc trên **TaskLy repository ĐANG CÓ**. Hãy chuyển **toàn bộ trải nghiệm tương tác trong `TASKLY_ULTIMATE_MOBILE_INTERACTIVE_V3.html`** thành chức năng ứng dụng Flutter thực, theo thiết kế và trạng thái prototype, KHÔNG tạo lại app từ đầu. Cần tích hợp backend/API thật, tái sử dụng những phần đã có, giữ nhất quán UI/UX, và hoàn thành dần đến trạng thái **Closed Beta Ready**.

Yêu cầu triển khai bao gồm:

- Customer tìm dịch vụ, tạo booking động theo ngành dịch vụ, địa chỉ, lịch, báo giá, thanh toán sandbox, matching, xem task, chat, thay đổi/hủy, hoàn tất, review, support.
- Partner onboarding/KYC, skills, service areas, lịch rảnh, Academy/agreement, job feed, accept, commute/check-in, checklist/evidence, hoàn thành, giao dịch, payout sandbox, đánh giá.
- 2 role/mode trong **cùng một app mobile**, dữ liệu liên thông từ **backend làm nguồn sự thật**.
- Tất cả màn nằm trong bảng route ở Phần C phải có **route/widget, event handling, state, quyền truy cập, dữ liệu nguồn, lỗi, test**, trừ các trang `developer/testGuide/screenIndex/diagnostics/uiStates` được giới hạn **debug/dev**.
- Backend Spring Boot hiện có là ưu tiên; KHÔNG tạo song song backend mới nếu đã có.

## A2. RÀNG BUỘC CẤM PHÁ CODE CŨ

1. **Login và Register đã làm xong:** KHÔNG tạo lại, KHÔNG ghi đè, KHÔNG đổi flow, KHÔNG reset UI của hai màn này. Chỉ điều chỉnh kết nối tiếp bước nếu thiếu và có test chứng minh.
2. KHÔNG tạo Flutter project mới, không thay package structure, database, router/state management nếu chưa khảo sát và chứng minh cần.
3. KHÔNG sao chép HTML/CSS/JavaScript trực tiếp vào Flutter `lib/`; **không dùng WebView để dựng app production**.
4. KHÔNG xoá business/API hiện có hoặc chỉnh backend hợp đồng không tương thích một cách âm thầm.
5. KHÔNG hard-code bảng giá, voucher, số dư, role, task status, KYC status, quyền chat, trạng thái thanh toán trên mobile production.
6. Không để nút bấm giả, tính tiền giả, OTP cố định hay thao tác “thành công” khi server không xác nhận.
7. Không đưa Admin thành role/tab của mobile. Chỉ tạo **API hỗ trợ Admin Web** / interface phục vụ xử lý KYC, tranh chấp, refund khi đã có quyền.
8. Không lưu password, OTP, refresh token, giấy tờ KYC, thông tin ngân hàng trong plain-text localStorage/SharedPreferences/log.
9. Không hiển thị dữ liệu nhạy cảm của Customer cho mọi Partner trước khi task được phân công.
10. Nếu HTML dùng dữ liệu demo vô lý, ưu tiên an toàn và business invariant, ghi rõ khác biệt, không copy lỗi demo sang production.

## A3. Nguồn sự thật và cách xử lý khác biệt

Ưu tiên theo thứ tự:

1. Quy tắc bảo mật và phân quyền bắt buộc.
2. API/schema/business rules đã chạy của TaskLy backend.
3. Flutter code hiện tại + style brand chính thức.
4. Hành vi và thiết kế của HTML V3.
5. Các đề xuất bổ sung trong tài liệu này.

Nếu mâu thuẫn: lập `docs/taskly-v3-conflicts.md` với **Existing / HTML / Proposed / Decision**, chọn phương án bảo toàn dữ liệu & compatibility hoặc đánh dấu **NEEDS_APPROVAL** khi liên quan tiền, quyền hoặc hợp đồng. Không tự quyết định chính sách phí hủy, escrow, payout, KYC/legal retention hoặc điều khoản bằng một con số từ HTML.

## A4. START NOW — bắt buộc scan repository trước

Trước khi viết code:

- Xác định Flutter app entry point, `pubspec.yaml`, router, state management, API client, DI, assets, theme, localization.
- Xác định backend Spring Boot entry point, controllers, DTO, entities, auth filters, migrations, DB, Redis, websocket, payment adapters.
- Dò toàn bộ Login/Register và test hiện tại; đánh dấu **PROTECTED**.
- Đọc trực tiếp `design-reference/TASKLY_ULTIMATE_MOBILE_INTERACTIVE_V3.html` và `design-reference/TASKLY_ULTIMATE_V3_TEST_AND_INTEGRATION_GUIDE.md` khi những file đó đã được chép vào repo.
- Tạo `docs/taskly-v3-current-audit.md`, `docs/taskly-v3-route-mapping.md`, `docs/taskly-v3-api-gap.md`, `docs/taskly-v3-plan.md`.
- Với MỖI tính năng: `EXISTS / PARTIAL / MISSING / BROKEN / NEEDS_APPROVAL / OUT_OF_SCOPE`.
- Không giả vờ đã truy cập source nếu file chưa tồn tại. Nếu HTML chưa nằm trong repo, vẫn dùng prompt này để dựng functional roadmap và yêu cầu người dùng đính kèm HTML reference để khớp pixel/UX.

Sau scan, triển khai từng **vertical slice** Flutter UI → controller → API → backend → DB → tests. Tiếp tục slice kế tiếp sau khi slice trước qua build/test; không viết 100 màn mock trống rồi mới nối backend.

---


# PHẦN B — UI/UX DESIGN SYSTEM & KIẾN TRÚC

## B1. Ngôn ngữ thiết kế: TaskLy Premium Smart Home

- Brand chính: **emerald / teal / mint + white + dark navy**; dễ dùng, sạch, tin cậy.
- Token gợi ý: `primary #0F9D7A`, `primaryDark #087A60`, `primarySoft #DDF5EE`, `mint #B9EFE3`, `background #F7FBF9`, `surface #FFFFFF`, `text #0F172A`, `muted #667085`, `border #DDE7E4`, `success #16A36D`, `warning #F5A524`, `error #E5484D`.
- `8pt spacing`, screen inset 20–24, card radius 20–24, input radius 16–18, button height 52–56, responsive 360–430+ dp.
- Header hero: gradient mint, greeting, địa chỉ, tìm kiếm, robot TaskLy 3D nhẹ, CTA đặt việc.
- Dịch vụ: icon minh họa 3D/pastel khác nhau nhưng thống nhất style (Dọn nhà, Tổng vệ sinh, Sửa chữa, Chuyển nhà, Máy lạnh, Đi chợ hộ, Thú cưng, IT).
- Robot mascot là asset minh họa trong Home/onboarding/empty state/success; **không** render 3D nặng trên mọi trang, ưu tiên PNG/WebP/optimized SVG/Lottie phù hợp hiệu suất.
- Không copy pixel của app cạnh tranh. Không lạm dụng glassmorphism, blur, shadow; đảm bảo contrast WCAG, reduce-motion support.
- Bottom Nav Customer: **Trang chủ / Hoạt động / Đặt việc (giữa) / Tin nhắn / Tài khoản**.
- Bottom Nav Partner: **Việc phù hợp / Lịch / Công việc / Thu nhập / Hồ sơ**.
- Typography thống nhất (Inter/Manrope hoặc font project), localization **vi** trước, sẵn sàng EN; tiền VND, ngày giờ theo timezone, number format dùng intl.
- Tap targets >= 44dp; handling keyboard/safe-area/back/pull-to-refresh; hình ảnh ở đúng `BoxFit` và có placeholder.

## B2. Bộ widget nên tái sử dụng (không tạo trùng)

`TaskLyScaffold`, `TaskLyAppBar`, `TaskLyBottomNav`, `TaskLyRobotHero`, `TaskLyButton`, `TaskLyTextField`, `TaskLyPhoneField`, `TaskLyOtpInput`, `TaskLyAddressCard`, `TaskLyServiceCard`, `TaskLyJobCard`, `TaskLyStatusChip`, `TaskLyTimeline`, `TaskLyPriceBreakdown`, `TaskLyQuoteCountdown`, `TaskLyPartnerCard`, `TaskLyBookingStepper`, `TaskLySchedulePicker`, `TaskLyImageUploader`, `TaskLyReviewComposer`, `TaskLyChatBubble`, `TaskLySectionHeader`, `TaskLyDialog`, `TaskLyBottomSheet`, `TaskLyEmptyState`, `TaskLyLoadingState`, `TaskLyErrorState`, `TaskLyOfflineBanner`, `TaskLyPermissionState`, `TaskLySkeleton`, `TaskLyToast`.

Mỗi thành phần phải hỗ trợ loading/disabled/error/empty phù hợp. Không tạo universal widget với hàng chục tham số khó bảo trì.

## B3. Kiến trúc code — phải tuân theo project đã có

Nếu project chưa có cấu trúc rõ, tham khảo, **không ép migrate nếu không cần**:

```text
lib/
  app/                     # app shell, router, bootstrap, DI
  core/
    design_system/         # tokens, themes, widgets
    api/                   # client, error mapping, interceptors
    auth/                  # session, role/permissions
    storage/               # secure storage, safe cache
    notification/          # push/deep link
    location/              # permission + map adapter
    media/                 # upload adapter
    utils/                 # time, money, validators
  features/
    auth_followups/        # email OTP, forgot/reset (KHÔNG rebuild login/register)
    customer_home/
    services/
    booking/
    addresses/
    task_lifecycle/
    payments/
    matching/
    favorites_reviews/
    recurring/
    vouchers_rewards/
    chat/
    notifications/
    support_safety/
    customer_account/
    partner_onboarding/
    partner_kyc/
    partner_skills_areas/
    partner_schedule/
    partner_jobs/
    partner_work/
    partner_finance/
    partner_account/
  l10n/
assets/
  brand/
  robots/
  services/
  auth/
  empty_states/
```

Các feature cần tổ chức widget + state + service/repository + model/DTO + tests. Dùng **state management/router/HTTP client hiện tại** của app; nếu chưa có thì đề xuất đơn giản, không ép Riverpod/Bloc/GetX không có lý do.

## B4. Nguyên tắc API

- Backend là nguồn sự thật của task status, quote, payment, partner eligibility, payout, role, KYC, rating, voucher.
- Mobile có cache có TTL/invalidations, optimistic updates chỉ cho thao tác an toàn; thao tác tiền/trạng thái quan trọng phải chờ server.
- Có idempotency key cho tạo payment/booking/accept/complete/refund/payout khi thích hợp.
- Chuẩn lỗi: 400 validation; 401 refresh/logout; 403 role/resource; 404 not found; 409 conflict; 422 business rule; 429 retry-after; 5xx retry safe.
- Phân trang, debounce search, cancel requests cũ, refresh/reconnect, loading/empty/error/offline.
- Upload sử dụng signed URLs/provider an toàn nếu phù hợp; không gửi chứng từ KYC bừa bãi.
- Feature flags lấy từ backend; không để UI feature disabled thành nút chết.

---


# PHẦN C — DANH MỤC CHUẨN 94 MÀN HÌNH/ROUTES TRÍCH TỪ HTML

**Tuyên bố nguồn:** Các route ID và nhãn dưới đây được **trích trực tiếp từ `SCREEN_GROUPS`** của bản HTML V3. Yêu cầu hành vi/nguồn dữ liệu bên cạnh là **đặc tả triển khai Flutter/API**, không có nghĩa HTML đã hỗ trợ backend thật.

**Tiêu chí chung bắt buộc cho mỗi route:**

- Có tên route, screen widget, navigation path, role guard rõ ràng.
- CTA/form có xử lý thật; lỗi hữu ích khi API không thành công.
- Dữ liệu user/booking/task/payment không lấy từ hardcoded mock trong release.
- Test tối thiểu gồm render, điều hướng, loading/error, form validation, authorization.
- Kiểm tra bàn phím và màn nhỏ; không bị overflow; accessibility labels.


## C1. Khởi động & bảo mật (8 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `splash` | Khởi động / Splash | Boot splash; kiểm tra session an toàn, refresh token, load user/me/role, quyết định hướng điều hướng, timeout và retry | Auth/session, user profile, remote config |
| `login` | Đăng nhập (mô phỏng) | GIỮ NGUYÊN Login Flutter đã hoàn thành; chỉ nối navigation/token/error theo hiện trạng; KHÔNG tự dựng lại | Existing Auth API |
| `register` | Đăng ký (mô phỏng) | GIỮ NGUYÊN Register Flutter đã hoàn thành; không ghi đè form; nối Email OTP; giữ field phone contact nếu đang có | Existing Auth API |
| `emailOtp` | Xác minh email OTP | 6 ô OTP, paste, countdown, resend, thử sai/hết hạn/chặn; xác minh rồi tải profile | Email OTP and auth |
| `forgot` | Quên mật khẩu | Nhập email, gửi yêu cầu; thông điệp trung tính không tiết lộ account tồn tại; cooldown | Password recovery |
| `resetOtp` | OTP đặt lại mật khẩu | Verify OTP với purpose PASSWORD_RESET; nhận reset token ngắn hạn | Password recovery |
| `newPassword` | Tạo mật khẩu mới | Mật khẩu mới/xác nhận, validation, gửi reset token, thu hồi phiên theo chính sách | Password recovery |
| `success` | Thông báo thành công | Thành công sau xác minh/reset/booking theo loại; CTA đưa về đúng màn | Navigation/UI states |


## C2. Customer • khám phá (8 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `home` | Trang chủ Customer | Home Customer với location, search, 8 category, task active, gợi ý, robot CTA, nội dung theo data | Services/tasks/profile/notifications |
| `services` | Danh mục dịch vụ | Danh sách dịch vụ, nhóm, tìm/lọc, availability theo vùng, trạng thái rỗng/lỗi | Service catalog |
| `serviceDetail` | Chi tiết dịch vụ | Ảnh, mô tả, bao gồm/không gồm, giá tham khảo, FAQ/chính sách, CTA booking | Service detail/pricing |
| `search` | Tìm kiếm & lọc | Tìm kiếm/lọc từ dữ liệu thật; loading, debounce, xoá lọc, kết quả rỗng | Service search |
| `aiDraft` | TaskLy AI gợi ý | Gợi ý draft từ mô tả tự nhiên nếu flag được bật; user duyệt/chỉnh từng trường, không auto-post | AI draft optional/provider adapter |
| `addresses` | Sổ địa chỉ | Danh sách địa chỉ, chọn mặc định, xóa có xác nhận, đổi địa chỉ booking | Customer addresses |
| `addressEdit` | Thêm / sửa địa chỉ | Thêm/sửa label, địa chỉ, ghi chú, liên hệ; validate; GPS/map picker tùy chọn | Customer address write |
| `favorites` | Partner yêu thích | Danh sách Partner yêu thích, xem hồ sơ, bỏ yêu thích, đặt lại nếu eligibility đúng | Favorites/partner profiles |


## C3. Customer • đặt việc (14 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `booking` | Booking Wizard | Wizard service→details→date/time→address→extras→partner preference→review; lưu draft; back không mất dữ liệu | Booking draft/config |
| `quote` | Báo giá chi tiết | Bảng báo giá server, subtotal/extras/platform/discount/total, expiresAt, refresh khi thay inputs | Quotes and price rules |
| `payment` | Thanh toán sandbox | Chọn payment method hỗ trợ; tạo intent server; SDK/deeplink provider; loading/fail/retry | Payment intents/transactions |
| `paymentResult` | Kết quả thanh toán | Không tin redirect query để đánh dấu thành công; poll/refetch trạng thái server; pending/success/fail | Payment status |
| `matching` | Matching Partner | Tìm Partner, timeout, đổi thời gian/hủy/rematch; realtime + polling fallback | Matching service |
| `activities` | Hoạt động / Danh sách việc | Tabs Upcoming/Active/Completed/Cancelled, filter/search/pagination, mở task | Tasks query |
| `taskDetail` | Chi tiết & Timeline việc | Timeline, status/price/address/partner/evidence, actions theo quyền & trạng thái | Task read/events |
| `taskEdit` | Thay đổi thông tin việc | Chỉ edit trực tiếp khi business rules cho phép; invalidate quote; lưu thay đổi qua API | Task edit and re-quote |
| `taskChange` | Yêu cầu thay đổi | Sau ACCEPTED: tạo change request, Partner chấp thuận/từ chối, Customer chốt và payment adjustment | Change request workflow |
| `cancelTask` | Hủy công việc | Preview phí hủy/hoàn, lý do, xác nhận, chống nhấn lặp; kết quả server quyết định | Cancellation/refund policy |
| `rematch` | Tìm Partner thay thế | Partner hủy/no-show hoặc Customer request: đưa task về MATCHING với trạng thái thanh toán rõ | Rematching/assignment |
| `completeConfirm` | Xác nhận hoàn thành | Customer xem bằng chứng/tổng kết rồi Confirm hoặc Report problem; timeout policy backend | Task completion confirmation |
| `review` | Đánh giá hai chiều | Đánh giá Customer→Partner và Partner→Customer theo task; một review/perspective, validate | Reviews |
| `bookAgain` | Đặt lại nhanh | Tạo booking draft từ task cũ, yêu cầu chọn lịch/giá mới, không tự charge | Booking draft/history |


## C4. Giao tiếp & hỗ trợ (11 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `inbox` | Hộp thư | Danh sách chat theo task/support, unread counts, search, pagination | Conversations |
| `chat` | Chat theo công việc | Chat theo task và role; text/read/delivery, attachment/coordinates nếu policy; reconnect | Chat realtime |
| `notifications` | Trung tâm thông báo | Inbox thông báo, đánh dấu đã đọc, deep link kiểm tra quyền, load thêm | Notifications |
| `notificationPrefs` | Cài đặt thông báo | Toggle loại thông báo, permission push, các thông báo bắt buộc không tắt tùy ý | Notification settings |
| `support` | Trung tâm trợ giúp | Help Center, FAQ, danh mục vấn đề, mở ticket/incident | Support CMS |
| `ticketCreate` | Tạo phiếu hỗ trợ | Tạo ticket theo task/category/mô tả/ảnh, validation, thông báo thành công | Support tickets |
| `tickets` | Danh sách hỗ trợ | Danh sách ticket/status/timeline/trả lời của hỗ trợ | Support tickets |
| `dispute` | Khiếu nại / tranh chấp | Mở tranh chấp cho task theo điều kiện, chọn loại/lý do và bằng chứng | Disputes |
| `disputeDetail` | Chi tiết tranh chấp | Theo dõi tranh chấp, phản hồi và quyết định Admin Web (không cho Customer tự quyết định hoàn tiền) | Disputes/admin decisions |
| `safety` | Trung tâm an toàn | Safety Center, mẹo an toàn, báo người dùng, chặn liên hệ trái quyền, liên hệ hỗ trợ | Safety & reporting |
| `report` | Báo cáo người dùng | Form báo user/task: loại vi phạm, mô tả, bằng chứng, trạng thái | Reports/moderation |


## C5. Tài khoản & tiện ích (9 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `account` | Tài khoản Customer | Tài khoản Customer, mode switch, nhóm mục cài đặt/quyền riêng tư/hỗ trợ | Profile/navigation |
| `profileEdit` | Sửa thông tin cá nhân | Sửa tên/avatar/điện thoại liên hệ, email theo flow xác minh riêng nếu thay đổi | User profile |
| `security` | Bảo mật / đổi mật khẩu | Trang bảo mật: đổi mật khẩu, quản lý phiên, khôi phục tài khoản, logout | Security/session |
| `changePassword` | Đổi mật khẩu hiện tại | Đổi mật khẩu cũ→mới, verify, revoke theo chính sách | Auth change password |
| `sessions` | Thiết bị đăng nhập | Liệt kê thiết bị/phiên, thu hồi theo phiên hoặc tất cả | Sessions |
| `paymentHistory` | Lịch sử giao dịch | Giao dịch/refund/điều chỉnh theo task; trạng thái/tracking id, phân trang | Payments/ledger |
| `rewards` | Điểm thưởng demo | TaskPoints/voucher demo; production flag và backend rules cấp/đổi/giảm điểm | Rewards optional |
| `settings` | Cài đặt ứng dụng | Ngôn ngữ, notification, riêng tư, feedback, version, theme nếu có | User prefs/remote config |
| `about` | Giới thiệu / Điều khoản / Xóa tài khoản | Giới thiệu, điều khoản, privacy, version, yêu cầu xóa tài khoản theo quy trình | Legal/accounts |


## C6. Partner • gia nhập (6 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `partnerWelcome` | Trở thành Partner | Trang trở thành Partner, quyền lợi, yêu cầu, bước onboarding, KYC/skill/academy | Partner onboarding |
| `kyc` | Xác minh danh tính KYC | Form KYC, ảnh mặt giấy tờ & selfie nếu policy, consent và upload an toàn | KYC and media |
| `kycStatus` | Trạng thái duyệt KYC | DRAFT/SUBMITTED/UNDER_REVIEW/APPROVED/REJECTED, nêu lý do, sửa/nộp lại | KYC review |
| `partnerSkills` | Kỹ năng & dịch vụ | Chọn dịch vụ đủ điều kiện, trình độ/training; chỉ job matching nếu skill verified | Skills and eligibility |
| `partnerAreas` | Khu vực hoạt động | Chọn khu vực/quận/phạm vi làm việc; kiểm tra service coverage | Partner service areas |
| `partnerAvailability` | Lịch rảnh | Chọn lịch cơ bản và liên kết lịch rảnh chi tiết theo giờ | Partner availability |


## C7. Partner • nhận & làm việc (8 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `jobs` | Danh sách việc phù hợp | Danh sách job hợp lệ theo KYC/skill/area/availability; filter, trạng thái online | Job feed/matching |
| `jobDetail` | Xem chi tiết công việc | Thông tin job, thời gian, yêu cầu, khoảng cách/thu nhập ước tính; accept atomic | Job read/accept |
| `partnerSchedule` | Lịch Partner | Lịch ngày/tuần/tháng; job accepted + blocked dates, edit availability | Partner schedule |
| `partnerWork` | Việc đang thực hiện | Tab hôm nay/đang làm/sắp tới; status action đúng lifecycle, change request | Partner tasks/workflow |
| `checkin` | Check-in & di chuyển | On-the-way, arrived/check-in; GPS permission, accuracy/distance evidence; không tin vị trí client | Location/check-in |
| `evidence` | Ảnh & bằng chứng hoàn thành | Checklist, ảnh/video theo service rules, upload progress/retry, submit complete | Task evidence/media |
| `partnerIssue` | Báo vấn đề công việc | Báo sự cố khách vắng/không vào được/không an toàn/khác; tạo ticket | Support/safety |
| `partnerReviews` | Đánh giá nhận được | Danh sách reviews do Customer gửi sau task hợp lệ | Reviews |


## C8. Partner • tài chính & hồ sơ (5 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `earnings` | Tổng quan thu nhập | Số dư pending/available, chart, mốc đối soát, giải thích phí | Earnings/ledger |
| `transactions` | Sổ giao dịch | Sổ giao dịch Partner: payout/fees/adjustments, lọc trạng thái | Partner finance |
| `payout` | Yêu cầu rút tiền (demo) | Yêu cầu rút tiền nếu enabled, kiểm tra số dư/tài khoản/chống double spend | Payout requests |
| `performance` | Hiệu suất Partner | Rating/completion/on-time/cancel; metrics từ backend, khoảng thời gian rõ | Partner performance |
| `partnerProfile` | Hồ sơ Partner | Thông tin Partner + KYC/skill/areas/availability/finance/reviews/mode switch | Partner profile |


## C9. Test & thiết kế (4 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `testGuide` | Hướng dẫn E2E | Hướng dẫn thử E2E dựa trên demo; chỉ debug/dev | Internal test guide |
| `developer` | Bảng điều khiển Demo | Demo toggles + kiểm tra trạng thái, không bao giờ xuất hiện production | Internal dev tools |
| `screenIndex` | Danh sách tất cả màn | Danh mục toàn bộ routes, chỉ dev/demo | Internal screen catalog |
| `uiStates` | Loading / Empty / Error / Offline | Showcase loading/empty/error/offline/permissions; dùng component real UI | UI state gallery |


## C10. Ultimate • Customer (9 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `noShow` | Báo Partner không đến | Customer report Partner no-show; validate thời hạn; tạo case, route rematch/refund theo policy | Attendance/disputes |
| `paymentAdjustment` | Điều chỉnh tiền mẫu | Sau change request đầy đủ: extra charge/refund sandbox; production dựa server ledger | Payment adjustments |
| `welcomeTour` | Giới thiệu & hướng dẫn | Onboarding giới thiệu, các điểm nổi bật và bỏ qua/hoàn thành một lần | User onboarding |
| `mapPicker` | Bản đồ chọn điểm (demo) | Chọn tọa độ bằng bản đồ thật, reverse-geocoding, confirm; fallback địa chỉ thủ công | Location/map provider |
| `uploadCenter` | Ảnh yêu cầu dịch vụ | Ảnh booking: camera/gallery, preview/remove, upload, quota/file validation | Media uploads |
| `priceBreakdown` | Bảng giá & hết hạn | Bảng giá chi tiết, quote TTL 10 phút ở demo, cập nhật giá từ server | Quote/price rules |
| `recurringPlans` | Dịch vụ định kỳ | Once/weekly/biweekly/monthly, pause/resume/cancel/next occurrence, no silent auto-charge | Recurring plan service |
| `vouchers` | Kho voucher & điểm | Danh sách voucher hợp lệ, áp mã/đổi điểm, chống reuse/abuse; promo backend rule | Voucher/rewards |
| `taskChecklist` | Checklist & bằng chứng | Checklist/evidence theo service và task; kết quả luôn gắn assignment | Work checklist/evidence |


## C11. Ultimate • Chat và an toàn (4 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `chatAttachment` | Chat đính kèm ảnh/vị trí | Gửi file/ảnh/vị trí theo quyền, quota, antivirus/media scanning tùy thiết kế | Chat/media |
| `helpFaq` | FAQ từng chủ đề | FAQ booking/payment/partner/đổi lịch/huỷ/an toàn | Help CMS |
| `incidentCenter` | Xử lý tình huống | Báo tình huống phát sinh, phân cấp mức độ, tạo case/ticket | Safety incidents |
| `contactPrivacy` | Bảo mật thông tin liên hệ | Mặc định ẩn liên hệ, chỉ mở theo quan hệ task đã xác nhận và policy | Contact privacy |


## C12. Ultimate • Partner Pro (6 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `availabilityPro` | Lịch rảnh theo giờ | 7 ngày/tuần start/end, ngày nghỉ, buffer 45p demo; production travel-aware | Partner schedule/conflict |
| `partnerTraining` | Partner Academy | Partner Academy modules/quizzes; lưu completion/version | Training |
| `partnerAgreement` | Thỏa thuận Partner | Chấp thuận hợp đồng theo version/time, chính sách production phải được rà soát | Partner legal consent |
| `bankAccounts` | Ngân hàng Partner | Danh sách tài khoản rút, mask thông tin, add/remove/verify theo provider | Partner payout account |
| `bankAdd` | Thêm ngân hàng demo | Form bank & account holder, validation, lưu qua provider an toàn | Partner payout account |
| `payoutDetail` | Theo dõi rút tiền demo | Chi tiết trạng thái withdrawal request, mốc processing/failed/paid | Payout status |


## C13. Ultimate • QA (2 routes)


| Route ID HTML | Tên màn hình gốc | Yêu cầu triển khai Flutter (hành vi chính) | Nguồn dữ liệu |
|---|---|---|---|
| `appChangelog` | Điểm mới phiên bản V3 | Thông tin nâng cấp demo, phiên bản và lịch sử phát hành | App metadata |
| `diagnostics` | Chẩn đoán và xuất state | Diagnostics dev, snapshot dữ liệu đã khử PII, thông tin build/environment | Internal diagnostics |


# PHẦN D — DOMAIN/BUSINESS FLOW BẮT BUỘC

## D1. Xác thực sau Login/Register đã có

**Đừng sửa lại Login/Register.** Hoàn tất chuỗi sau:

```text
App Splash
  ├─ Không có session → Login Flutter hiện tại
  └─ Có session → Refresh nếu cần → GET /me → Load roles & flags
                                        ├─ Chưa verified email → Email OTP
                                        ├─ Customer → Customer Shell
                                        └─ Partner approved + chọn mode → Partner Shell
```

Register hiện tại cần thu tên/email/số điện thoại liên hệ/password (nếu đã hỗ trợ thì giữ nguyên); xác minh qua **OTP email** (6 số, TTL ví dụ 5 phút, resend cooldown 60s; backend config quyết định). Phone lưu E.164; **không phát SMS OTP trong bản đầu**. Forgot Password: request email → reset OTP → reset token riêng → new password → invalidate session cũ theo security policy. Không trả OTP trong API response, không log OTP, không sử dụng mã demo `123456` trong production. Test expired/duplicate/wrong/too many/cooldown/not found/locked.

## D2. Danh mục 8 dịch vụ và Dynamic Smart Forms

Nguồn HTML gồm đúng 8 dịch vụ demo sau; giá `from` chỉ là **giá minh họa**. Khi dựng thật, service catalog, dynamic form schema và pricing rule phải cấu hình được từ backend hoặc schema versioned.

| Service ID | Dịch vụ | Field/form cần có | Kiểm tra bắt buộc |
|---|---|---|---|
| `clean` | Dọn nhà | `area`, `rooms`, `bathrooms`, `supplies` | m² > 0, số phòng không âm, dụng cụ hợp lệ |
| `deep` | Tổng vệ sinh | `area`, `rooms`, `windows` | m² > 0, lựa chọn cửa kính hợp lệ |
| `repair` | Sửa chữa | `device`, `issue`, `urgency`, ảnh liên quan | mô tả vấn đề đủ rõ, có thể request khảo sát |
| `move` | Chuyển nhà | `pickup`, `dropoff`, `floor`, `elevator`, `boxes` | pickup/dropoff bắt buộc và khác nhau, số thùng hợp lệ |
| `ac` | Vệ sinh máy lạnh | `units`, `type`, `access` | units >= 1, phụ phí theo backend |
| `shop` | Đi chợ hộ | `shoppingList`, `budget`, `receipt` | danh sách không rỗng, ngân sách > 0, rõ tiền mua hàng vs phí dịch vụ |
| `pets` | Chăm thú cưng | `animal`, `count`, `care` | count >= 1, công việc đủ thông tin |
| `it` | IT Support | `device`, `issue`, `remote` | thiết bị/vấn đề/hình thức bắt buộc |

**Nguyên tắc:** Form dùng chung framework nhưng field khác theo loại dịch vụ. Server validate lại theo schema và service area. UI phải phân biệt thông tin nào ảnh hưởng báo giá, tránh lấy các công thức tính mẫu trong HTML làm giá chính thức.

## D3. Booking nhiều bước — hoàn chỉnh, không mất dữ liệu

```text
Chọn Service → Dynamic Form → Ảnh (tuỳ dịch vụ)
             → Chọn Address/Map → Date/Time/Duration
             → One-time hoặc Recurring → Extras/Partner Preference
             → Apply Voucher → Request Server Quote
             → Review + Policy → Create/Reserve Booking
             → Payment sandbox intent → Payment status từ backend
             → MATCHING → Partner nhận → ACTIVE TASK
```

- Draft lưu an toàn với schema version, tiếp tục khi app khởi động lại; không lưu payment secrets.
- Khi thay `service/details/address/date/time/duration/extras/voucher` → **invalidate quote** và lấy lại giá; quote version/expiresAt do backend cấp.
- Quote V3 HTML hết hạn **10 phút chỉ là ví dụ**; production deadline theo backend.
- Voucher `WELCOME20`, `TASKLY30`, điểm đổi mẫu **không phải chính sách giá thật**; backend quản lý eligibility, ownership, expiry, minSpend, stacking, exhausted, used.
- Với recurring: once/weekly/biweekly/monthly; recurrence theo timezone chính xác; tạo lượt tiếp theo dưới dạng draft hoặc đơn cần xác nhận; HTML **không tự trừ tiền**, production chỉ tự động nếu có thỏa thuận/thiết kế thanh toán riêng được phê duyệt.
- Thanh toán sandbox không được chuyển sang success chỉ vì deep-link `?success=true`; xác minh bằng server/webhook và idempotency, hiển thị pending/failed/retry/cancelled.
- Thời điểm tạo task so với payment hold phải được quy định rõ bởi backend, hỗ trợ hết hạn/rollback an toàn.

## D4. Quy trình Task & Assignment (từ HTML)

```text
DRAFT → POSTED → MATCHING → ACCEPTED → TASKER_ON_THE_WAY
       → ARRIVED → IN_PROGRESS → COMPLETED → PAID
```

Ngoại lệ HTML: `CANCELLED`, `DISPUTED`, `REFUNDED`; no-show/rematching/payment adjustment là **subflows** phải có lịch sử và audit. `PAID` trong UI demo hiển thị “Hoàn tất · Đã giải ngân”, nhưng production phải phân biệt **TASK COMPLETED**, **PAYMENT CAPTURED**, **ESCROW HELD**, **RELEASED**, **PARTNER SETTLED** nếu chúng là các sự kiện khác nhau. Không gộp business data chỉ để khớp label prototype.

Quy tắc bất biến:

- Chỉ 1 Partner active tại một thời điểm; nhận job atomic/optimistic locking; người thứ hai nhận cùng task phải có `409` rõ ràng.
- Partner phải có KYC approved + skills + service area + lịch trống + account standing đủ điều kiện.
- Customer chỉ sửa trực tiếp trước assignment hoặc khi rule cho phép; sau ACCEPTED phải tạo Change Request.
- Partner chỉ được cập nhật task đã được phân công và theo thứ tự status hợp lệ.
- Check-in cần permission/location có giới hạn độ chính xác, thời gian server, chống spoof ở mức khả thi.
- Check-out/evidence/timestamp tùy cấu hình service, không được complete rỗng khi evidence required.
- Customer confirm completion hoặc report; timeout/auto-settlement nếu có phải chạy server scheduler và rule rõ ràng.
- Cancel/no-show/rematch phải có reason, snapshot fee/refund và không duplicate release/refund.
- Mọi transition lưu event history: `actor`, `timestamp`, `from`, `to`, `reason`, `requestId`.

## D5. Change Request và Payment Adjustment hai chiều

```text
Customer tạo request đổi lịch/thời lượng/phạm vi
→ Partner ACCEPT / REJECT
→ Nếu ACCEPT, backend tính delta và lập revised quote
→ Customer ACCEPT giá & điều khoản thay đổi cuối cùng
→ Nếu delta > 0: extra payment intent/authorization phù hợp
→ Nếu delta < 0: refund adjustment phù hợp
→ Chỉ khi đủ điều kiện, commit task revision/version và phát notification
```

HTML mô phỏng sequence này và nút “Xác nhận điều chỉnh DEMO”; production không được tự động ghi tiền đã thanh toán trong client. Xử lý `request expired`, `conflicting change request`, `task completed in meantime`, `race`, `payment fails`, `partner rejects`, `customer rejects`, `resend notification`.

## D6. Matching/No-show/Rematching

- Matching ưu tiên skills/area/availability + hợp lệ giờ đến; không hiển thị PII của Customer trên job feed công khai.
- Nhận việc atomic. Nếu hết thời gian tìm kiếm, Customer chọn **tiếp tục tìm / đổi lịch / hủy** theo rule.
- Partner late/no-show: Customer báo vấn đề → ghi nhận case → support/ops xử lý; không tự khẳng định no-show chỉ từ một nút.
- Rematch phải thu hồi assignment trước, audit/notify và tránh double active assignment; trạng thái payment giữ/refund theo server.
- Partner bị no-show report có quyền phản hồi và gửi bằng chứng phù hợp; quyết định do hỗ trợ/Admin Web.

## D7. Chat, Notification, Safety

- Chat chỉ mở khi có quan hệ task/role hợp lệ; đóng theo lifecycle/policy. Tin nhắn text/image/location, paginated, ack/delivery/read, reconnect, dedup, upload validation/quota.
- Push: task accepted/late/on-the-way/arrived/started/completed, payment, message, KYC, dispute, payout; deep link vẫn phải authorize.
- Contact privacy: mask điện thoại/email trước assignment; chỉ hiện sau khi đủ điều kiện và có thời hạn cần thiết.
- Ticket/Complaint/Report: category + linked task + attachments + status + conversation + decision; Customer/Partner không được truy cập ticket của người khác.
- Safety: cách liên hệ hỗ trợ, báo bất thường, chặn người dùng, xử lý nhiệm vụ không an toàn. Không đưa tính năng liên hệ khẩn giả khiến người dùng tưởng là dịch vụ cấp cứu được vận hành.

## D8. Partner KYC, Academy, Availability, Earnings

```text
Become Partner → Personal Info → KYC (document + selfie if configured)
→ Skills → Areas → Availability → Training/Quiz → Agreement(versioned)
→ Submit → Admin Web Review → APPROVED / REJECTED → Jobs
```

- KYC images private storage, access control, upload signed URL, retry, retention/deletion policy.
- Academy quiz trong HTML là **demo một câu hỏi**; production nội dung/rubric/required training do Admin quản lý.
- Agreement lưu version, acceptedAt, locale và userId; HTML `v1.0` chỉ là ví dụ.
- Availability: weekly day + start/end + days off; buffer di chuyển **45 phút trong HTML là giá trị demo**, khi triển khai phải dựa service/location/policy và có thể tính ETA provider.
- Earnings: tiền đang chờ, sẵn dùng, total, payout histories, fee/adjustment; số dư tính server ledger.
- Bank account: chỉ hiển thị masked, không lưu credentials/raw details trong logs; sử dụng provider/secure storage phù hợp.
- Payout requests có idempotency, eligibility, hold, pending/approved/failed/paid, audit; **chỉ sandbox trước**.
- Chức năng Withdrawal có thể tắt `PAYOUT_ENABLED=false` cho Closed Beta nếu backend/provider chưa sẵn sàng.

## D9. Rewards, AI, Community và tính năng không chặn MVP

- Rewards và voucher trong HTML có demo wallet, WELCOME20/TASKLY30; có thể giữ nhưng **feature flag off** khi chưa có backend ledger/rules.
- AI Draft là một mẫu gợi ý từ khóa; nếu chưa có AI backend an toàn thì dùng UI disabled + scope rõ; không tuyên bố đó là AI thật.
- Community feed, referrals, loyalty nâng cao, subscription, doanh nghiệp B2B, AI định giá không nằm trong 94 route lõi và **không được tự phát triển ngoài scope** nếu chưa được phê duyệt.
- PWA/WebView không thay thế Flutter production.

---


# PHẦN E — BACKEND/API & DATA MODEL DỰ KIẾN

> **Các endpoint dưới đây là hợp đồng ĐỀ XUẤT**, không phải khẳng định backend TaskLy hiện đang có. AI phải scan controllers/OpenAPI/schema thật, lập mapping và thích ứng; không rename existing API tùy tiện.

## E1. Gợi ý API contract theo feature

| Domain | Method / endpoint đề xuất | Mục đích |
|---|---|---|
| Identity | `GET /api/v1/users/me` | Hồ sơ, roles, verification, account standing |
| Auth | `POST /api/v1/auth/email/verify` | Verify email OTP |
| Auth | `POST /api/v1/auth/email/resend` | Gửi lại OTP |
| Auth | `POST /api/v1/auth/password/forgot` | Xin OTP reset, response trung tính |
| Auth | `POST /api/v1/auth/password/verify-otp` | Đổi OTP thành reset token |
| Auth | `POST /api/v1/auth/password/reset` | Đặt lại password bằng token |
| Auth | `POST /api/v1/auth/refresh` | Refresh token nếu backend dùng mô hình này |
| Services | `GET /api/v1/services` | Catalog + filters/service area |
| Services | `GET /api/v1/services/{id}` | Detail và form schema |
| Addresses | `GET/POST /api/v1/addresses` | Danh sách / tạo địa chỉ |
| Addresses | `PATCH/DELETE /api/v1/addresses/{id}` | Sửa / xóa |
| Quote | `POST /api/v1/quotes` | Server quote, expiresAt, snapshot |
| Booking | `POST /api/v1/tasks` | Tạo booking với quote id và idempotency |
| Booking | `GET /api/v1/tasks` | List theo role/status |
| Booking | `GET /api/v1/tasks/{id}` | Chi tiết task |
| Booking | `PATCH /api/v1/tasks/{id}` | Edit khi hợp lệ |
| Booking | `POST /api/v1/tasks/{id}/cancel` | Preview/submit cancellation nên tách nếu cần |
| Matching | `GET /api/v1/tasks/{id}/matching` | Matching state |
| Matching | `POST /api/v1/tasks/{id}/rematch` | Request rematch |
| Partner jobs | `GET /api/v1/partner/jobs` | Feed eligible jobs |
| Partner jobs | `POST /api/v1/partner/jobs/{id}/accept` | Atomic accept |
| Partner work | `POST /api/v1/tasks/{id}/journey/start` | Bắt đầu di chuyển |
| Partner work | `POST /api/v1/tasks/{id}/check-in` | GPS/time check-in |
| Partner work | `POST /api/v1/tasks/{id}/start` | Start work |
| Partner work | `POST /api/v1/tasks/{id}/complete` | Evidence/checklist completion |
| Customer completion | `POST /api/v1/tasks/{id}/confirm-completion` | Customer confirm |
| Changes | `POST /api/v1/tasks/{id}/change-requests` | Tạo yêu cầu thay đổi |
| Changes | `POST /api/v1/change-requests/{id}/respond` | Partner accept/reject |
| Changes | `POST /api/v1/change-requests/{id}/confirm` | Customer final consent |
| Payment | `POST /api/v1/payments/intents` | Payment provider intent |
| Payment | `GET /api/v1/payments/{id}` | Server-verified status |
| Payments | `GET /api/v1/users/me/transactions` | Customer history |
| Recurring | `GET/POST /api/v1/recurring-plans` | Listing/create |
| Recurring | `PATCH /api/v1/recurring-plans/{id}` | Pause/resume/cancel/next draft |
| Vouchers | `GET /api/v1/vouchers/eligible` | Voucher có thể áp |
| Reviews | `POST /api/v1/tasks/{id}/reviews` | Review hai chiều |
| Chat | `GET /api/v1/tasks/{id}/messages` | Pagination |
| Chat | `POST /api/v1/tasks/{id}/messages` | Send with idempotency |
| Notification | `GET /api/v1/notifications` | Inbox |
| Notification | `PATCH /api/v1/notifications/{id}` | Read |
| Support | `GET/POST /api/v1/support/tickets` | Ticket list/create |
| Dispute | `POST /api/v1/tasks/{id}/disputes` | Tạo tranh chấp |
| Partner | `GET /api/v1/partner/me` | Partner profile |
| Partner | `PATCH /api/v1/partner/me` | Skills/areas/availability theo DTO phù hợp |
| Partner | `POST /api/v1/partner/kyc` | Submit KYC, media references |
| Partner | `GET /api/v1/partner/jobs/schedule` | Accepted tasks + calendar |
| Partner | `GET /api/v1/partner/earnings` | Dashboard earnings |
| Partner | `GET /api/v1/partner/ledger` | Transactions |
| Partner | `GET/POST /api/v1/partner/payouts` | Payout sandbox |
| Partner | `GET/POST /api/v1/partner/bank-accounts` | Bank account provider token |
| Media | `POST /api/v1/media/presign` | Get signed upload target |
| Config | `GET /api/v1/app/config` | Feature flags, min version, status copy |

Không nhất thiết tạo 50 controller. Ưu tiên domain separation, service-level authorization, validation và OpenAPI khớp app hiện tại.

## E2. Domain entities (tham khảo; chỉ bổ sung entity thiếu)

- `User`, `UserRole`, `UserSession`, `EmailVerification`, `PasswordReset`.
- `PartnerProfile`, `KycSubmission`, `PartnerSkill`, `PartnerServiceArea`, `WeeklyAvailability`, `BlockedDate`, `TrainingCompletion`, `AgreementAcceptance`.
- `Service`, `ServiceCategory`, `ServiceFormSchema`, `ServiceField`, `PricingRule`, `PriceQuote`.
- `Address`, `BookingDraft` (nếu backend lưu), `Task`, `TaskEvent`, `TaskAssignment`, `TaskChecklist`, `TaskEvidence`.
- `ChangeRequest`, `Cancellation`, `NoShowCase`, `RematchAttempt`.
- `PaymentIntent`, `PaymentTransaction`, `PaymentAdjustment`, `Refund`, `LedgerEntry`, `PayoutRequest`, `BankAccountToken`.
- `RecurringPlan`, `Voucher`, `VoucherRedemption`, `RewardWallet/PointsLedger`.
- `Conversation`, `ChatMessage`, `MessageAttachment`, `Notification`, `DevicePushToken`.
- `Review`, `FavoritePartner`, `SupportTicket`, `Dispute`, `Report`, `AuditLog`, `FeatureFlag`.

Các quan hệ phải có ownership rõ và optimistic locking khi cần; không dựa vào tên người dùng làm identity.

## E3. Mapping trạng thái & DTO

- Task status HTML: `DRAFT`, `POSTED`, `MATCHING`, `ACCEPTED`, `TASKER_ON_THE_WAY`, `ARRIVED`, `IN_PROGRESS`, `COMPLETED`, `PAID`, `CANCELLED`, `DISPUTED`, `REFUNDED`.
- Payment từ demo sử dụng `HELD`, `RELEASED` và thanh toán lỗi; production map qua payment-state machine thực.
- KYC ví dụ: `NOT_STARTED`, `DRAFT`, `SUBMITTED`, `UNDER_REVIEW`, `APPROVED`, `REJECTED` (map theo backend).
- Change Request: `REQUESTED`, `PARTNER_ACCEPTED`, `PARTNER_REJECTED`, `CUSTOMER_CONFIRMED`, `PAYMENT_ADJUSTMENT_PENDING`, `APPLIED`, `CANCELLED`, `EXPIRED` (đề xuất).
- Payout: `REQUESTED`, `PENDING`, `PROCESSING`, `PAID`, `FAILED`, `CANCELLED` (đề xuất).

Một DTO mỗi domain phải có `id`, `owner/actor`, `version` nếu cập nhật cạnh tranh, createdAt, updatedAt, status, mô tả lỗi máy đọc được; server validate all transitions.

## E4. Security & Privacy

- JWT/auth hiện tại; role CUSTOMER/PARTNER theo nguồn backend, object-level access cho từng task/message/address/payment.
- Password hash server BCrypt/Argon2 theo setup, email OTP HMAC/hash + TTL + rate limit; không để API verify không giới hạn attempt.
- Secure token storage trên mobile; refresh token rotation/session invalidation nếu kiến trúc hỗ trợ.
- Webhook signature verification, replay protection/idempotency; mọi số tiền lấy từ DB/quote server.
- PII và KYC: masked/least-privilege, media private, retention, audit, no raw passwords/OTP/tokens in logs.
- Consent: terms/privacy version + `acceptedAt`; account deletion/export request và support policy hợp lệ.
- Session expiry giữa thao tác: refresh có retry một lần, giữ draft, tránh tạo booking/payment kép.

---


# PHẦN F — CÁC PHASE THỰC THI NHANH, KHÔNG PHÁ DỰ ÁN

## F0 — Baseline (BẮT BUỘC)

- Tạo git branch riêng `feature/taskly-ultimate-v3` từ branch hiện tại.
- Snapshot `flutter analyze`, `flutter test`, backend tests/build; ghi nhận failures có sẵn trước khi sửa.
- Lập route mapping toàn bộ Phần C; chỉ implement MISSING/PARTIAL.
- Khoanh vùng Login/Register bằng tests và danh sách file protected.
- Import Design Tokens và brand assets dùng lại trong code (không rewrite auth).

## F1 — Auth follow-ups + boot

Email OTP, resend/cooldown, Forgot/Reset, Splash, session restore, GET `/me`, role/mode + Customer App Shell. E2E auth phải PASS trước.

## F2 — Customer catalog/profile/address

Home, service grid, search/filter, service detail, profile, saved addresses, basic location/map permission. Service source phải là API.

## F3 — Smart Booking core

Dynamic 8 service schemas, upload, schedule, location, draft, quote, price breakdown/TTL, validation. Mỗi loại dịch vụ có ít nhất 1 happy test + 1 invalid test.

## F4 — Payment sandbox & task creation

Review, payment intent, backend-verified result, creation idempotency, matching state; no duplicate charge/task on retry.

## F5 — Partner onboarding & eligibility

Become Partner, KYC, skills, areas, weekly availability, blocked dates, Academy/agreement (sau khi chính sách duyệt), Admin Web KYC action qua backend.

## F6 — Matching + complete task lifecycle

Jobs feed, atomic accept, schedule/travel conflict, journey/check-in/start/evidence/complete, Customer confirm, updated task history; two-device E2E.

## F7 — Customer ↔ Partner communication

Chat realtime, attachments, notifications/push, links/status, offline reconnect, privacy masking.

## F8 — Change/Cancel/No-show/Rematch/Refund

Change Request 2 approvals + adjustment sandbox, cancellation fee preview, no-show report, rematch, dispute/decision, refund rule/gateway sandbox; adversarial E2E.

## F9 — Reviews/Favorites/Recurring/Rewards

Reviews two directions, favorite, book again, recurring plan, voucher wallet if backend ready. Flag optional features off by default.

## F10 — Partner finance

Earnings ledger, fee transparency, payout account, withdrawal sandbox, transaction status, performance.

## F11 — Support/Safety/Profile/UX polish

Ticket, complaint, report, contact privacy, FAQ, privacy settings, help and deletion, all UI states, animation nhẹ, responsive, A11y.

## F12 — QA + Closed Beta

Unit/widget/integration/E2E, security/authorization, Android real device, offline, push, crash/performance, feature flags, release config, environment separation. Không ghi READY khi P0/P1 còn block.

## F13 — OPTIONAL (không chặn Beta)

Full Rewards economy, advanced AI, community, referral, deep analytics, subscriptions; chỉ sau khi product scope và business rules được duyệt.

**Quy tắc auto work:** AI agent có thể chạy liên tục từng phase trong repository mà không phải hỏi câu nhỏ lặp lại; nhưng phải dừng xin xác nhận nếu cần xoá dữ liệu, migrate phá schema, đổi provider thanh toán thật, chuyển tiền, xử lý giấy tờ thật hoặc thay chính sách giá/pháp lý. Mỗi phase tóm tắt: files changed, APIs reused/new, tests pass/fail, remaining blockers; tự sửa lỗi rồi mới đi tiếp.

---


# PHẦN G — ACCEPTANCE TESTS END-TO-END

## G1. Main Customer → Partner → Customer flow

```gherkin
Given Customer đã đăng nhập và email đã xác minh
And Partner đã được phê duyệt, có skill/area/availability phù hợp
When Customer chọn dịch vụ và nhập dynamic details hợp lệ
And chọn địa chỉ, thời gian, nhận quote server còn hạn
And hoàn tất payment sandbox
Then task có ID riêng và trạng thái matching theo policy
When Partner xem feed và nhận task
Then task chuyển ACCEPTED và Customer thấy Partner được phân công
When Partner lần lượt On the way, Check-in, Start và Submit completion evidence
Then lịch sử task hiển thị đúng cho cả hai phía
When Customer xác nhận hoàn thành
Then transaction được giải ngân theo chính sách backend và Partner thấy ledger
When hai bên đánh giá
Then review hiện trên task và profile đúng người nhận
```

## G2. Validation theo dịch vụ

- Dọn nhà 65m², 2 phòng, chọn dụng cụ: quote theo schema thật và không mất dữ liệu khi back.
- Vệ sinh máy lạnh units=3, type treo tường: quote khác units=1; không dùng tiền demo hardcoded.
- Chuyển nhà thiếu dropoff → chặn next; có pickup/dropoff valid → next.
- Đi chợ hộ thiếu danh sách/budget invalid → báo lỗi; phải hiển thị tách ngân sách mua hàng vs công dịch vụ.
- Service ngoài vùng hỗ trợ → không thể confirm booking, UI nêu hướng giải quyết.

## G3. Payment + voucher + quote

- Sửa giờ/địa chỉ/options → quote cũ invalidated → lấy quote mới.
- Voucher hết hạn/đã dùng/không đủ điều kiện → hiển thị lý do; backend không trừ tiền sai.
- Payment callback trùng 2 lần, double tap, mạng chập chờn → không tạo charge/task kép.
- Redirect báo success nhưng backend pending/fail → UI chờ hoặc báo lỗi, không tạo PAID.

## G4. Concurrency & eligibility

- Hai Partner accept cùng Task: chỉ 1 thành công, 1 thấy 409 và list refresh.
- Partner KYC rejected/suspended, skill thiếu, ngoài area, lịch trùng hoặc buffer không đủ → accept bị từ chối bởi **server**.
- Customer cố update/cancel task user khác → 403.
- Partner cố start/complete task không assigned → 403.

## G5. Change, No-show, Cancellation, Dispute

- Change Request Partner reject → dữ liệu task cũ không bị sửa.
- Partner accept nhưng Customer không xác nhận → task cũ giữ nguyên; request pending/expire.
- Customer xác nhận + extra charge fail → không commit giá mới hoặc phải rollback an toàn.
- Partner no-show → Case + Support + Rematch hoặc Cancel theo policy; không duplicate assignment.
- Cancel cuối ngày/late: preview fee/refund dựa backend snapshot.
- Dispute resolved refund: ledger có event, Customer thấy trạng thái, Partner không được tự quyết toán.

## G6. KYC & finance

- KYC submit thiếu ảnh hoặc upload lỗi → không chuyển APPROVED.
- KYC rejected → Partner thấy lý do, resubmit; không nhận job khi chưa đủ quyền.
- Training/Agreement incomplete khi required → chặn nhận job.
- Withdrawal > available balance → reject; double submit → một payout request.
- Bank account masking, không lộ số tài khoản đầy đủ trên list/log.

## G7. UX/Lifecycle

- Cold start với refresh token hợp lệ → tới đúng home/mode.
- Hết phiên trong checkout → vẫn giữ booking draft; không trả success giả.
- Denied location → nhập địa chỉ thủ công (nếu service hỗ trợ).
- Offline đang thanh toán/accept/check-in/complete → không báo thao tác thành công.
- Push tap từ app kill → auth/authorization rồi mới navigate đúng task.
- Small Android 360x800 & iPhone SafeArea: không overflow, keyboard không che CTA, screen reader labels hợp lệ.

## G8. Test commands và Definition of Done

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
# Backend Maven, chỉ khi repo đang dùng Maven:
./mvnw test
./mvnw package -DskipTests
```

Thêm integration/E2E thật theo stack test hiện có, không ghi “PASS” nếu chưa chạy. Lưu bằng chứng vào:

```text
docs/taskly-v3-test-matrix.md
docs/taskly-v3-bugs.md
docs/taskly-v3-release-checklist.md
```

Chỉ đánh dấu **TASKLY CLOSED BETA READY** khi các luồng P0 đi từ app đến backend thật chạy; UI 94 route được đối chiếu; không có P0/P1 blocker; migration/an toàn dữ liệu có xác nhận; build và smoke test thiết bị đạt yêu cầu.

---


# PHẦN H — OUTPUT CỤ THỂ CỦA AI AGENT

Phải trả và cập nhật trong repository:

1. `docs/taskly-v3-current-audit.md`: màn/API/file hiện có vs chưa có.
2. `docs/taskly-v3-route-mapping.md`: **toàn bộ 94 HTML routes** → Flutter routes/widgets/backend endpoints/states/tests.
3. `docs/taskly-v3-api-gap.md`: current API, fields, missing, proposed minimal additions.
4. `docs/taskly-v3-design-system.md`: token, shared widgets, assets, responsive.
5. `docs/taskly-v3-business-rules.md`: lifecycle, assignment, prices, cancel, refund, KYC, privacy; **demo assumption vs approved rule**.
6. `docs/taskly-v3-test-matrix.md`: từng happy/error/permission test và kết quả thật.
7. Flutter modules + integration đã triển khai, tái sử dụng Login/Register nguyên trạng.
8. Backend endpoint/service/migrations **chỉ khi thiếu**, có OpenAPI, validation và test.
9. `docs/taskly-v3-release-checklist.md`: readiness, blockers, feature flags, dependency môi trường.
10. Final report gồm: `IMPLEMENTED / PARTIAL / BLOCKED / NEEDS_APPROVAL`, file changed, build results, next actions.

## H1. Những thứ phải được tắt/khóa production

- `developer`, `testGuide`, `screenIndex`, `diagnostics`, mô phỏng success, KYC approve demo, Reset local data, fake payouts.
- OTP `123456`, mock identity, mock credit balances, voucher demo có giá trị quy đổi, fake contact location.
- Không đưa mock Customer và mock Partner cùng tài khoản vào server; tạo account/role thật hoặc test accounts có quyền rõ.

## H2. Checklist cuối để đối chiếu HTML

- [ ] 94 route được mapping; route nội bộ debug không phát hành.
- [ ] Login/Register không bị ghi đè hoặc phá logic.
- [ ] Email OTP + Forgot/Reset + session restore hoạt động.
- [ ] 8 service schemas được test đầy đủ.
- [ ] Booking + quote + sandbox payment + matching liên thông.
- [ ] Partner KYC/skills/availability/training/agreement được guard.
- [ ] Atomic job accept + lifecycle + evidence + customer confirm.
- [ ] Cancel/change/no-show/rematch/dispute/refund có handling.
- [ ] Chat/notifications/support và privacy theo task.
- [ ] Reviews/favorites/book again/recurring/voucher theo feature flags.
- [ ] Partner earnings/ledger/bank/payout sandbox đúng số từ server.
- [ ] UI loading/empty/error/offline/permission, responsive, keyboard, accessibility.
- [ ] Android build + tests + E2E qua server; ít nhất 1 test 2 account/2 thiết bị hoặc client độc lập.
- [ ] Không lưu secret hoặc KYC trong localStorage/log; không trust client for payment/roles.

---

# PHẦN I — LỆNH BẮT ĐẦU THỰC THI (COPY CHO CODING AGENT)

```text
Hãy đọc file TASKLY_ULTIMATE_V3_FULL_FLUTTER_BUILD_MASTER_PROMPT.md này và (nếu có trong repo) toàn bộ file design-reference/TASKLY_ULTIMATE_MOBILE_INTERACTIVE_V3.html.

Triển khai TaskLy Flutter Customer + Partner đúng theo 94 route, business flows và acceptance tests trong prompt. Đây là project ĐÃ CÓ Login và Register: tuyệt đối không viết lại hoặc phá hai màn đó. Admin ở Web riêng.

BƯỚC 1: Scan tất cả Flutter + backend hiện tại, xác định công nghệ đang dùng, liệt kê source file, screens, state management, routes, APIs, DTOs, migrations. Lập bảng route mapping 94 màn HTML → EXISTING/PARTIAL/MISSING, ưu tiên reuse.

BƯỚC 2: Tạo design tokens/shared widgets, giữ nguyên auth có sẵn. Triển khai từng phase F1 → F12 theo vertical slices, mỗi slice từ UI → state → backend → tests; không dựng toàn bộ UI giả trước.

BƯỚC 3: Khớp UI/UX TaskLy V3 (emerald, mint, cards, robot 3D nhẹ) và tất cả flows Customer–Partner. Nút nào chưa có API thì đánh dấu rõ blocker/flag, không tạo fake success.

BƯỚC 4: Sau từng phase chạy flutter analyze, flutter test, build APK debug và backend test tương ứng. Sửa lỗi; không phá code đang chạy. Ghi rõ các API mới, thay đổi DB, màn hoàn tất, known issues.

BƯỚC 5: Tạo báo cáo cuối + feature matrix. Chỉ tuyên bố Closed Beta Ready nếu tất cả P0 core E2E với backend thật qua được. Dừng xin xác nhận nếu cần thay đổi phá tương thích database, tiền, KYC chính thức hoặc pháp lý.

BẮT ĐẦU NGAY BẰNG AUDIT VÀ PHASE 1; không tạo repo mới, không thay thế Login/Register.
```
