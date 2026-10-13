# Chuyển giới thiệu và xác thực từ taskly-split

Ứng dụng khởi động tại `lib/auth/entry.dart`: khôi phục phiên → giới thiệu → đăng nhập/đăng ký → giao diện Customer của Taskly-main.

Các màn hình giới thiệu, đăng nhập email, đăng ký, OTP email và quên/đặt lại mật khẩu cùng API client và secure storage được chuyển từ `taskly-split/mobile`. Ảnh nền nằm trong `assets/images`. Đăng xuất xóa phiên và trở về màn hình giới thiệu.

Backend vẫn nằm trong `taskly-split/backend`; cần chạy backend với cơ sở dữ liệu, Redis và cấu hình gửi OTP tương ứng. File `.env` của backend không được đóng gói vào ứng dụng Flutter.

Customer đăng nhập bằng số điện thoại và mật khẩu qua `POST /api/v1/auth/mobile/login-phone` (JSON: `phone`, `password`, `deviceName`). Ứng dụng chuẩn hóa `+84` thành `0` trước khi gửi. Partner tiếp tục đăng nhập email qua `/auth/mobile/login`. Đăng ký, xác minh tài khoản và khôi phục mật khẩu vẫn dùng OTP email. Cần khởi động lại backend sau khi cập nhật để có endpoint đăng nhập SĐT.

Chạy từ thư mục `Taskly-main`:

```powershell
flutter pub get
flutter run --flavor customer --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
flutter run --flavor partner --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Android emulator mặc định dùng `10.0.2.2`; Windows/web mặc định dùng `localhost`. Với điện thoại thật, truyền địa chỉ IP LAN của máy chạy backend. Bản release yêu cầu URL HTTPS. Backend cần cho phép origin tương ứng nếu chạy trên web.

Customer và Partner là hai ứng dụng Android riêng, dùng chung mã nguồn:

| Flavor | Tên ứng dụng | Application ID | Sau đăng nhập |
| --- | --- | --- | --- |
| customer | TaskLy Customer | com.taskly.customer | Trang chủ Customer |
| partner | TaskLy Partner | com.taskly.partner | Trang chủ Tasker |

Flavor tự chọn giao diện; không cần truyền thêm `PARTNER_APP`. Hai app có bộ nhớ và phiên đăng nhập riêng; không có nút chuyển Customer/Tasker trong app. Application ID trùng các bản customer/partner cũ của taskly-split, nên cài APK mới sẽ cập nhật các app đó và giữ dữ liệu. Bản thử nghiệm gộp cũ có ID `com.taskly.taskly_mobile` là một ứng dụng khác.

Build APK:

```powershell
flutter build apk --debug --flavor customer
flutter build apk --debug --flavor partner
```

APK nằm tại `build/app/outputs/flutter-apk/app-customer-debug.apk` và `app-partner-debug.apk`.

Xác thực dùng backend thật. Dữ liệu công việc, thanh toán, hồ sơ chỉnh sửa và luồng Tasker của Taskly-main vẫn dùng mock repositories; chưa được chuyển sang API nghiệp vụ. Mỗi lần đăng nhập tạo một kho dữ liệu mô phỏng mới và điền tên, email, số điện thoại của tài khoản backend vào hồ sơ của app tương ứng. Các job mô phỏng không đồng bộ giữa hai app. Việc tách app không thay thế kiểm tra quyền TASKER ở backend khi tích hợp API nghiệp vụ.

Kiểm tra:

```powershell
flutter analyze
flutter test
```
