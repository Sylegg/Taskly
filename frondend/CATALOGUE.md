# Danh mục và dịch vụ

Web dùng `/api/admin/catalogue/*` để gọi backend duy nhất ở cổng 8080. Các thao tác yêu cầu phiên Admin; thao tác ghi kiểm tra Origin. Backend lưu danh mục vào `service_categories`, dịch vụ vào `services`, đồng thời xóa cache danh mục công khai khi có thay đổi.

1. Mở **Danh mục dịch vụ**, tạo nhóm và bật nhóm.
2. Mở **Dịch vụ**, chọn nhóm, nhập tên, mô tả ngắn, chọn icon hoặc tải ảnh riêng và lưu.
3. Mở **Xem chi tiết → Thiết lập giá** ngay trong dịch vụ để tạo hoặc cập nhật quy tắc tính giá. Có thể chọn giá cố định (`FIXED`), theo giờ (`HOURLY`) hoặc theo trường trong biểu mẫu (`FIELD`). Các thay đổi gọi API giá của backend và được lưu vào database.
4. Bật dịch vụ để hiển thị trên Customer. Dữ liệu mới tạo mặc định đang tắt.

Customer đọc `/api/v1/public/services`. Trang chủ tự tải danh mục mỗi 20 giây khi app đang mở, khi quay lại app và khi kéo để làm mới. Tắt danh mục sẽ ẩn cả nhóm. Chỉ xóa được nhóm không còn dịch vụ; xóa dịch vụ dùng cơ chế xóa mềm của backend.

Danh mục và dịch vụ trên hai màn hình này sử dụng database, không lấy dữ liệu localStorage của bản demo cũ.

Hai bảng sử dụng bố cục có nút **Xem chi tiết →**. Bấm vào một dòng để xem thông tin, chỉnh sửa, bật/tắt hoặc xóa. Có thể tìm kiếm, lọc trạng thái và xuất các dòng đang hiển thị thành CSV.

Giá và thứ tự không xuất hiện trong bảng, biểu mẫu sửa nội dung hoặc CSV của hai trang này. Giá được quản lý riêng trong phần **Thiết lập giá** ở chi tiết dịch vụ; menu **Bảng giá & phí** đã được bỏ. Khi sửa nội dung hoặc icon, dữ liệu giá và thứ tự hiện có vẫn được giữ nguyên. Bản ghi mới tự được đặt sau các bản ghi hiện có. Cột **Form** hiển thị các trường lấy từ biểu mẫu đặt dịch vụ của backend.

Trong **Dịch vụ → Xem chi tiết**, dùng **Bật phổ biến / Tắt phổ biến** để chọn các dịch vụ cho hàng **Phổ biến** bên dưới vòng cung trang chủ Customer. Cờ popular được lưu riêng trong database qua PATCH /api/v1/admin/services/{id}/popular; sửa nội dung, icon hay giá giữ nguyên cờ này. Dịch vụ mới mặc định chưa phổ biến. Chỉ dịch vụ đang hoạt động trong danh mục đang hoạt động xuất hiện trên app. Hàng này tự ẩn khi không có dịch vụ phổ biến và cuộn ngang nếu có hơn bốn dịch vụ.
