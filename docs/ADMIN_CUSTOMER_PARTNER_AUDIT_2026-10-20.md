# Kiểm tra phân bố chức năng admin Customer / Partner

Ngày kiểm tra: 20/10/2026. Kiểm tra trực tiếp phiên admin đang đăng nhập tại localhost:3000 và đối chiếu mã frontend/backend. Không chỉnh sửa ứng dụng, không gửi tin nhắn, không tạo hoặc duyệt giao dịch tài chính.

## Kết luận

Menu chính đã chia đúng nhóm Customer/Partner, nhưng chức năng bên trong chưa tách và hoàn thiện đồng đều. Customer có 17 mục, Partner có 15 mục. Có lỗi chọn nhầm hộp thư, liên kết dashboard không hoạt động, cấu hình Partner không truy cập được và nhiều trang vẫn dùng dữ liệu demo. Không nên kết luận tất cả các trang admin hiện đã phục vụ dữ liệu thật.

## Nhóm đã đặt đúng

| Vị trí | Chức năng | Đánh giá |
|---|---|---|
| Customer | Customers; Dịch vụ; Danh mục dịch vụ; Cộng đồng; Banner/CMS | Đúng nhóm; có component chuyên biệt và API. |
| Customer | Nạp & Rút tiền | Component nhận role CUSTOMER, API danh sách lọc theo role; nhập cả yêu cầu rút từ customer_refund_withdrawals. Có lỗi riêng ở thao tác tạo lệnh rút thủ công, xem F1. |
| Partner | Partners; Thưởng mốc đơn; Hồ sơ ứng tuyển; Khu vực; Bài thi; Đồng phục | Đúng nhóm; có component chuyên biệt và API. |
| Partner | Nạp & Rút tiền | Component nhận role PARTNER và API danh sách lọc role. |
| Dùng chung | Toàn bộ công việc | Một đơn có cả customer và partner, dùng một màn hình điều phối chung là hợp lý. |
| Dùng chung | CSKH; cài đặt hệ thống | Có thể dùng chung nếu ghi rõ phạm vi. CSKH đã có hai hộp thư nhưng chọn mặc định chưa theo portal. Cài đặt hiện là cấu hình toàn hệ thống. |

Mã phân nhóm: `frondend/src/lib/admin-navigation.ts:3-4`. Render module và truyền role tài chính: `frondend/src/components/AdminApp.tsx:243-295`.

## Các điểm cần sửa, theo mức ưu tiên

### F1 — Cao: lệnh rút thủ công Customer đi vào ví Partner

- Frontend cho phép chọn WITHDRAWAL trong modal tạo giao dịch của Customer và gửi `/api/admin/partner-wallet-transactions`.
- Backend `manual()` chỉ tách riêng nhánh CUSTOMER + DEPOSIT. CUSTOMER + WITHDRAWAL tiếp tục gọi `request(...,"withdraw",...)` của Partner.
- Nhánh đó kiểm tra số dư `partner_wallets` và khi chi tiền sẽ trừ `partner_wallets`. Số dư Customer lại tính từ refund credits, deposits Customer, booking debits và `customer_refund_withdrawals`.
- Hệ quả: Customer chỉ có số dư Customer có thể bị báo thiếu tiền; tài khoản dùng cả hai app có thể bị xử lý nhầm ví. Đây là kết luận theo luồng mã, chưa thực hiện giao dịch thử.
- Cần chuyển thao tác này sang luồng rút Customer hoặc tạm bỏ lựa chọn rút thủ công cho Customer cho đến khi nối đúng backend.
- Bằng chứng: `frondend/src/components/DepositWithdrawAdmin.tsx:342-360`; `backend/src/main/java/com/taskly/booking/PartnerWalletController.java:95-115,142`; `backend/src/main/java/com/taskly/booking/BookingCheckout.java:20-25`.

### F2 — Cao: nhiều trang trên menu vẫn chỉ là demo

