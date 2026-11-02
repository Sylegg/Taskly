# TaskLy V3 route mapping — Customer first

Source: the 94 routes in the supplied master prompt, cross-checked against SCREEN_GROUPS in the HTML. Date: 2026-10-09.

EXISTS means an existing feature/API, not full beta certification. PARTIAL and MISSING remain open. Demo-only UI tests do not establish live API support. Partner is OUT_OF_SCOPE for this Customer-first change.

| HTML route | Screen | Status | Flutter mapping | API (prefix /api/v1/) | Evidence / limitation |
|---|---|---|---|---|---|
| `splash` | Khởi động / Splash | EXISTS | TasklyEntry / Session.restore | auth/mobile/refresh; users/me | session_test.dart |
| `login` | Đăng nhập (mô phỏng) | EXISTS / PROTECTED | AuthPage | auth/mobile/login; auth/mobile/login-phone | phone_login_test.dart |
| `register` | Đăng ký (mô phỏng) | EXISTS / PROTECTED | AuthPage | auth/register | api_test.dart |
| `emailOtp` | Xác minh email OTP | EXISTS | AuthPage OTP | auth/verify-otp; auth/resend-otp | Backend AuthSecurityTest |
| `forgot` | Quên mật khẩu | EXISTS | AuthPage recovery | auth/forgot-password | Backend AuthSecurityTest |
| `resetOtp` | OTP đặt lại mật khẩu | PARTIAL | AuthPage reset flow (combined) | auth/reset-password | Backend AuthSecurityTest |
| `newPassword` | Tạo mật khẩu mới | EXISTS | AuthPage reset | auth/reset-password | Backend AuthSecurityTest |
| `success` | Thông báo thành công | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `home` | Trang chủ Customer | PARTIAL | PageId.home / TaskLyCustomerHome | public/services; users/me/* | home_design_test.dart |
| `services` | Danh mục dịch vụ | EXISTS | PageId.services / serviceList | public/services | account_api_test.dart |
| `serviceDetail` | Chi tiết dịch vụ | PARTIAL | PageId.serviceDetail / serviceDetail | public/services (loaded catalogue) | account_api_test.dart |
| `search` | Tìm kiếm & lọc | PARTIAL | PageId.services / local catalogue search | public/services | home_design_test.dart |
| `aiDraft` | TaskLy AI gợi ý | PARTIAL | PageId.ai (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `addresses` | Sổ địa chỉ | EXISTS | PageId.addresses / address list | users/me/addresses | Backend user tests |
| `addressEdit` | Thêm / sửa địa chỉ | EXISTS | Address editor bottom sheet | users/me/addresses | Backend user tests |
| `favorites` | Partner yêu thích | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `booking` | Booking Wizard | PARTIAL | PageId.create / CustomerBooking | public/booking-schemas; users/me/booking-draft | customer_v3_booking_test.dart; BookingDraftControllerTest |
| `quote` | Báo giá chi tiết | EXISTS | CustomerBooking review / server quote | POST users/me/booking-quotes | BookingDraftControllerTest; customer_v3_booking_test.dart |
| `payment` | Thanh toán sandbox | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `paymentResult` | Kết quả thanh toán | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `matching` | Matching Partner | PARTIAL | PageId.recommendations (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `activities` | Hoạt động / Danh sách việc | PARTIAL | PageId.tasks (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `taskDetail` | Chi tiết & Timeline việc | PARTIAL | PageId.task (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `taskEdit` | Thay đổi thông tin việc | PARTIAL | PageId.task (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `taskChange` | Yêu cầu thay đổi | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `cancelTask` | Hủy công việc | PARTIAL | PageId.task (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `rematch` | Tìm Partner thay thế | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `completeConfirm` | Xác nhận hoàn thành | PARTIAL | PageId.payment (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `review` | Đánh giá hai chiều | PARTIAL | PageId.rating (task lifecycle unavailable) | POST users/me/reviews/{taskId} | AccountControllerTest |
| `bookAgain` | Đặt lại nhanh | PARTIAL | PageId.create (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `inbox` | Hộp thư | PARTIAL | PageId.messages (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `chat` | Chat theo công việc | PARTIAL | PageId.chat (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `notifications` | Trung tâm thông báo | PARTIAL | PageId.notifications (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `notificationPrefs` | Cài đặt thông báo | EXISTS | PageId.settings | users/me/settings | account_api_test.dart |
| `support` | Trung tâm trợ giúp | PARTIAL | PageId.help / static help | No support ticket API | customer_journey_test.dart (demo only) |
| `ticketCreate` | Tạo phiếu hỗ trợ | PARTIAL | PageId.complaint (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `tickets` | Danh sách hỗ trợ | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `dispute` | Khiếu nại / tranh chấp | PARTIAL | PageId.complaint (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `disputeDetail` | Chi tiết tranh chấp | PARTIAL | PageId.complaintStatus (existing demo UI) | Missing or guarded unavailable | No live E2E; explicit API gap |
| `safety` | Trung tâm an toàn | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `report` | Báo cáo người dùng | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `account` | Tài khoản Customer | PARTIAL | PageId.profile / accountScreens | users/me; users/me/statistics | account_api_test.dart |
| `profileEdit` | Sửa thông tin cá nhân | EXISTS | PageId.editProfile | PATCH users/me/profile | account_api_test.dart |
| `security` | Bảo mật / đổi mật khẩu | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `changePassword` | Đổi mật khẩu hiện tại | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `sessions` | Thiết bị đăng nhập | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `paymentHistory` | Lịch sử giao dịch | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `rewards` | Điểm thưởng demo | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `settings` | Cài đặt ứng dụng | PARTIAL | PageId.settings | users/me/settings | account_api_test.dart |
| `about` | Giới thiệu / Điều khoản / Xóa tài khoản | PARTIAL | PageId.help / static terms | Account deletion API missing | customer_journey_test.dart (demo only) |
| `partnerWelcome` | Trở thành Partner | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `kyc` | Xác minh danh tính KYC | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `kycStatus` | Trạng thái duyệt KYC | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerSkills` | Kỹ năng & dịch vụ | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerAreas` | Khu vực hoạt động | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerAvailability` | Lịch rảnh | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `jobs` | Danh sách việc phù hợp | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `jobDetail` | Xem chi tiết công việc | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerSchedule` | Lịch Partner | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerWork` | Việc đang thực hiện | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `checkin` | Check-in & di chuyển | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `evidence` | Ảnh & bằng chứng hoàn thành | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerIssue` | Báo vấn đề công việc | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerReviews` | Đánh giá nhận được | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `earnings` | Tổng quan thu nhập | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `transactions` | Sổ giao dịch | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `payout` | Yêu cầu rút tiền (demo) | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `performance` | Hiệu suất Partner | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerProfile` | Hồ sơ Partner | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `testGuide` | Hướng dẫn E2E | OUT_OF_SCOPE | Dev only; no release route | None | No production demo controls |
| `developer` | Bảng điều khiển Demo | OUT_OF_SCOPE | Dev only; no release route | None | No production demo controls |
| `screenIndex` | Danh sách tất cả màn | OUT_OF_SCOPE | Dev only; no release route | None | No production demo controls |
| `uiStates` | Loading / Empty / Error / Offline | OUT_OF_SCOPE | Dev only; no release route | None | No production demo controls |
| `noShow` | Báo Partner không đến | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `paymentAdjustment` | Điều chỉnh tiền mẫu | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `welcomeTour` | Giới thiệu & hướng dẫn | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `mapPicker` | Bản đồ chọn điểm (demo) | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `uploadCenter` | Ảnh yêu cầu dịch vụ | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `priceBreakdown` | Bảng giá & hết hạn | EXISTS | CustomerBooking review / fee breakdown and expiry | GET users/me/booking-quotes/{id} | BookingDraftControllerTest; customer_v3_booking_test.dart |
| `recurringPlans` | Dịch vụ định kỳ | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `vouchers` | Kho voucher & điểm | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `taskChecklist` | Checklist & bằng chứng | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `chatAttachment` | Chat đính kèm ảnh/vị trí | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `helpFaq` | FAQ từng chủ đề | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `incidentCenter` | Xử lý tình huống | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `contactPrivacy` | Bảo mật thông tin liên hệ | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `availabilityPro` | Lịch rảnh theo giờ | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerTraining` | Partner Academy | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `partnerAgreement` | Thỏa thuận Partner | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `bankAccounts` | Ngân hàng Partner | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `bankAdd` | Thêm ngân hàng demo | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `payoutDetail` | Theo dõi rút tiền demo | OUT_OF_SCOPE | Existing Partner UI / later phase | Not modified | Customer requested first |
| `appChangelog` | Điểm mới phiên bản V3 | MISSING | No dedicated production route | Missing | See API gaps; not claimed implemented |
| `diagnostics` | Chẩn đoán và xuất state | OUT_OF_SCOPE | Dev only; no release route | None | No production demo controls |
