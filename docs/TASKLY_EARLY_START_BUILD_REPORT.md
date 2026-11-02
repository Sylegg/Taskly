# BÁO CÁO TÍNH NĂNG: ĐẾN SỚM, CHECK-IN, XIN BẮT ĐẦU SỚM, KHÁCH XÁC NHẬN & BẢO TOÀN LỊCH CÁCH CA 60 PHÚT

## 1. TỔNG QUAN HỆ THỐNG ĐÃ TRIỂN KHAI

Hệ thống TaskLy đã được nâng cấp đồng bộ trên cả **4 tầng kiến trúc** hiện hữu:
1. **Backend (Spring Boot 4 / Java 21 / PostgreSQL / H2)**
2. **Admin Web (Next.js 15 / TypeScript / Tailwind CSS)**
3. **Flutter Customer App (`Taskly-main`)**
4. **Flutter Partner App (`Taskly-main`)**

---

## 2. CHI TIẾT CÁC TÍNH NĂNG VÀ MÔ HÌNH NGHIỆP VỤ

### 2.1. Tách biệt 8 mốc thời gian vận hành độc lập (Không ghi đè lịch gốc)
- `originalScheduledStartAt`: Giờ bắt đầu ca gốc do khách đặt ban đầu.
- `originalScheduledEndAt`: Giờ kết thúc ca gốc do khách đặt ban đầu.
- `acceptedAt`: Thời điểm Partner nhận đơn (được phép nhận từ trước nhiều ngày).
- `checkedInAt`: Thời điểm Partner check-in tại nhà khách (cửa sổ mặc định 15 phút trước giờ hẹn).
- `approvedStartAt`: Giờ bắt đầu ca mới được xác nhận sau khi khách hàng đồng ý bắt đầu sớm.
- `expectedEndAt`: Giờ kết thúc dự kiến được tính lại (`approvedStartAt + durationMinutes`), thời lượng và giá trị ca làm luôn được bảo toàn tuyệt đối.
- `actualStartedAt`: Thời điểm server ghi nhận Partner chính thức bấm bắt đầu làm việc.
- `verifiedActualEndAt`: Thời điểm hoàn tất công việc được nghiệm thu.

### 2.2. Cửa sổ Check-in độc lập (15 phút)
- Partner được phép đến sớm và bấm **Tôi đã đến (Check-in)** trong vòng `earlyCheckinWindowMinutes` (mặc định 15 phút trước lịch hẹn).
- Nếu bấm sớm hơn 15 phút, Backend từ chối với mã lỗi `CHECKIN_TOO_EARLY`.
- Check-in chỉ cập nhật tọa độ/thời điểm có mặt (`checkedInAt`), **KHÔNG** tự động bắt đầu tính giờ làm việc.

### 2.3. Quy trình Xin bắt đầu sớm & Quyền quyết định của Khách hàng
- Partner có thể gửi đề nghị làm sớm trước giờ hẹn tối đa `maxEarlyStartMinutes` (mặc định 60 phút).
- Hệ thống hỗ trợ chọn chip lý do nhanh: "Đã có mặt sớm", "Khách nhà sẵn sàng", "Tránh giờ cao điểm" hoặc nhập lý do riêng.
- Khách hàng là **người duy nhất** có quyền phê duyệt (`APPROVE`) hoặc từ chối (`REJECT`).
- Đề nghị có thời hạn hết hạn (`expiresAt` = 15 phút hoặc thời điểm hẹn gốc, tùy mốc nào đến trước).
- Nếu Khách từ chối hoặc đề nghị hết hạn: Giữ nguyên lịch hẹn gốc, Partner chỉ được bấm bắt đầu khi đến giờ hẹn gốc.
- **Bảo toàn quyền lợi**: Thời lượng làm việc và giá dịch vụ KHÔNG thay đổi khi bắt đầu sớm.

### 2.4. Khóa nút Bắt đầu (Authoritative Server Gating)
- Đồng hồ thiết bị di động không được tin cậy; Backend Server Clock là nguồn chân lý duy nhất.
- Nút "Bắt đầu công việc" của Partner chỉ sáng khi:
  1. Đơn đã được gán cho Partner và Partner đang ACTIVE.
  2. Partner đã check-in (`checkedInAt != null`).
  3. Thời điểm hiện tại của Server >= Giờ bắt đầu hợp lệ (`approvedStartAt` nếu đã duyệt, hoặc `originalScheduledStartAt` nếu chưa/không duyệt).

### 2.5. Bảo toàn lịch đệm cách ca 60 phút (Conservative Reservation)
- Khoảng chiếm dụng phòng thủ của ca làm được tính là:
  `[min(scheduledStart, approvedStart), max(scheduledEnd, expectedEnd)] + minBufferMinutes (60 phút)`.
- Khoảng chiếm dụng phòng thủ này được giữ nguyên cho đến khi ca làm hoàn thành thực tế (`verifiedActualEndAt`), đảm bảo không chồng chéo lịch nhận đơn khác của Partner.

---

## 3. DANH SÁCH FILE THAY ĐỔI & THÊM MỚI

