# Rà soát file trong workspace — 13/10/2026

Đã kiểm tra toàn bộ cây file (không đi theo liên kết thư mục, bỏ qua `.git`), cấu hình build, quy tắc `.gitignore`, đồ thị import Flutter/Next.js, tham chiếu trong test/script/tài liệu và tiến trình Java hiện chạy. Không xóa hoặc sửa mã nguồn trong lần rà soát này. Dung lượng là tổng kích thước file, không phải dung lượng cấp phát trên ổ đĩa.

## Kết quả chính

- 25.979 file, khoảng **15,64 GiB** trước khi tạo báo cáo.
- Build/cache chiếm phần lớn dung lượng. Có thể tạo lại nhưng cần dừng tác vụ đang chạy trước khi dọn.
- `backend/.runtime` chứa **46 JAR**, khoảng **4,28 GiB**. Script `backend/scripts/restart-current-backend.ps1` tạo một JAR có UUID mỗi lần restart và không dọn bản cũ.
- Đã xác định backend PID **2176** đang dùng `taskly-backend-fe735d35a320434c92a306d76423e1f7.jar` tại thời điểm kiểm tra. **Giữ bản này**; 45 bản còn lại là ứng viên dọn sau khi kiểm tra lại tiến trình và nhu cầu rollback.
- Có **417 file `.log`** ngoài các thư mục build/cache/dependency chính; **219 file** nằm ngay gốc workspace. Log phục vụ chẩn đoán, không phải mã nguồn. Lưu bản cần điều tra trước khi dọn; log của tiến trình đang chạy có thể còn đang được ghi.

## File nguồn chưa được nối vào luồng chạy

Đồ thị import bắt đầu từ `Taskly-main/lib/main.dart` và các entrypoint Next.js `page/layout/route`. “Không được import” chưa đủ chứng minh có thể xóa: cần xác nhận tính năng này đã bỏ hoặc đã được thay thế.

| File | Bằng chứng / đánh giá |
|---|---|
| `Taskly-main/lib/data/recruitment/secure_recruitment_persistence.dart` | Không tìm thấy import hoặc khởi tạo `SecureRecruitmentPersistence` trong app/test; được nhắc trong kế hoạch. Ứng viên mã cũ chưa tích hợp. |
| `frondend/src/components/CategoryQuantityEditor.tsx` | Không có import trong app/test/script đã kiểm tra. |
| `frondend/src/components/ServiceBookingFieldsEditor.tsx` | Không có import trong app/test/script đã kiểm tra. |
| `frondend/src/components/ServicePricingEditor.tsx` | Không có import trong app/test/script đã kiểm tra; tài liệu có nhắc. |
| `frondend/src/components/service-pricing-editor.css` | Chỉ được import bởi `ServicePricingEditor.tsx`, nên không đi vào luồng chạy hiện tại. |
| `frondend/src/components/RecruitmentAcademyAdmin.tsx` | Không có import trong app/test/script đã kiểm tra; tài liệu có nhắc. |
| `frondend/src/data/daily_milestones.json` | Không tìm thấy tham chiếu theo đường dẫn/tên file trong app/test/script đã kiểm tra. Cần xác minh có phải dữ liệu seed dự phòng không. |

## Không chạy trong app hiện tại nhưng còn được test dùng

**Giữ lại** các file này; xóa sẽ ảnh hưởng test hoặc mã mà test import gián tiếp:

- `Taskly-main/lib/features/partner/recruitment_academy.dart`: `recruitment_academy_admin_content_test.dart`.
- `Taskly-main/lib/features/partner/recruitment_identity.dart`: `recruitment_edit_window_test.dart`.
- `Taskly-main/lib/data/recruitment/mock_recruitment_repository.dart`, `recruitment_seed.dart` và ba file trong `lib/domain/recruitment/`: `recruitment_foundation_test.dart` và các import gián tiếp.
- `frondend/src/lib/recruitment-snapshot.mjs`: `frondend/tests/recruitment-snapshot.test.mjs`.

Các màn hình recruitment có test nhưng không được nối vào entrypoint hiện tại có thể là vấn đề tích hợp cần xem lại, không nên mặc định coi là rác.

## File cần giữ

