# Rà soát workspace — 02/11/2026

Kiểm kê lại trực tiếp toàn bộ cây file, đối chiếu cấu hình build, import/export/part Dart, entrypoint Next.js, tham chiếu test/tool và tiến trình Java. Không dùng số liệu của báo cáo 13/10 thay cho kết quả hiện tại. Không xóa file, không thay đổi mã nguồn, không dừng ứng dụng.

Đã kiểm kê **26,290 file**, **13.41 GiB**, trước khi ghi báo cáo mới. Dung lượng là tổng kích thước file, không phải allocated size.

## 1. File sinh tự động / có thể tạo lại

| Thư mục | Số file | MiB |
|---|---:|---:|
| `Taskly-main/build/` | 9271 | 6,050.08 |
| `Taskly-main/.dart_tool/` | 710 | 2,294.84 |
| `backend/.runtime/` | 46 | 4,383.93 |
| `frondend/.next/` | 305 | 293.72 |
| `frondend/.next-dev/` | 227 | 103.66 |
| `frondend/node_modules/` | 13188 | 377.75 |
| `backend/build/` | 507 | 98.41 |
| `backend/.gradle/` | 14 | 13.82 |
| `Taskly-main/android/.gradle/` | 16 | 56.59 |

Bốn thư mục `backend/build-arrival-check`, `build-support-filter-check`, `build-support-task-check`, `build-travel-check`: 998 file, 7.71 MiB. Đây là đầu ra kiểm tra build, không phải source.

- `backend/.runtime`: 46 JAR cũ, 4,28 GiB. Script `scripts/restart-current-backend.ps1` tạo bản UUID mới mỗi lần restart, không tự dọn bản cũ. Tiến trình backend hiện tại PID 38900 chạy từ `build/classes`, không dùng `.runtime`. Các JAR này là ứng viên dọn lớn nhất; có thể giữ 1–2 bản để rollback. Kiểm tra lại tiến trình ngay trước khi dọn.
- Build/cache có thể tạo lại nhưng đang có backend/frontend/Flutter chạy. Chỉ dọn sau khi dừng tiến trình tương ứng. `.next-dev` là thư mục dev được khai báo thật trong `next.config.ts`, không phải bản sao vô dụng.
- `node_modules` là dependency đã cài, không phải mã rác. Xóa sẽ cần cài lại.
- APK trong build có thể là bản cần lưu để cài đặt/phát hành; giữ bản cần thiết trước khi dọn.
- Có 45 file log ngoài các nhóm build/cache/dependency chính, tổng 2.72 MiB. Log lịch sử có thể dọn; giữ log đang được ghi (`dev-backend`, `dev-frontend`, `run-customer`, `run-partner`) trong lúc chạy.

## 2. Source chưa được nối vào luồng chạy — cần xem xét, chưa kết luận xóa được

Không tìm thấy import/tham chiếu ngoài chính file trong app/test/tool đã rà soát:

- `Taskly-main/lib/data/recruitment/secure_recruitment_persistence.dart`.
- `frondend/src/components/CategoryQuantityEditor.tsx`.
- `frondend/src/components/ServiceBookingFieldsEditor.tsx`.
- `frondend/src/components/ServicePricingEditor.tsx` và CSS chỉ được nó import: `service-pricing-editor.css`.
- `frondend/src/components/RecruitmentAcademyAdmin.tsx`.
- `frondend/src/components/TasklyBookingSuccess.tsx`.
- `frondend/src/data/daily_milestones.json`.

Đây có thể là tính năng chưa tích hợp hoặc mã cũ đã thay thế. Cần xác nhận mục đích trước khi bỏ, đặc biệt các editor nghiệp vụ.

## 3. Không nằm trong app graph nhưng test/tool vẫn dùng — giữ

- Mobile: `lib/features/partner/recruitment_academy.dart` được `test/recruitment_academy_admin_content_test.dart` dùng; `recruitment_identity.dart` được `test/recruitment_edit_window_test.dart` dùng.
- `lib/data/recruitment/mock_recruitment_repository.dart`, `recruitment_seed.dart` và ba file trong `lib/domain/recruitment/` còn phục vụ `test/recruitment_foundation_test.dart` và tool export fixture.
- Frontend: `src/lib/recruitment-snapshot.mjs` được test snapshot dùng.
- Các mock trong `lib/data/mock/` được `main.dart` và `app/dependencies.dart` nối vào app: không phải file bỏ quên chỉ vì tên có chữ mock.

## 4. Asset / bản tham khảo

- Hai ảnh `Taskly-main/assets/images/login_bg.jpg`, `register_bg.jpg` không tìm thấy tham chiếu tên/đường dẫn trong source/test/tool. Tổng khoảng 1,19 MiB. Là ứng viên asset cũ; chưa tự xóa vì thư mục ảnh vẫn được pubspec bundle và có thể còn được dùng ngoài code đã kiểm tra.
- Icon trong `assets/category-icons`, `assets/service-icons` và `frondend/public/*-icons` được dựng đường dẫn động. Đã xác nhận ở `category_symbol.dart`, `service_symbol.dart`, `CategoryIcon.tsx`, `ServiceIcon.tsx`. Giữ toàn bộ icon và license.
- `frondend/public/reference/admin-original.html` là bản HTML tham chiếu; `/reference/:path*` bị redirect về `/` trong Next config. Có thể chuyển sang kho tài liệu nếu muốn bỏ khỏi public, không cần để app hiện tại chạy.
- `Taskly-main/design-reference/` và `docs/home-design/` là tài liệu/mẫu/ảnh kiểm chứng; không chạy trong app nhưng chưa đủ cơ sở gọi là rác.
- File trùng byte phát hiện chủ yếu là manifest debug/profile, license, icon iOS nhiều kích thước và cấu hình workspace. Những file này có vai trò theo đường dẫn nên không xóa chỉ vì nội dung trùng.

## 5. Cần giữ

`.env` (không đọc/in bí mật), lockfile dependency, Gradle wrapper, script chạy/seed, toàn bộ migration SQL/Java, dữ liệu `backend/data/private-images/` và `backend/data/city-area-backup.json`. Không chứng minh file backup không còn cần nên giữ. Spring controller/service/entity/repository và Flyway migration được framework phát hiện tự động, không dùng tiêu chí thiếu import để kết luận file rác. Các thư mục nền tảng Flutter và cấu hình IDE không phải rác chỉ vì hiện chạy Android.

## Phạm vi và giới hạn

Đây là kiểm tra tĩnh, không phải chứng minh mọi nhánh chức năng không dùng một file. Không chạy toàn bộ test, không sửa dependency hoặc xóa dữ liệu. Không có Git repository tại gốc workspace để đối chiếu lịch sử. Danh sách toàn bộ file và phân nhóm nằm trong `WORKSPACE_FILE_AUDIT_2026-11-02.csv`. Nhãn CSV là phân nhóm theo đường dẫn, không phải lệnh xóa.
