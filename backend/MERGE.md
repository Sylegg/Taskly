# Backend duy nhất

Customer, Partner và dashboard Admin sử dụng backend trong thư mục này, cổng 8080.

Chạy từ thư mục workspace:

```powershell
powershell -ExecutionPolicy Bypass -File .\backend\run-backend.ps1
```

Docker Desktop cần chạy các container PostgreSQL và Redis hiện có. Cấu hình được đọc từ `.env` ở workspace.

Đã giữ toàn bộ API của backend phụ: tài khoản, thanh toán, cài đặt, đánh giá, bản nháp đặt việc, báo giá và người giúp yêu thích. V7 người giúp yêu thích đã được áp dụng nên giữ nguyên; phần cài đặt tài khoản chuyển sang V10 để tránh trùng phiên bản. V8 và V9 giữ nguyên.

Mã nguồn backend phụ trước khi xóa nằm trong `../backend-phu-before-merge.zip`. Các ZIP dự phòng cũ vẫn được giữ.