- `.env`, cấu hình kết nối, cấu hình ký APK/keystore nếu có; không đọc hoặc đưa giá trị bí mật vào báo cáo.
- `backend/data/private-images/`: dữ liệu ảnh người dùng/KYC; không phải cache. `backend/data/city-area-backup.json` là bản sao dữ liệu, chưa xác minh bỏ được.
- Toàn bộ migration SQL/Java. Các migration Java được Flyway phát hiện tự động nên không cần import trực tiếp.
- Spring controller/service/entity/repository: framework có thể phát hiện tự động. `CustomerTaskRepository.java` không thấy tham chiếu trực tiếp nhưng là `JpaRepository`, chưa kết luận bỏ được.
- `pubspec.lock`, `package-lock.json`, Gradle wrapper, scripts chạy/seed, source/test và tài liệu nghiệp vụ.
- `assets/` và `frondend/public/`: icon trùng nội dung giữa mobile/web là bản dùng riêng cho hai ứng dụng. Asset có thể được dựng đường dẫn động hoặc khai báo theo thư mục, không được xóa chỉ vì không tìm thấy chuỗi tên file.
- Các thư mục iOS/macOS/Linux/Windows/web là mã nền tảng Flutter, không phải rác chỉ vì hiện đang build Android.
- APK/AAB trong `Taskly-main/build/` là sản phẩm build. Sao chép bản muốn phát hành ra nơi lưu riêng trước khi dọn build.
- `.idea`, `.vscode` có thể chứa cấu hình IDE cá nhân; không tự động xóa.

## Giới hạn kết luận

Đây là kiểm tra tĩnh và kiểm kê file, không chạy tất cả luồng chức năng để chứng minh mã chết. Không cài thêm công cụ, không thay đổi dependency và không chạy dọn dẹp. Cần kiểm tra lại tiến trình/JAR đang chạy ngay trước khi thực hiện xóa.

Chi tiết dung lượng và danh sách log/ảnh chụp được liệt kê bên dưới. Danh sách máy đọc được nằm trong `WORKSPACE_CLEANUP_FILES.csv`.


## Build/cache/dependency inventory

| Path | Files | MiB |
|---|---:|---:|
| `Taskly-main/build/` | 9074 | 8,336.26 |
| `Taskly-main/.dart_tool/` | 710 | 2,274.33 |
| `Taskly-main/android/.gradle/` | 16 | 50.56 |
| `Taskly-main/.widget_preview/` | 48 | 0.23 |
| `backend/build/` | 468 | 98.12 |
| `backend/.gradle/` | 14 | 13.82 |
| `backend/build-arrival-check/` | 393 | 2.85 |
| `backend/build-support-filter-check/` | 93 | 0.80 |
| `backend/build-support-task-check/` | 417 | 2.97 |
| `backend/build-travel-check/` | 95 | 1.09 |
| `frondend/.next/` | 305 | 293.72 |
| `frondend/.next-dev/` | 247 | 120.84 |
| `backend/.runtime/` | 46 | 4,383.93 |
| `frondend/node_modules/` | 12720 | 360.77 |

## Screenshot candidates

- `customer-debug.png` (1.41 MiB)
- `screen.png` (1.82 MiB)
- `Taskly-main/community_feed_screen.png` (1.94 MiB)
- `Taskly-main/community_feed_screen2.png` (0.11 MiB)
- `Taskly-main/community_feed_screen3.png` (0.09 MiB)
- `Taskly-main/community_screen.png` (1.40 MiB)
- `Taskly-main/community_screen2.png` (1.40 MiB)
- `Taskly-main/community_screen3.png` (1.39 MiB)
- `Taskly-main/community_screen4.png` (0.18 MiB)
- `Taskly-main/current_customer_screen.png` (1.39 MiB)
- `Taskly-main/current_screen_now.png` (0.04 MiB)
- `Taskly-main/current_user_screen.png` (0.04 MiB)
- `Taskly-main/emulator_screen.png` (0.42 MiB)
- `Taskly-main/keyboard-check.png` (0.18 MiB)
- `Taskly-main/partner_after.png` (0.33 MiB)
- `Taskly-main/partner_back_to_tab0.png` (0.33 MiB)
- `Taskly-main/partner_current.png` (0.33 MiB)
- `Taskly-main/partner_login_screen.png` (1.51 MiB)
- `Taskly-main/partner_now.png` (0.24 MiB)
- `Taskly-main/partner_offline.png` (0.26 MiB)
- `Taskly-main/partner_screen.png` (1.52 MiB)
- `Taskly-main/partner_tab1.png` (0.33 MiB)
- `Taskly-main/partner_tab2.png` (0.33 MiB)
- `Taskly-main/screen.png` (0.37 MiB)
- `Taskly-main/screen_new.png` (0.38 MiB)
- `Taskly-main/screen_now.png` (0.44 MiB)
- `Taskly-main/screen_scroll.png` (0.27 MiB)

## Log locations

| Directory | Files | MiB |
|---|---:|---:|
| `.` | 219 | 4.02 |
| `Taskly-main` | 93 | 0.70 |
| `Taskly-main/docs` | 5 | 0.16 |
| `backend` | 89 | 13.12 |
| `docs` | 1 | 0.18 |
| `frondend` | 10 | 0.39 |
