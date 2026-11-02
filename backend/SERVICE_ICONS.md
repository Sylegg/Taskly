# Icon dịch vụ trên ứng dụng người dùng

Trong trang quản trị, mở **Dịch vụ**, chọn **Chỉnh sửa** hoặc **Tạo dịch vụ**.

- **Icon có sẵn:** chọn hình phù hợp trong bộ icon. Chọn **Tự động** để dùng icon mặc định theo loại dịch vụ.
- **Ảnh icon riêng:** chọn ảnh PNG hoặc JPG, tối đa 1 MB. Nên dùng ảnh vuông và PNG nền trong suốt. Xem trước ảnh rồi bấm **Lưu**.
- **Đổi hoặc bỏ ảnh:** chọn ảnh khác để thay thế; dùng nút bỏ ảnh hoặc chọn icon có sẵn để chuyển về icon tương ứng.

Ảnh riêng được ưu tiên hiển thị. Nếu tải ảnh trên app thất bại, app dùng icon có sẵn hoặc icon mặc định. Danh mục và dịch vụ cần đang bật để xuất hiện trên app. Tải lại danh sách dịch vụ trên app sau khi lưu thay đổi trong trang quản trị.

Icon được lưu bền vững trong database cùng dịch vụ. Backend xử lý ảnh PNG/JPG thành PNG có cạnh dài tối đa 256 px, giữ tỷ lệ và nền trong suốt. Ảnh đầu vào có mỗi chiều không quá 2048 px. Đổi ảnh tạo đường dẫn mới để trình duyệt và app không dùng lại ảnh cũ từ cache. Không cần MinIO để sử dụng icon dịch vụ.

App Customer cần bản build đã hỗ trợ trường icon mới. Với các bản app cũ, dịch vụ vẫn hiển thị bằng icon mặc định.

Admin và Customer dùng chung 17 ảnh icon Lucide, cùng nét vẽ và màu sắc. File PNG ở `frondend/public/service-icons` và `Taskly-main/assets/service-icons` được tạo từ cùng nguồn bằng `node tools/sync-service-icons.mjs` trong thư mục `frondend`. Script đồng bộ cả ánh xạ icon tự động theo slug cho Flutter; sau khi chạy cần build lại app. Ảnh riêng từ backend vẫn được ưu tiên so với bộ icon này.

Vòng cung dịch vụ trên trang chủ dùng cùng `ServiceSymbol` với danh sách dịch vụ: ảnh riêng từ API được ưu tiên, sau đó đến icon đã chọn trong admin, cuối cùng là icon tự động theo mã dịch vụ. Tên dịch vụ không ghi đè icon đã cấu hình. Khi API trả danh sách rỗng, vòng cung hiển thị trạng thái chưa có dịch vụ, không thay bằng dữ liệu mẫu.
