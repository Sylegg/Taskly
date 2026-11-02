-- Reusable PostgreSQL catalogue import. Existing rows and prices are never overwritten.
-- Requires an active account with SERVICE_MANAGE permission for pricing attribution.
BEGIN;

CREATE TEMP TABLE seed_categories (
    slug VARCHAR(80) PRIMARY KEY,
    name VARCHAR(160) NOT NULL,
    description VARCHAR(1000) NOT NULL,
    display_order INTEGER NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_categories VALUES
('cleaning', 'Dọn dẹp nhà cửa', 'Dọn dẹp theo giờ và tổng vệ sinh nhà ở, căn hộ, phòng trọ.', 10),
('upholstery', 'Vệ sinh sofa và nệm', 'Làm sạch sofa, nệm tại nhà bằng phương pháp phù hợp với chất liệu.', 20),
('air-conditioning', 'Dịch vụ máy lạnh', 'Vệ sinh, kiểm tra và xử lý các vấn đề thường gặp của máy lạnh.', 30),
('appliance-repair', 'Sửa chữa điện gia dụng', 'Kiểm tra sự cố máy giặt, tủ lạnh và tư vấn phương án sửa chữa.', 40),
('furniture', 'Lắp ráp và tháo dỡ nội thất', 'Lắp ráp, tháo dỡ bàn ghế, giường, tủ và kệ trong gia đình.', 50),
('moving', 'Chuyển nhà và đóng gói', 'Hỗ trợ đóng gói, di chuyển đồ đạc khi chuyển phòng trọ hoặc căn hộ.', 60),
('shopping', 'Đi chợ và mua sắm hộ', 'Mua thực phẩm, nhu yếu phẩm và giao hàng theo danh sách của khách.', 70),
('pet-care', 'Chăm sóc thú cưng', 'Chăm sóc chó, mèo tại nhà và hỗ trợ dắt chó đi dạo.', 80),
('it-support', 'Hỗ trợ công nghệ', 'Hỗ trợ máy tính, phần mềm hợp pháp và thiết lập mạng Wi-Fi gia đình.', 90),
('laundry', 'Giặt sấy và ủi quần áo', 'Giặt sấy quần áo thông thường và ủi trang phục theo yêu cầu.', 100);

CREATE TEMP TABLE seed_services (
    category_slug VARCHAR(80) NOT NULL,
    slug VARCHAR(100) PRIMARY KEY,
    name VARCHAR(160) NOT NULL,
    short_description VARCHAR(500) NOT NULL,
    description VARCHAR(4000) NOT NULL,
    price_min BIGINT NOT NULL,
    price_max BIGINT NOT NULL,
    duration_minutes INTEGER NOT NULL,
    display_order INTEGER NOT NULL,
    pricing_mode VARCHAR(16) NOT NULL,
    quantity_field VARCHAR(80),
    base_amount BIGINT NOT NULL,
    unit_amount BIGINT NOT NULL
) ON COMMIT DROP;

INSERT INTO seed_services VALUES
('cleaning', 'home-cleaning', 'Dọn nhà theo giờ',
 'Quét, lau sàn, vệ sinh bếp và phòng tắm, sắp xếp đồ dùng sinh hoạt.',
 'Một người hỗ trợ dọn các khu vực sinh hoạt theo số giờ đã chọn: quét và lau sàn, lau bề mặt dễ tiếp cận, vệ sinh bếp và phòng tắm. Giá 70.000đ/giờ. Khách chọn dụng cụ có sẵn hoặc yêu cầu người hỗ trợ mang theo. Không bao gồm xử lý rác nguy hại, vệ sinh trên cao hoặc di chuyển đồ nặng.',
 70000, 560000, 180, 10, 'HOURLY', NULL, 0, 70000),
('cleaning', 'deep-cleaning', 'Tổng vệ sinh nhà ở',
 'Làm sạch kỹ sàn, bếp, phòng tắm và các bề mặt trong nhà theo diện tích.',
 'Tổng vệ sinh các khu vực đã khai báo, tập trung vào bụi bẩn tích tụ trên sàn, bề mặt bếp, phòng tắm và cửa kính trong tầm với nếu khách yêu cầu. Giá gồm 100.000đ chuẩn bị và 12.000đ/m². Không bao gồm vệ sinh mặt ngoài trên cao, xử lý nấm mốc diện rộng, phế thải xây dựng hoặc hóa chất chuyên dụng.',
 112000, 2500000, 240, 20, 'FIELD', 'area', 100000, 12000),
('upholstery', 'sofa-cleaning', 'Vệ sinh sofa tại nhà',
 'Hút bụi và làm sạch sofa vải bằng phương pháp phù hợp với chất liệu.',
 'Giá 350.000đ/bộ sofa vải tối đa 3 chỗ ngồi. Bao gồm kiểm tra chất liệu, hút bụi và vệ sinh bề mặt bằng thiết bị phù hợp. Khách cung cấp điện, nước và khu vực thao tác. Sofa da, sofa lớn hơn 3 chỗ hoặc vết bẩn đặc biệt cần trao đổi phạm vi trước khi đặt. Thời gian khô phụ thuộc chất liệu và thông gió.',
 350000, 1050000, 120, 30, 'FIELD', 'items', 0, 350000),
('upholstery', 'mattress-cleaning', 'Vệ sinh nệm tại nhà',
 'Hút bụi và vệ sinh bề mặt nệm đơn hoặc nệm đôi trong gia đình.',
 'Giá 250.000đ/nệm có kích thước tối đa 1,8m × 2m. Bao gồm hút bụi, kiểm tra chất liệu và làm sạch bề mặt theo phương pháp phù hợp. Không bao gồm giặt chăn ga, sửa nệm hoặc cam kết loại bỏ toàn bộ vết ố lâu năm. Khách chuẩn bị điện, nước và không gian để nệm khô.',
 250000, 750000, 90, 40, 'FIELD', 'items', 0, 250000),
('air-conditioning', 'air-conditioning', 'Vệ sinh máy lạnh',
 'Vệ sinh lưới lọc, dàn lạnh và dàn nóng của máy lạnh treo tường.',
 'Giá 180.000đ/máy lạnh treo tường tối đa 2HP ở vị trí dễ tiếp cận. Bao gồm vệ sinh lưới lọc, dàn lạnh, dàn nóng và kiểm tra hoạt động cơ bản. Máy âm trần, tủ đứng hoặc vị trí cần giàn giáo cần thống nhất phạm vi riêng. Không bao gồm nạp gas, thay linh kiện hoặc sửa chữa sự cố.',
 180000, 720000, 60, 50, 'FIELD', 'units', 0, 180000),
('air-conditioning', 'aircon-repair', 'Kiểm tra sự cố máy lạnh',
 'Kiểm tra tình trạng không lạnh, rò nước hoặc tiếng ồn bất thường.',
 'Phí kiểm tra tại nhà 200.000đ cho một máy lạnh ở vị trí dễ tiếp cận. Kỹ thuật viên xác định nguyên nhân, giải thích phương án xử lý và báo giá phần sửa chữa nếu có. Phí này chỉ bao gồm kiểm tra; linh kiện, gas và công sửa chữa phát sinh cần được khách đồng ý riêng trước khi thực hiện.',
 200000, 200000, 60, 60, 'FIXED', NULL, 200000, 0),
('appliance-repair', 'washing-machine-repair', 'Kiểm tra sự cố máy giặt',
 'Kiểm tra máy giặt không chạy, không thoát nước hoặc báo lỗi.',
 'Phí kiểm tra tại nhà 180.000đ cho một máy giặt gia đình. Bao gồm kiểm tra nguồn điện, đường cấp và thoát nước, mã lỗi và tư vấn phương án xử lý. Không bao gồm linh kiện hoặc công sửa chữa phát sinh; kỹ thuật viên phải báo giá và được khách đồng ý trước khi sửa.',
 180000, 180000, 60, 70, 'FIXED', NULL, 180000, 0),
('appliance-repair', 'refrigerator-repair', 'Kiểm tra sự cố tủ lạnh',
 'Kiểm tra tủ lạnh không lạnh, đóng tuyết bất thường hoặc phát tiếng ồn.',
 'Phí kiểm tra tại nhà 200.000đ cho một tủ lạnh gia đình. Bao gồm kiểm tra tình trạng hoạt động, nhiệt độ, nguồn điện và tư vấn phương án xử lý. Không bao gồm thay linh kiện, nạp gas hoặc công sửa chữa phát sinh. Mọi hạng mục sửa chữa được báo giá riêng và cần khách đồng ý.',
 200000, 200000, 60, 80, 'FIXED', NULL, 200000, 0),
('furniture', 'assembly', 'Lắp ráp nội thất',
 'Lắp ráp bàn ghế, kệ, giường hoặc tủ theo hướng dẫn của nhà sản xuất.',
 'Một người hỗ trợ lắp ráp nội thất với giá 100.000đ/giờ. Khách chuẩn bị đầy đủ bộ phận, phụ kiện và hướng dẫn lắp ráp; người hỗ trợ mang dụng cụ cầm tay cơ bản. Không bao gồm mua phụ kiện, cải tạo kết cấu, điện nước hoặc vận chuyển. Đồ lớn cần nhiều người phải trao đổi trước.',
 100000, 800000, 120, 90, 'HOURLY', NULL, 0, 100000),
('furniture', 'furniture-disassembly', 'Tháo dỡ nội thất',
 'Tháo giường, tủ hoặc kệ, phân loại và giữ gọn các phụ kiện.',
 'Một người hỗ trợ tháo dỡ nội thất với giá 100.000đ/giờ. Bao gồm tháo các bộ phận có thể tháo an toàn, gom phụ kiện và ghi chú để thuận tiện lắp lại. Không bao gồm phá dỡ đồ gắn liền công trình, vận chuyển, vật tư đóng gói hoặc tháo thiết bị điện nước. Khách thông báo trước đồ quá nặng hoặc xuống cấp.',
 100000, 800000, 120, 100, 'HOURLY', NULL, 0, 100000),
('moving', 'moving', 'Hỗ trợ chuyển nhà',
 'Hỗ trợ nâng, chuyển và sắp xếp đồ đạc khi chuyển phòng trọ hoặc căn hộ.',
 'Giá 150.000đ/giờ cho một người hỗ trợ vận chuyển đồ đạc, tính theo số giờ đã chọn. Khách cung cấp địa chỉ đi, địa chỉ đến, tầng và tình trạng thang máy. Giá chưa bao gồm xe tải, phí đường, vật tư đóng gói hoặc nhân sự bổ sung. Đồ quá khổ, két sắt và thiết bị đặc biệt cần phương án riêng.',
 150000, 1200000, 180, 110, 'HOURLY', NULL, 0, 150000),
('moving', 'packing', 'Đóng gói đồ đạc',
 'Phân loại, bọc, đóng thùng và dán nhãn đồ dùng trước khi chuyển nhà.',
 'Một người hỗ trợ đóng gói với giá 90.000đ/giờ. Bao gồm phân loại đồ theo phòng, bọc đồ dễ vỡ bằng vật tư khách cung cấp, đóng thùng và dán nhãn. Khách chuẩn bị thùng, băng keo và vật liệu bảo vệ. Không bao gồm vận chuyển hoặc bảo quản tài sản có giá trị; khách tự quản lý tiền, giấy tờ và trang sức.',
 90000, 720000, 180, 120, 'HOURLY', NULL, 0, 90000),
('shopping', 'shopping', 'Đi chợ hộ',
 'Mua thực phẩm theo danh sách và giao đến địa chỉ của khách.',
 'Phí đi chợ hộ 60.000đ/lượt cho một điểm mua trong phạm vi 3km từ địa chỉ giao. Khách ghi rõ danh sách, số lượng, ngân sách và yêu cầu hóa đơn. Tiền mua hàng nằm ngoài phí dịch vụ và được đối soát bằng hóa đơn hoặc ảnh biên nhận. Hàng thay thế hoặc vượt ngân sách chỉ được mua sau khi khách đồng ý.',
 60000, 60000, 60, 130, 'FIXED', NULL, 60000, 0),
('shopping', 'grocery-delivery', 'Mua nhu yếu phẩm hộ',
 'Mua đồ dùng thiết yếu tại cửa hàng hoặc siêu thị theo yêu cầu.',
 'Phí hỗ trợ 50.000đ/lượt cho một điểm mua trong phạm vi 3km từ địa chỉ giao. Áp dụng cho nhu yếu phẩm thông thường có thể mang bằng xe máy. Giá không bao gồm tiền hàng, phí gửi xe hoặc phí giao riêng của cửa hàng. Người hỗ trợ xác nhận hàng thay thế và gửi biên nhận để khách kiểm tra.',
 50000, 50000, 60, 140, 'FIXED', NULL, 50000, 0),
('pet-care', 'pet-care', 'Chăm sóc thú cưng tại nhà',
 'Cho ăn, thay nước, vệ sinh khu vực sinh hoạt và chơi cùng chó hoặc mèo.',
 'Giá 120.000đ/thú cưng cho một buổi chăm sóc khoảng 60 phút. Khách chuẩn bị thức ăn, dụng cụ và hướng dẫn sinh hoạt. Bao gồm cho ăn, thay nước, vệ sinh khay hoặc khu vực sinh hoạt cơ bản và cập nhật tình trạng cho khách. Không bao gồm khám, điều trị, cho thuốc, cắt tỉa hoặc chăm sóc thú đang có bệnh cần chuyên môn.',
 120000, 360000, 60, 150, 'FIELD', 'count', 0, 120000),
('pet-care', 'dog-walking', 'Dắt chó đi dạo',
 'Dắt chó đi dạo trong khu vực gần nhà theo hướng dẫn của chủ nuôi.',
 'Giá 60.000đ/chó cho một lượt đi dạo khoảng 45 phút. Khách chuẩn bị dây dắt, vòng cổ phù hợp và thông báo tính khí, sức khỏe của chó. Người hỗ trợ giữ chó có dây dắt và thu gom chất thải. Chó có tiền sử tấn công, cần chăm sóc đặc biệt hoặc đi ngoài khu vực đã thống nhất cần trao đổi trước.',
 60000, 180000, 45, 160, 'FIELD', 'count', 0, 60000),
('it-support', 'it-support', 'Hỗ trợ máy tính',
 'Kiểm tra lỗi cơ bản, thiết lập phần mềm hợp pháp và hướng dẫn sử dụng.',
 'Giá 120.000đ/giờ theo số giờ đã chọn, tại nhà hoặc từ xa theo biểu mẫu. Hỗ trợ kiểm tra lỗi thông thường, cài đặt phần mềm có bản quyền hoặc miễn phí hợp pháp và thiết lập thiết bị ngoại vi. Khách sao lưu dữ liệu quan trọng trước buổi làm việc. Không bao gồm thay linh kiện, mua bản quyền hoặc khôi phục dữ liệu chuyên sâu.',
 120000, 960000, 90, 170, 'HOURLY', NULL, 0, 120000),
('it-support', 'wifi-setup', 'Cài đặt Wi-Fi gia đình',
 'Thiết lập router, đổi mật khẩu và kiểm tra kết nối mạng trong gia đình.',
 'Phí 180.000đ cho một buổi khoảng 60 phút, hỗ trợ một router gia đình. Bao gồm cấu hình Wi-Fi, đổi mật khẩu, kết nối thiết bị và kiểm tra vị trí đặt router. Khách cung cấp thiết bị, nguồn điện và thông tin kết nối của nhà mạng. Không bao gồm mua thiết bị, kéo cáp mới, phí nhà mạng hoặc sửa phần cứng.',
 180000, 180000, 60, 180, 'FIXED', NULL, 180000, 0),
('laundry', 'laundry', 'Giặt sấy quần áo',
 'Giặt và sấy quần áo sinh hoạt thông thường, phân loại theo hướng dẫn.',
 'Giá 25.000đ/kg quần áo thông thường; khách khai báo số kg nguyên trong biểu mẫu và thống nhất khối lượng trước khi thực hiện. Bao gồm phân loại cơ bản, giặt và sấy theo nhãn chăm sóc. Không bao gồm giặt khô, đồ da, đồ cao cấp, chăn nệm hoặc xử lý vết bẩn đặc biệt. Khách ghi rõ đồ cần giặt riêng và hướng dẫn giao nhận.',
 25000, 250000, 120, 190, 'FIELD', 'weightKg', 0, 25000),
('laundry', 'ironing', 'Ủi quần áo',
 'Ủi và gấp áo, quần thông thường theo số lượng khách đăng ký.',
 'Giá 15.000đ/món quần áo thông thường. Khách cung cấp quần áo đã sạch và khô, thông tin chất liệu và yêu cầu gấp hoặc treo. Không bao gồm giặt, đồ da, trang phục đính kết phức tạp hoặc váy cưới. Khách ghi rõ điều kiện sử dụng bàn ủi và khu vực thao tác tại nhà trong hướng dẫn tiếp cận.',
 15000, 150000, 90, 200, 'FIELD', 'items', 0, 15000);

CREATE TEMP TABLE seed_actor ON COMMIT DROP AS
SELECT u.id FROM users u
WHERE u.status = 'ACTIVE'
  AND EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN role_permissions rp ON rp.role_id = ur.role_id
      JOIN permissions p ON p.id = rp.permission_id
      WHERE ur.user_id = u.id AND p.permission_key = 'SERVICE_MANAGE'
  )