- Dashboard, Live Operations và Phân tích & báo cáo đọc `db.tasks`, `db.payments`, dữ liệu seed/localStorage. Trang Toàn bộ công việc lại dùng API riêng trong TaskAdmin. Vì vậy hai màn hình có thể cho số liệu khác nhau.
- Refunds, Khiếu nại & tranh chấp, Đánh giá & kiểm duyệt, Voucher, Rewards & điểm chưa được nối như các module API chuyên biệt; nhiều thao tác cập nhật store của trình duyệt.
- Đã nhìn thấy trực tiếp Refunds hiển thị hai bản ghi RF901/RF902 và nhãn “dữ liệu mô phỏng trong trình duyệt”.
- “Refunds” demo không phải nơi xử lý thực tế các yêu cầu rút tiền hoàn của Customer; các yêu cầu đó đang nằm trong Nạp & Rút tiền.
- Nếu dùng admin để vận hành thật: cần nối API hoặc ẩn/đánh dấu rõ các module này. Không cần xóa source.
- Bằng chứng: `AdminApp.tsx:31,62,88-100,151,295-315`; `DepositWithdrawAdmin.tsx:204-231`.

### F3 — Trung bình: thiếu đường mở cấu hình Partner

- `RecruitmentConfigAdmin` có Cam kết & chính sách, Lịch văn phòng, Checklist hồ sơ, Phúc lợi Partner và SLA.
- `RecruitmentAdmin` có nhánh `tab === 'config'`, nhưng initialTab chỉ nhận applications/areas/exam/uniforms; không có lệnh setTab để chọn config.
- Menu Đồng phục chỉ mở `uniformOnly`, nên không mở được các nhóm cấu hình còn lại; SLA cũng chỉ render khi không phải uniformOnly.
- Cần thêm một lối vào “Cấu hình tuyển dụng/Partner” thay vì tạo nhiều bản cấu hình giống nhau ở cả hai portal.
- Bằng chứng: `RecruitmentAdmin.tsx:70-74,101,390-403`; `RecruitmentConfigAdmin.tsx:16-22,404-407`; `AdminApp.tsx:248`.

### F4 — Trung bình: CSKH Customer mở hộp thư Partner

- Đã bấm Customer → Chăm sóc khách hàng: tab Partner • Đối tác vẫn được chọn.
- `SupportAdmin` khởi tạo role='partner'; `AdminApp` không truyền portal vào component, cả ở trang riêng lẫn hộp chat nổi.
- Cần chọn mặc định theo portal hoặc tự chuyển khi đổi portal. Hai hộp thư Customer/Partner có thể vẫn nằm chung trang để nhân viên hỗ trợ cả hai.
- Bằng chứng: `SupportAdmin.tsx:15`; `AdminApp.tsx:229-231,245`.

### F5 — Trung bình: nút Duyệt KYC / Matching trên dashboard không chuyển trang

- Dashboard tạo nút điều hướng tới `kyc` và `matching`.
- Hai key không có trong headings và không được normalize trong navigate(), nên bị return ngay.
- Đã thử Duyệt KYC trên giao diện: không thay đổi trang.
- Cần trỏ Duyệt KYC sang Hồ sơ ứng tuyển của Partner (hoặc một trang KYC thật), Matching sang Toàn bộ công việc với bộ lọc thích hợp.
- Bằng chứng: `AdminApp.tsx:99,303`; `frondend/src/data/headings.json`.

### F6 — Trung bình: nội dung tổng quan chưa theo phạm vi portal

- Customer dashboard vẫn hiện ưu tiên Duyệt KYC, số Partner và số tiền mô phỏng; hai portal dùng cùng hàm dashboard/operations/analytics.
- Việc điều phối chung là hợp lý, nhưng trang tổng quan dưới nhãn Customer/Partner cần ghi rõ “toàn hệ thống” hoặc có nội dung theo portal.
- Không phải đang có hai backend hay hai bộ đơn riêng: phần lớn là một màn hình dùng chung xuất hiện hai nơi.
- Bằng chứng: `AdminApp.tsx:295-313` và quan sát Customer dashboard.

