# TaskLy Admin Dashboard

Dashboard chỉ có một vai trò hiển thị: **ADMIN**. Tài khoản phải đăng nhập qua backend thật trước khi vào dashboard. Backend đang dùng role ADMIN hoặc SUPER_ADMIN cho quyền quản trị; cả hai hiển thị là ADMIN. Customer, Tasker và các role quản trị chuyên biệt không được vào dashboard này.

## Chạy

Khởi động backend bằng ../backend/run-backend.ps1, rồi chạy:

~~~powershell
npm install
npm run dev
~~~

Mở http://localhost:3000 và đăng nhập tài khoản quản trị đã có quyền trên backend. Không tự tạo hoặc cấp quyền Admin trong giao diện. API mặc định: http://localhost:8080/api/v1; đặt TASKLY_API_URL trong môi trường chạy Next.js nếu cần thay đổi. Biến này chỉ dùng tại server.

## Customers dùng dữ liệu thật

- Danh sách, trạng thái, họ tên, email, số điện thoại và số công việc tải từ database qua GET /api/v1/admin/customers.
- Chỉnh sửa họ tên và số điện thoại qua PATCH /api/v1/admin/customers/{id}.
- Khóa/mở khóa tài khoản đã xác minh qua PATCH /api/v1/admin/customers/{id}/status. Khóa tài khoản thu hồi refresh token.
- Không tạo customer giả từ dashboard. Customer đăng ký trong app TaskLy Customer.
- Không lưu danh sách customer thật hoặc token trong localStorage. Phiên Admin dùng cookie HttpOnly; thao tác ghi kiểm tra Origin. Next.js kiểm tra role từ /users/me và backend kiểm tra quyền cho API Customers.
- Khi API lỗi, hiển thị lỗi và cho tải lại; không thay dữ liệu thật bằng seed.
- Backend không trả Admin trong danh sách Customers.

Các module còn lại vẫn là mô phỏng và được ghi rõ trên giao diện. Thay đổi trong các module mô phỏng không cập nhật dữ liệu tài chính hoặc công việc thật. Trang HTML tham chiếu cũ chuyển về dashboard chính, không dùng làm cổng quản trị riêng.

## Kiểm tra

~~~powershell
npm run lint
npm test
npm run build
~~~

Backend: gradlew.bat test --tests com.taskly.user.AdminCustomerControllerTest. Kiểm thử này chạy bằng profile test, không thay đổi tài khoản thực.