ORDER BY u.created_at, u.id LIMIT 1;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM seed_actor) THEN
        RAISE EXCEPTION 'An active account with SERVICE_MANAGE permission is required; no data was imported.';
    END IF;
END $$;

CREATE TEMP TABLE seed_new_categories ON COMMIT DROP AS
WITH inserted AS (
    INSERT INTO service_categories (id, slug, name, description, active, display_order, version, created_at, updated_at)
    SELECT gen_random_uuid(), slug, name, description, TRUE, display_order, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM seed_categories
    ON CONFLICT (slug) DO NOTHING
    RETURNING id, slug
) SELECT * FROM inserted;

CREATE TEMP TABLE seed_new_services ON COMMIT DROP AS
WITH inserted AS (
    INSERT INTO services (id, category_id, slug, name, short_description, description,
        suggested_price_min, suggested_price_max, currency, estimated_duration_minutes,
        active, display_order, version, created_at, updated_at)
    SELECT gen_random_uuid(), c.id, s.slug, s.name, s.short_description, s.description,
        s.price_min, s.price_max, 'VND', s.duration_minutes, TRUE, s.display_order, 0,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM seed_services s JOIN service_categories c ON c.slug = s.category_slug
    WHERE c.active = TRUE AND c.deleted_at IS NULL
    ON CONFLICT (slug) DO NOTHING
    RETURNING id, slug
) SELECT * FROM inserted;

CREATE TEMP TABLE seed_new_rules ON COMMIT DROP AS
WITH inserted AS (
    INSERT INTO service_pricing_rules (service_id, mode, quantity_field, base_amount,
        unit_amount, platform_fee_amount, quote_ttl_minutes, enabled, version, updated_by, updated_at)
    SELECT n.id, s.pricing_mode, s.quantity_field, s.base_amount, s.unit_amount,
        0, 15, TRUE, 1, a.id, CURRENT_TIMESTAMP
    FROM seed_new_services n JOIN seed_services s ON s.slug = n.slug CROSS JOIN seed_actor a
    ON CONFLICT (service_id) DO NOTHING
    RETURNING service_id
) SELECT * FROM inserted;

SELECT 'categories_inserted' AS result, count(*) AS rows FROM seed_new_categories
UNION ALL SELECT 'services_inserted', count(*) FROM seed_new_services
UNION ALL SELECT 'pricing_rules_inserted', count(*) FROM seed_new_rules;

COMMIT;