### F7 — Thấp: nhãn giao diện không theo ngữ cảnh

- Portal Partner còn hiển thị “Customers API”, “Tải lại Customers”.
- Banner “Các module khác đang sử dụng dữ liệu mô phỏng” hiện cả trên Nạp & Rút tiền, Thưởng mốc đơn và Cài đặt hệ thống dù các module này có API thật.
- Finance của Customer vẫn có mô tả giải ngân “Đối tác & Khách hàng”, ký quỹ/escrow, dễ khiến người vận hành hiểu nhầm phạm vi.
- Cần đổi nhãn theo module và xác định nguồn dữ liệu đúng cho từng trang.
- Bằng chứng: `AdminApp.tsx:174,187-192`; `DepositWithdrawAdmin.tsx` phần KPI; `headings.json` phần payments.

## Chức năng có code nhưng cần xác nhận còn thuộc phạm vi sản phẩm

- Academy: `RecruitmentAcademyAdmin.tsx` và API lessons/training-videos vẫn tồn tại nhưng component không được import vào admin. Nếu đào tạo còn là nghiệp vụ đang dùng thì thiếu lối vào; nếu đã chủ động bỏ Academy thì nên xem là mã cũ, không tự động đưa lại vào menu.
- Audit, Staff, Permissions, Integrations, Data Lab và Campaigns có headings/một phần code nhưng không có menu. Không coi đây là trang bắt buộc phải thêm chỉ vì code tồn tại. Phần lớn đang là prototype; campaign còn bị navigate() chặn.
- `payouts` còn nhánh render và phân loại Partner nhưng không có heading/menu; phần rút tiền hiện đã có trong Nạp & Rút tiền nên không cần thêm trang thứ hai làm cùng việc.
- Chưa có màn hình đối soát số dư Customer thống nhất để xem đủ nạp, trừ khi đặt đơn, hoàn đơn và rút trên một lịch sử. Đây là đề xuất để vận hành, không khẳng định là yêu cầu đã thống nhất.

## Bố cục đề xuất

| Nhóm | Customer | Partner | Dùng chung |
|---|---|---|---|
| Người dùng | Customers | Partners | Chi tiết tài khoản chung khi một người dùng cả hai app |
| Nội dung | Dịch vụ, danh mục, banner, cộng đồng | — | — |
| Tuyển dụng | — | Hồ sơ, khu vực, bài thi, đồng phục, cấu hình tuyển dụng | — |
| Tài chính | Nạp/rút và lịch sử số dư Customer | Ví, nạp/rút, thưởng/thu nhập Partner | Cấu hình ngân hàng/hạn mức toàn hệ thống cần ghi rõ dùng chung |
| Vận hành | Tổng quan theo Customer | Tổng quan theo Partner | Công việc và điều phối, cùng một nguồn dữ liệu |
| CSKH | Mặc định hộp thư Customer | Mặc định hộp thư Partner | Một công cụ CSKH có thể chuyển role |
| Chất lượng/marketing | Chỉ công bố module đã nối API | Chỉ công bố module đã nối API | Tranh chấp/đánh giá cần nguồn thật trước khi dùng vận hành |

## Phạm vi kiểm chứng

Đã xem trực tiếp sidebar hai portal, Customer dashboard, nút KYC, CSKH Customer, Refunds Customer và Nạp & Rút tiền của cả hai portal. Những mục còn lại được đối chiếu mã điều hướng, render component và API. Không thử tất cả thao tác ghi dữ liệu, không xác nhận tính đầy đủ của nghiệp vụ chỉ từ việc có một menu. Chưa sửa code trong lần kiểm tra này.