### A. Backend (`backend/`)
- `src/main/resources/db/migration/V75__early_arrival_and_start.sql`: Migration thêm các cột thời gian vào bảng `tasks`, tạo bảng `early_start_requests`, khởi tạo 5 tham số cấu hình vận hành trong `system_settings`.
- `src/main/java/com/taskly/settings/SystemSettingsService.java`: Quản lý 5 tham số vận hành (`minBufferMinutes`, `travelSafetyMinutes`, `earlyCheckinWindowMinutes`, `maxEarlyStartMinutes`, `earlyStartExpiryMinutes`).
- `src/main/java/com/taskly/settings/AdminSettingsController.java`: API `GET /api/v1/admin/operations/job-start-policy` và `PATCH /api/v1/admin/settings/operations`.
- `src/main/java/com/taskly/task/entity/CustomerTask.java`: Mapped các trường thời gian mới và quan hệ `EarlyStartRequest`.
- `src/main/java/com/taskly/task/entity/EarlyStartRequest.java`: Entity theo dõi vòng đời đề nghị bắt đầu sớm.
- `src/main/java/com/taskly/task/repository/EarlyStartRequestRepository.java`: Repository truy vấn request theo task và trạng thái.
- `src/main/java/com/taskly/task/EarlyStartService.java`: Xử lý toàn bộ logic nghiệp vụ check-in, xin bắt đầu sớm, khách duyệt, kiểm tra điều kiện canStart và tính toán conservative reservation.
- `src/main/java/com/taskly/task/EarlyStartController.java`: Cung cấp REST endpoints:
  - `POST /api/v1/tasks/{taskId}/check-in`
  - `POST /api/v1/tasks/{taskId}/early-start-request`
  - `POST /api/v1/tasks/{taskId}/early-start-decision`
  - `POST /api/v1/tasks/{taskId}/start`
  - `GET /api/v1/tasks/{taskId}/start-eligibility`
- `src/main/java/com/taskly/recruitment/PartnerSchedulingService.java`: Áp dụng công thức conservative interval `[min, max]` trong thuật toán xếp lịch và điều phối.
- `src/main/java/com/taskly/recruitment/RecruitmentActivationService.java`: Ghi nhận các mốc `acceptedAt`, `checkedInAt`, `actualStartedAt`, `verifiedActualEndAt` trong các bước chuyển trạng thái.
- `src/main/java/com/taskly/task/TaskActivityController.java`: Trả về trường `earlyStart` chi tiết trong API lấy activity task.
- `src/main/java/com/taskly/task/AdminTaskController.java`: Trả về các mốc thời gian và chi tiết `earlyStartRequest` cho Admin Web.
- `src/main/java/com/taskly/booking/BookingCheckout.java`: Ràng buộc hủy đơn khi `tasker_viewed_at == null`.

### B. Admin Web (`frondend/`)
- `src/components/OperationsSettings.tsx`: Giao diện cấu hình chính sách vận hành (khoảng cách ca 60m, an toàn di chuyển, cửa sổ check-in 15m, giới hạn làm sớm 60m, thời gian phản hồi 15m).
- `src/components/TaskAdmin.tsx`:
  - Cột "Lịch hẹn" hiển thị các chip/badge trạng thái: `Duyệt sớm`, `Đã đến`, `Làm thật`, `Đề nghị làm sớm`.
  - Section 3 Modal chi tiết đơn việc: Lưới hiển thị 6 mốc vận hành độc lập (`Nhận đơn`, `Check-in`, `Bắt đầu thật`, `Kết thúc thật`, `Lịch hẹn gốc`, `Giờ duyệt mới & kết thúc dự kiến`) kèm Card thông tin đề nghị bắt đầu sớm.

### C. Flutter Apps (`Taskly-main/`)
- `lib/features/task_activity.dart`:
  - **Khách hàng**: Hiển thị Card đề nghị bắt đầu sớm với giờ cũ/mới rõ ràng, ghi chú không đổi thời lượng/giá dịch vụ, 2 nút hành động "Đồng ý bắt đầu sớm" và "Giữ nguyên giờ đặt". Hiển thị thông báo khi Partner check-in đến nơi.
  - **Partner**: Phân tách rõ ràng 3 hành động:
    1. *Tôi đã đến (Check-in)*: Kiểm tra cửa sổ 15 phút, khóa nếu đến quá sớm.
    2. *Xin bắt đầu sớm*: Modal chọn chip lý do hoặc tự nhập, gửi đề nghị đến khách.
    3. *Bắt đầu công việc*: Kiểm tra điều kiện `canStart` từ Server, khóa nút và thông báo lý do nếu chưa đủ điều kiện.
  - Hiển thị đầy đủ bảng lịch hẹn với các mốc thời gian độc lập.
- `lib/features/partner/partner_jobs.dart`: Cập nhật điều hướng nút thao tác nhanh `ARRIVED` -> endpoint check-in và `IN_PROGRESS` -> endpoint start.

---

## 4. KẾT QUẢ KIỂM THỬ (QA & TEST RESULTS)

### 4.1. Backend Tests
1. **`EarlyArrivalAndStartIntegrationTest`**:
   - Số lượng test: **28 / 28 test cases PASS 100%**.
   - Kiểm tra toàn diện: Check-in quá sớm bị chặn, Check-in trong cửa sổ 15m thành công, Đề nghị làm sớm quá 60m bị chặn, Khách APPROVE đổi `approvedStartAt`, Khách REJECT giữ nguyên lịch gốc, Đề nghị hết hạn, Partner không thể bắt đầu trước giờ khi chưa duyệt, Conservative reservation bảo toàn khoảng đệm 60 phút.
2. **`PartnerScheduleBufferTest`**:
   - Số lượng test: **21 / 21 test cases PASS 100%**.
   - Kiểm tra toàn diện quy tắc cách ca 60 phút giữa các đơn việc liên tiếp.
3. **`BookingDraftControllerTest`**:
   - PASS quy tắc hủy đơn và kiểm tra xem xét của Partner.

### 4.2. Admin Web Tests
- Chạy `npm run lint` (`tsc --noEmit`): **0 errors**.
- Chạy `npm test` (`node --test tests/*.test.mjs`): **22 / 22 test cases PASS 100%**.

### 4.3. Flutter App Static Analysis
- Chạy `flutter analyze lib/features/task_activity.dart lib/features/partner/partner_jobs.dart`: **Clean (0 errors, 0 warnings)**.
