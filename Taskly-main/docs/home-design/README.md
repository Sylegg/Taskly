# TaskLy Customer Home

High-fidelity Flutter implementation, với bản sắc Emerald / Mint / White và robot vector riêng của TaskLy. Ảnh tham khảo chỉ định hướng cấu trúc marketplace; không dùng màu cam, mascot, quảng cáo hoặc Community feed của ứng dụng tham khảo.

[Mở gallery để so sánh trạng thái và kích thước](index.html).

## Bộ thiết kế bàn giao

| # | Output | Preview 390px / component |
| --- | --- | --- |
| 1 | Returning user + active task | [Trang đầu](returning-390x844.png), [Active task & Assistant](returning-scroll-450.png) |
| 2 | New user | [Home](new-390x844.png), [Gợi ý & hướng dẫn](new-scroll-900.png) |
| 3 | No active task | [Home](no-active-390x844.png), [Nội dung tiếp theo](no-active-scroll-450.png) |
| 4 | Loading | [Skeleton](loading-390x844.png) |
| 5 | Offline | [Cache + banner](offline-390x844.png) |
| 6 | Bottom navigation | [Component](component-bottom-navigation.png) |
| 7 | Service category | [Component](component-service-category.png), [Grid 4×2](component-service-grid.png) |
| 8 | Active task | [Component](component-active-task.png) |
| 9 | Book again | [Component](component-book-again.png) |
| 10 | Favorite partner | [Component](component-favorite-partner.png) |
| 11 | TaskLy Assistant | [Component](component-assistant.png) |
| 12 | Rewards | [Component](component-rewards.png) |
| 13 | Recommended service | [Component](component-recommended-service.png) |

Thêm: [Header](component-header.png), [Upcoming](component-upcoming-task.png), [Tips](component-home-tip.png), [Lỗi tải dữ liệu](error-390x844.png).

Mỗi trạng thái có ảnh tương ứng cho 360×800, 390×844 và 430×932. PNG render ở tỷ lệ 3× (ví dụ 390×844 → 1170×2532), không chứa Ahem/test-font placeholders. Preview sử dụng font hệ thống Segoe để render chữ tiếng Việt; Android dùng font hệ thống qua Flutter. Không đóng gói hoặc phân phối file font Windows.

## UX & visual rules

- Hero organic Mint, greeting động theo tên, địa chỉ chọn được và search thực sự nhập được.
- 8 dịch vụ nằm trước công việc, rồi Assistant, gợi ý dịch vụ, đặt lại, favorites, rewards và tips.
- Công việc đang di chuyển/làm việc có timeline, Partner, rating, ETA và các nút nhắn tin/theo dõi. Lịch nhận trước trong tương lai được tách sang Upcoming.
- Không có active/upcoming/history/favorite thì ẩn section tương ứng. User mới có hướng dẫn 3 bước. Dismiss Assistant áp dụng cho phiên Home hiện tại.
- Không đưa marketing lên đầu và không thêm Community vào navigation. Promotions hiện không có dữ liệu nên không render.
- Card bo 20–28px, bóng nhẹ, padding 20px, gap section 28px. CTA có press scale 0.98. Robot chuyển động vào vị trí rất nhẹ, tôn trọng reduced motion; không lặp animation gây phân tâm.
- Bottom navigation cố định, SafeArea, robot AI ở giữa không có nhãn “Đặt việc”. Robot nhún và nghiêng nhẹ ba nhịp rồi nghỉ, tôn trọng cài đặt giảm chuyển động. Chạm robot mở chat trợ lý riêng. Chat hiện hướng dẫn dịch vụ bằng câu trả lời tự động cục bộ, chưa kết nối API AI hội thoại. Đặt dịch vụ qua CTA ở hero hoặc danh mục dịch vụ. Các trang Customer khác dùng cùng navigation.

## Flutter components

`lib/features/home/home_components.dart` chứa `TaskLyHomeHeader`, `AddressSelector`, `TaskLySearchBar`, `ServiceGrid`, `ServiceIcon`, `TaskLyAssistantCard`, `ActiveTaskCard`, `UpcomingTaskCard`, `RecommendedServiceCard`, `BookAgainCard`, `FavoritePartnerCard`, `RewardsProgressCard`, `HomeTipCard`, `TaskLyBottomNav`, `CentralBookButton`, `SectionHeader`, `HomeSkeleton`.

`lib/features/home/customer_home.dart` sắp xếp nội dung theo snapshot, nối controller và xử lý chọn địa chỉ, dismiss, pull-to-refresh, error/cached/offline states. Địa chỉ chọn trên Home được chuyển vào draft khi bắt đầu đặt việc. Book Again giữ nội dung lần đặt trước. Favorite CTA mở luồng tạo booking; việc chọn/giữ lịch cho đúng Partner cần hợp đồng booking backend.

## Dữ liệu thật và giới hạn hiện tại

Xác thực Customer bằng SĐT và mật khẩu vẫn dùng backend. Nghiệp vụ công việc hiện vẫn dùng mock repositories của Taskly-main. Catalog mô phỏng được bổ sung Tổng vệ sinh, Vệ sinh máy lạnh, Chăm thú cưng và IT Support để 8 shortcut có màn hình dịch vụ tương ứng.

Home không tự gán điểm thưởng, favorites hoặc service ratings cho người dùng. `HomeExtras` nhận các dữ liệu này khi có; mặc định chúng vắng mặt. Dữ liệu 240 điểm/favorite/rating trong gallery là fixture rõ ràng ở `tool/home_preview.dart`; Rewards chưa có API đổi voucher.

Khi kiểm tra phiên trên resume hoặc retry gặp lỗi mạng/timeout, Home giữ snapshot trong RAM và hiển thị banner offline. Pull-to-refresh kiểm tra lại kết nối. Chưa có lưu cache công việc xuống đĩa hoặc đồng bộ job giữa Customer/Partner. Promotions và favorites cần nối API thực tế trước phát hành production.

## Chạy và kiểm tra

```powershell
# App Customer với xác thực backend
flutter run --flavor customer --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1

# Preview UI bằng fixture, không đăng nhập
flutter run --flavor customer -t tool/home_preview.dart --dart-define=HOME_PREVIEW=returning
# HOME_PREVIEW: returning / new / no-active / loading / offline

flutter analyze
flutter test

# Xuất PNG trên môi trường Windows hiện tại
flutter test test/home_design_test.dart --dart-define=HOME_CAPTURE=true
```

QA bao gồm cả 3 kích thước, scroll qua toàn bộ nội dung, keyboard search, đổi địa chỉ, dismiss Assistant, tạo draft, SafeArea, text scale 130%, offline recovery và các journey Customer/Tasker hiện có.
