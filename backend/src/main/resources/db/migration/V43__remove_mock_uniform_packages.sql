-- Remove untouched demo catalog entries. Keep referenced packages for order history.
UPDATE partner_uniform_packages SET active=false,version=version+1
WHERE name IN ('Cơ bản DEMO','Tiêu chuẩn DEMO','Đầy đủ DEMO')
AND description='Cấu hình mẫu; Admin cần xác nhận nội dung gói';

DELETE FROM partner_uniform_inventory WHERE package_id IN (
 SELECT p.id FROM partner_uniform_packages p
 WHERE p.name IN ('Cơ bản DEMO','Tiêu chuẩn DEMO','Đầy đủ DEMO')
 AND p.description='Cấu hình mẫu; Admin cần xác nhận nội dung gói'
 AND NOT EXISTS (SELECT 1 FROM partner_uniform_orders o WHERE o.package_id=p.id)
);
DELETE FROM partner_uniform_packages p
WHERE p.name IN ('Cơ bản DEMO','Tiêu chuẩn DEMO','Đầy đủ DEMO')
AND p.description='Cấu hình mẫu; Admin cần xác nhận nội dung gói'
AND NOT EXISTS (SELECT 1 FROM partner_uniform_orders o WHERE o.package_id=p.id);
