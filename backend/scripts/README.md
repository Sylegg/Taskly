# Danh mục dịch vụ TaskLy

`seed-service-catalogue.sql` nhập 10 danh mục và 20 dịch vụ tiếng Việt vào PostgreSQL đang được backend sử dụng. Mỗi danh mục có 2 dịch vụ; tất cả được kích hoạt, dùng VND, có mô tả phạm vi công việc, giá gợi ý và thời lượng. Không có dữ liệu giả về khách hàng, người làm hoặc đơn đặt dịch vụ.

Chạy từ thư mục workspace sau khi backend đã áp dụng các migration và có tài khoản quản trị đang hoạt động với quyền `SERVICE_MANAGE`:

```powershell
powershell -ExecutionPolicy Bypass -File .\backend\scripts\seed-service-catalogue.ps1
```

Script đọc tên database và người dùng từ `.env`, nhập dữ liệu qua container `taskly-postgres-1`, rồi làm mới hai cache danh mục trên `taskly-redis-1`. Có thể chỉ định container khác bằng `-PostgresContainer` và `-RedisContainer`. SQL chạy trong một transaction: lỗi sẽ hủy toàn bộ lần nhập. Slug đã tồn tại được bỏ qua, kể cả bản ghi đã xóa mềm; dữ liệu hoặc giá mà quản trị viên đã chỉnh sẽ không bị ghi đè. Bảng giá chỉ được thêm cho dịch vụ vừa tạo. Chạy lại khi đã nhập đầy đủ sẽ tạo 0 bản ghi.

| Danh mục | Dịch vụ |
| --- | --- |
| Dọn dẹp nhà cửa | Dọn nhà theo giờ; Tổng vệ sinh nhà ở |
| Vệ sinh sofa và nệm | Vệ sinh sofa tại nhà; Vệ sinh nệm tại nhà |
| Dịch vụ máy lạnh | Vệ sinh máy lạnh; Kiểm tra sự cố máy lạnh |
| Sửa chữa điện gia dụng | Kiểm tra sự cố máy giặt; Kiểm tra sự cố tủ lạnh |
| Lắp ráp và tháo dỡ nội thất | Lắp ráp nội thất; Tháo dỡ nội thất |
| Chuyển nhà và đóng gói | Hỗ trợ chuyển nhà; Đóng gói đồ đạc |
| Đi chợ và mua sắm hộ | Đi chợ hộ; Mua nhu yếu phẩm hộ |
| Chăm sóc thú cưng | Chăm sóc thú cưng tại nhà; Dắt chó đi dạo |
| Hỗ trợ công nghệ | Hỗ trợ máy tính; Cài đặt Wi-Fi gia đình |
| Giặt sấy và ủi quần áo | Giặt sấy quần áo; Ủi quần áo |

Các mức giá là cấu hình khởi tạo để test và tiếp tục chỉnh cho vận hành, không phải giá thị trường đã khảo sát. Phí nền tảng khởi tạo bằng 0; báo giá có hiệu lực 15 phút. Giá được tính theo giờ (`duration` của biểu mẫu là số giờ), theo số lượng (`area`, `items`, `units`, `count`, `weightKg`) hoặc phí cố định. Với dịch vụ kiểm tra thiết bị, giá cố định chỉ là phí kiểm tra; tiền linh kiện và sửa chữa được thống nhất riêng. Tiền mua hàng nằm ngoài phí đi chợ/mua sắm hộ.

Bảng giá được ghi nhận dưới tài khoản quản trị đủ quyền được tạo sớm nhất. Quản trị viên có thể sửa giá và phí trong mục dịch vụ. Khi đổi giá, cập nhật đồng thời khoảng giá gợi ý và nội dung mô tả nếu có ghi đơn giá để thông tin hiển thị nhất quán. API danh mục: `GET /api/v1/public/services`; API biểu mẫu: `GET /api/v1/public/booking-schemas`.
