# Các sửa đổi admin theo xác nhận ngày 20/10/2026

1. **Rút tiền Customer:** tạo lệnh trên cùng sổ `customer_refund_withdrawals` mà app Customer sử dụng; tính số dư Customer, khóa tài khoản khi tạo lệnh, kiểm tra hạn mức số dư và chống gửi lại trùng. Lệnh Customer không ghi/trừ ví Partner. Lệnh Customer cũ lưu nhầm bảng Partner được chặn duyệt chi để tránh trừ sai ví; cần đối soát riêng nếu có dữ liệu cũ, không tự di chuyển giao dịch tài chính. Mã giao dịch không được tái dùng giữa các sổ nạp/rút. Phép tính số dư Partner chỉ tính các lệnh có role PARTNER.
2. **CSKH:** chọn hộp thư mặc định theo portal Customer/Partner, áp dụng cho trang riêng và hộp chat nổi; khi đổi portal thì chọn lại đúng vai trò. Người quản trị vẫn chuyển được giữa hai hộp thư.
3. **Cấu hình Partner:** thêm menu Cấu hình tuyển dụng, nối tới màn hình có cam kết/chính sách, lịch văn phòng, checklist, phúc lợi và SLA; chỉ thuộc portal Partner. Không thêm lại Academy.
4. **Dashboard:** xóa hai nút Duyệt KYC và Matching khỏi Hàng đợi ưu tiên. Giữ các phần còn lại.
5. **Demo:** giữ Dashboard, Operations, báo cáo, tranh chấp, đánh giá, Voucher và Rewards theo yêu cầu; ghi rõ nguồn dữ liệu mô phỏng tại các trang này.
6. **Refunds:** đổi thành Rút số dư Customer, dùng dữ liệu và thao tác API thật. Chỉ hiển thị yêu cầu rút, không đi qua bộ xử lý hoàn tiền demo; tiền hoàn đơn vẫn do backend xử lý khi hủy đơn đủ điều kiện. Nếu không tải được yêu cầu rút thì hiển thị lỗi thay vì im lặng bỏ qua.
7. **Nhãn:** thay Customers API/Tải lại Customers theo portal; bỏ thông báo demo sai trên các trang API thật; cài đặt toàn hệ thống và hạn mức dùng chung được ghi rõ. Bỏ KPI escrow không đại diện dữ liệu ví, thay bằng tổng yêu cầu rút.
8. **Màu:** Customer xanh lá, Partner xanh dương. Áp dụng vào tab, nhận diện portal, menu đang chọn, nút chính, focus, finance và tag/avatar CSKH. Giữ màu trạng thái thành công/cảnh báo theo ý nghĩa nghiệp vụ.

## Kiểm chứng

- TypeScript: `npm run lint` thành công.
- Web: `npm test` — 23/23 test thành công.
- Backend: 21/21 test của CustomerWithdrawalIntegrationTest, CustomerWalletTest, BookingCancellationTest, PartnerWalletControllerTest và WalletNotificationsTest thành công.
- Bộ kiểm thử H2 dùng cơ sở dữ liệu tách biệt: Customer và Partner cùng một tài khoản; tạo lệnh rút, gửi lại, đổi số tiền, tái dùng mã nạp/rút, vượt số dư, chi tiền, từ chối, rút từ app và bảo vệ lệnh cũ.
- Đã kiểm tra giao diện: cấu hình tuyển dụng tải SLA/cam kết, CSKH đúng role ở cả hai portal, rút Customer đọc dữ liệu thật, dashboard không còn hai nút đã yêu cầu xóa, hai màu portal khác nhau.
- Không tạo hoặc duyệt giao dịch thật để kiểm thử.

Ảnh kiểm chứng: `admin-customer-fixed.png`, `admin-partner-fixed.png`.
