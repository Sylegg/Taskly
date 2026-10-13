# Lưu dữ liệu tài khoản

App đăng nhập thật dùng `ApiCustomerRepository` và token của `Session`. Hồ sơ, địa chỉ, phương thức, cài đặt, danh sách đánh giá và số công việc đọc từ backend theo tài khoản. Không dùng địa chỉ, giao dịch hoặc đánh giá mẫu cho tài khoản thật.

Backend mới nằm trong `backend/`, được lấy từ backend hiện có tại `C:/Users/Lenovo/OneDrive/Desktop/taskly-split/backend`. Hai tệp bổ sung là `AccountController.java` và migration `V7__account_preferences.sql`; đã được chép sang backend hiện có. Khởi động lại backend để Flyway tạo các bảng mới. Không thay đổi `.env`.

Chạy backend theo cấu hình database hiện có, sau đó chạy app:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Android emulator dùng `10.0.2.2`; điện thoại thật dùng IP LAN của máy chạy backend. Bản release cần API HTTPS.

## Các thao tác

- Hồ sơ: lưu họ tên. Email và số điện thoại hiển thị để xem; thay đổi cần luồng xác minh riêng.
- Địa chỉ: thêm, sửa, xóa, chọn mặc định; nhập tỉnh/thành phố.
- Thanh toán: người dùng thêm tiền mặt hoặc tên ngân hàng, chủ tài khoản và 4 số cuối; xóa và chọn mặc định. Lựa chọn được lưu trên máy chủ. Không lưu số thẻ đầy đủ, CVV, PIN hay OTP.
- Cài đặt: lưu lựa chọn thông báo. Chưa đăng ký push notification.
- Đánh giá: đọc đánh giá đã lưu. API POST `/users/me/reviews/{taskId}` chỉ nhận công việc của người dùng đã PAID, sao 1–5, mỗi công việc một đánh giá.
- Trợ giúp: nội dung hướng dẫn trong app, không cần lưu dữ liệu người dùng.

## Giới hạn còn lại

Lưu phương thức ngân hàng chưa phải liên kết tài khoản hoặc thu tiền. Cần lựa chọn cổng thanh toán, tài khoản merchant và luồng xác nhận từ nhà cung cấp để thực hiện giao dịch thật. API repository hiện chặn thao tác thu tiền và đăng công việc chưa được tích hợp; danh sách công việc/chat chưa nối backend nên luồng gửi đánh giá từ chi tiết công việc chưa sử dụng được với tài khoản thật. Số công việc trên hồ sơ đọc trực tiếp database.

## Kiểm tra

`flutter analyze` sạch. 20 kiểm thử Flutter liên quan tài khoản, phiên đăng nhập, repository và luồng mô phỏng đã qua. Backend `AccountControllerTest` dùng database H2 để xác nhận lưu phương thức, lưu cài đặt và cách ly người dùng. Bộ kiểm thử Flutter toàn bộ còn lỗi trong `home_design_test.dart` về layout và kỳ vọng trang chủ; không xác nhận toàn bộ suite đã qua. Chưa kiểm thử trực tiếp với database PostgreSQL đang chạy của bạn.
