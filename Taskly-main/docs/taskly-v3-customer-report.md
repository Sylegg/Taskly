# TaskLy Customer V3 — báo cáo triển khai

Đã đọc hai file tham chiếu và triển khai trên Flutter/Spring Boot hiện có. Login/Register được giữ nguyên. Phạm vi đã hoàn thành là danh mục dịch vụ, bản nháp Customer và báo giá theo cấu hình Admin; chưa hoàn tất toàn bộ Customer V3.

## IMPLEMENTED

- Home dùng danh mục thật; không chèn Partner hoặc giá demo vào tài khoản đã đăng nhập.
- Danh mục, tìm theo tên và chi tiết dịch vụ dùng dữ liệu API có sẵn.
- Booking 5 bước: dịch vụ → yêu cầu riêng → lịch → địa chỉ → kiểm tra.
- 8 biểu mẫu riêng: dọn nhà, tổng vệ sinh, sửa chữa, chuyển nhà, máy lạnh, đi chợ, thú cưng, IT.
- Báo giá server: Admin sửa giá/phí, chọn giá cố định/theo giờ/theo số lượng, thời hạn và version.
- API lưu/khôi phục/xóa bản nháp trên server; kiểm tra role Customer và quyền sở hữu.
- Tái sử dụng quản lý địa chỉ, tài khoản và tùy chọn thanh toán đã có.
- Sửa tràn thẻ Home; hiển thị lỗi lưu rõ ràng; chặn thao tác giả thành công.
- Bảng mapping 94 route và hồ sơ audit/API gap/kiểm thử/readiness.

## PARTIAL / BLOCKED

Chưa có tạo công việc, thanh toán sandbox, matching, vòng đời task, chat/thông báo công việc và support/dispute API. Các chức năng này được ghi rõ chưa khả dụng; lưu bản nháp hoặc lấy báo giá không đồng nghĩa đặt thành công. Các route còn thiếu được liệt kê trong bảng mapping. Partner chưa được mở rộng trong thay đổi này.

Admin cấu hình giá/phí theo yêu cầu “admin tự sửa”; chưa có màn Admin Web chỉnh giá trong thay đổi Customer này. NEEDS_APPROVAL: ưu đãi, thời điểm giữ/thu tiền, phí hủy/hoàn tiền và hợp đồng sandbox. Không lấy số tiền/chính sách từ HTML demo làm quy tắc thật. Cần đặc tả hoặc đường dẫn backend bổ sung để nối checkout.

## Kiểm tra

Analyzer: không có lỗi. Flutter: 62/62 test đạt. Backend: 37/37 test đạt. APK Customer debug build thành công. Chưa kiểm thử trên thiết bị thật hoặc chạy E2E thanh toán. Chưa đạt Closed Beta Ready.

APK: `build/app/outputs/flutter-apk/app-customer-debug.apk`.

## File chính

Flutter: `lib/features/customer_booking.dart`, `lib/domain/booking_draft.dart`, `lib/data/api_customer_repository.dart`; cập nhật controller, màn Customer, Home, service tiles và model giá tham khảo. Backend: `booking/BookingSchemas.java`, `booking/BookingDraftController.java`, migration `V8__customer_booking_drafts.sql`, `CustomerPricingController.java` v? `V9__admin_pricing_quotes.sql`. Kiểm thử: `customer_v3_booking_test.dart`, `BookingDraftControllerTest.java`, cập nhật account API/Home tests.

Không thay thế dự án, không sửa Login/Register, không triển khai lên môi trường bên ngoài và không chuyển tiền. Danh mục trống cần được cấu hình/kích hoạt qua Admin API có sẵn; không tự seed giá demo.
