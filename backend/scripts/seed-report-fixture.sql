-- TaskLy report fixture: first 60 days at Vinhomes Grand Park, Quận 9.
-- Run with psql after Flyway has completed:
--   psql "$DATABASE_URL" -v environment=development -v mode=reset -f backend/scripts/seed-report-fixture.sql
-- mode=upsert intentionally rebuilds only this fixture, so repeated reports stay deterministic.

\if :{?environment}
\else
\set environment 'development'
\endif
\if :{?mode}
\else
\set mode 'reset'
\endif

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF :'environment' NOT IN ('development', 'dev', 'local', 'test') THEN
    RAISE EXCEPTION 'Report fixture is allowed only in development, dev, local, or test';
  END IF;
  IF :'mode' NOT IN ('reset', 'upsert') THEN
    RAISE EXCEPTION 'mode must be reset or upsert';
  END IF;
END $$;

CREATE TEMP TABLE report_fixture_users ON COMMIT DROP AS
SELECT id FROM users WHERE email LIKE 'taskly.report.%@gmail.com';

-- Remove only records owned by the synthetic report accounts.
DELETE FROM customer_support_message_reads WHERE admin_id IN (SELECT id FROM report_fixture_users)
   OR message_id IN (SELECT id FROM customer_support_messages WHERE user_id IN (SELECT id FROM report_fixture_users));
DELETE FROM task_arrival_reports WHERE task_id IN (SELECT id FROM tasks WHERE customer_id IN (SELECT id FROM report_fixture_users));
DELETE FROM customer_support_messages WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM support_messages WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM task_messages WHERE task_id IN (SELECT id FROM tasks WHERE customer_id IN (SELECT id FROM report_fixture_users))
   OR sender_id IN (SELECT id FROM report_fixture_users);
DELETE FROM customer_booking_notifications WHERE customer_id IN (SELECT id FROM report_fixture_users);
DELETE FROM customer_reviews WHERE customer_id IN (SELECT id FROM report_fixture_users);
DELETE FROM task_booking_services WHERE task_id IN (SELECT id FROM tasks WHERE customer_id IN (SELECT id FROM report_fixture_users));
DELETE FROM task_booking_payments WHERE task_id IN (SELECT id FROM tasks WHERE customer_id IN (SELECT id FROM report_fixture_users));
DELETE FROM customer_price_quotes WHERE customer_id IN (SELECT id FROM report_fixture_users);
DELETE FROM customer_refund_credits WHERE customer_id IN (SELECT id FROM report_fixture_users);
DELETE FROM customer_refund_withdrawals WHERE customer_id IN (SELECT id FROM report_fixture_users);
DELETE FROM task_status_history WHERE task_id IN (SELECT id FROM tasks WHERE customer_id IN (SELECT id FROM report_fixture_users))
   OR actor_id IN (SELECT id FROM report_fixture_users);
DELETE FROM partner_task_settlements WHERE partner_id IN (SELECT id FROM report_fixture_users);
DELETE FROM tasks WHERE customer_id IN (SELECT id FROM report_fixture_users)
   OR tasker_id IN (SELECT id FROM report_fixture_users);
DELETE FROM partner_notification_outbox WHERE application_id IN
  (SELECT id FROM partner_applications WHERE user_id IN (SELECT id FROM report_fixture_users));
DELETE FROM recruitment_audit WHERE actor_id IN (SELECT id FROM report_fixture_users)
   OR application_id IN (SELECT id FROM partner_applications WHERE user_id IN (SELECT id FROM report_fixture_users));
DELETE FROM recruitment_requests WHERE actor_id IN (SELECT id FROM report_fixture_users);
DELETE FROM partner_application_services WHERE application_id IN
  (SELECT id FROM partner_applications WHERE user_id IN (SELECT id FROM report_fixture_users));
DELETE FROM partner_application_areas WHERE application_id IN
  (SELECT id FROM partner_applications WHERE user_id IN (SELECT id FROM report_fixture_users));
DELETE FROM partner_bank_accounts WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM partner_wallet_transactions WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM partner_wallets WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM partner_applications WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM user_payment_methods WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM user_preferences WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM addresses WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM user_roles WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM user_profiles WHERE user_id IN (SELECT id FROM report_fixture_users);
DELETE FROM users WHERE id IN (SELECT id FROM report_fixture_users);

CREATE TEMP TABLE report_customers(id uuid PRIMARY KEY, n int) ON COMMIT DROP;
CREATE TEMP TABLE report_partners(id uuid PRIMARY KEY, n int) ON COMMIT DROP;
CREATE TEMP TABLE report_tasks(id uuid PRIMARY KEY, n int, status varchar(32), customer_id uuid, partner_id uuid) ON COMMIT DROP;

-- The launch date is always 60 days before the seed run; no record predates it.
INSERT INTO users(id,email,phone,password_hash,status,active_mode,email_verified_at,used_customer,used_partner,created_at,updated_at)
SELECT md5('taskly-report-fixture:customer:'||g)::uuid,
       'taskly.report.customer'||lpad(g::text,2,'0')||'@gmail.com',
       '09'||lpad((12000000 + g)::text,8,'0'),
       crypt('Taskly-report-2026', gen_salt('bf')),
       CASE WHEN g >= 23 THEN 'SUSPENDED' ELSE 'ACTIVE' END,
       'CUSTOMER',
       now() - interval '60 days' + g * interval '2 days',
       true, false,
       now() - interval '60 days' + g * interval '2 days',
       now() - interval '60 days' + g * interval '2 days'
FROM generate_series(1,24) g;

INSERT INTO report_customers
SELECT md5('taskly-report-fixture:customer:'||g)::uuid, g FROM generate_series(1,24) g;

INSERT INTO users(id,email,phone,password_hash,status,active_mode,email_verified_at,used_customer,used_partner,created_at,updated_at)
SELECT md5('taskly-report-fixture:partner:'||g)::uuid,
       'taskly.report.partner'||lpad(g::text,2,'0')||'@gmail.com',
       '03'||lpad((88000000 + g)::text,8,'0'),
       crypt('Taskly-report-2026', gen_salt('bf')),
       CASE WHEN g = 12 THEN 'SUSPENDED' ELSE 'ACTIVE' END,
       'CUSTOMER',
       now() - interval '60 days' + (3 + g * 3) * interval '1 day',
       false, true,
       now() - interval '60 days' + (3 + g * 3) * interval '1 day',
       now() - interval '60 days' + (3 + g * 3) * interval '1 day'
FROM generate_series(1,12) g;

INSERT INTO report_partners
SELECT md5('taskly-report-fixture:partner:'||g)::uuid, g FROM generate_series(1,12) g;

INSERT INTO users(id,email,phone,password_hash,status,active_mode,email_verified_at,used_customer,used_partner,created_at,updated_at)
VALUES
 (md5('taskly-report-fixture:admin:1')::uuid,'taskly.report.admin@gmail.com','0988000001',crypt('Taskly-report-2026',gen_salt('bf')),'ACTIVE','CUSTOMER',now()-interval '58 days',false,false,now()-interval '58 days',now()-interval '58 days'),
 (md5('taskly-report-fixture:admin:2')::uuid,'taskly.report.support@gmail.com','0988000002',crypt('Taskly-report-2026',gen_salt('bf')),'ACTIVE','CUSTOMER',now()-interval '56 days',false,false,now()-interval '56 days',now()-interval '56 days');

INSERT INTO user_profiles(user_id,full_name,language,created_at,updated_at)
SELECT id, CASE WHEN id IN (SELECT id FROM report_customers) THEN
  (ARRAY['Nguyễn Minh Anh','Trần Thị Lan','Lê Hoàng Nam','Phạm Ngọc Mai','Võ Gia Hân','Đỗ Minh Khang','Bùi Khánh Linh','Phan Tuấn Kiệt','Huỳnh Thảo Vy','Đặng Quốc Bảo','Ngô Thanh Hà','Dương Nhật Minh','Lý Thu Trang','Mai Đức Anh','Cao Mỹ Duyên','Trương Gia Bảo','Hồ Ngọc Hân','Vũ Thành Đạt','Đinh Bảo Ngọc','Tạ Minh Quân','Nguyễn Thùy Dương','Trần Quốc Huy','Phạm Hoài An','Lâm Minh Châu'])[c.n]
  WHEN id IN (SELECT id FROM report_partners) THEN
  (ARRAY['Nguyễn Văn Hòa','Trần Minh Đức','Lê Quốc Thắng','Phạm Văn Khôi','Võ Thành Trung','Đỗ Anh Tuấn','Bùi Minh Tâm','Phan Quốc Việt','Huỳnh Văn Phúc','Đặng Minh Long','Ngô Đức Thành','Dương Văn Bình'])[p.n]
  ELSE CASE WHEN email LIKE '%admin%' THEN 'Nguyễn Quản Trị' ELSE 'Trần Hỗ Trợ' END END,
  'vi', created_at, updated_at
FROM users u
LEFT JOIN report_customers c ON c.id=u.id
LEFT JOIN report_partners p ON p.id=u.id
WHERE u.email LIKE 'taskly.report.%@gmail.com';

INSERT INTO user_roles(user_id,role_id,granted_at)
SELECT u.id, r.id, u.created_at FROM users u
JOIN roles r ON r.role_key = CASE WHEN u.email LIKE '%admin%' OR u.email LIKE '%support%' THEN 'SUPER_ADMIN' ELSE 'CUSTOMER' END
WHERE u.email LIKE 'taskly.report.%@gmail.com' ON CONFLICT DO NOTHING;
INSERT INTO user_roles(user_id,role_id,granted_at)
SELECT p.id, r.id, u.created_at FROM report_partners p JOIN users u ON u.id=p.id JOIN roles r ON r.role_key='TASKER'
ON CONFLICT DO NOTHING;
INSERT INTO user_preferences(user_id,notifications_enabled)
SELECT id,true FROM users WHERE email LIKE 'taskly.report.%@gmail.com' ON CONFLICT DO NOTHING;

INSERT INTO addresses(id,user_id,label,recipient_name,recipient_phone,address_line,ward,district,city,latitude,longitude,notes,is_default,building_type,building_description,created_at,updated_at)
SELECT md5('taskly-report-fixture:address:customer:'||c.n)::uuid,c.id,'Căn hộ',p.full_name,u.phone,
       format('Căn hộ C%04s, The Rainbow R%s.%s, Vinhomes Grand Park',100+c.n,1+(c.n%6),1+(c.n%5)),
       CASE WHEN c.n%2=0 THEN 'Long Bình' ELSE 'Long Thạnh Mỹ' END,'Quận 9','Hồ Chí Minh',
       10.8412+c.n/10000.0,106.8281+c.n/10000.0,'Gọi trước khi lên sảnh',true,'Chung cư',
       format('Tòa The Rainbow, tầng %s, căn %s',10+(c.n%20),100+c.n),u.created_at,u.updated_at
FROM report_customers c JOIN users u ON u.id=c.id JOIN user_profiles p ON p.user_id=u.id;
INSERT INTO addresses(id,user_id,label,recipient_name,recipient_phone,address_line,ward,district,city,latitude,longitude,notes,is_default,building_type,building_description,created_at,updated_at)
SELECT md5('taskly-report-fixture:address:partner:'||p.n)::uuid,p.id,'Địa chỉ làm việc',up.full_name,u.phone,
       'Sảnh S'||(1+p.n%4)||', Vinhomes Grand Park',CASE WHEN p.n%2=0 THEN 'Long Bình' ELSE 'Long Thạnh Mỹ' END,'Quận 9','Hồ Chí Minh',
       10.8410+p.n/10000.0,106.8280+p.n/10000.0,'Khu vực hoạt động của Partner',true,'Chung cư','Khu vực Vinhomes Grand Park',u.created_at,u.updated_at
FROM report_partners p JOIN users u ON u.id=p.id JOIN user_profiles up ON up.user_id=u.id;

INSERT INTO recruitment_areas(id,city,name,recruiting,capacity,version,updated_at)
VALUES(md5('taskly-report-fixture:area:grand-park')::uuid,'Hồ Chí Minh','Vinhomes Grand Park - Quận 9',true,100,0,now())
ON CONFLICT(id) DO UPDATE SET city=EXCLUDED.city,name=EXCLUDED.name,recruiting=true,capacity=100,updated_at=now();
INSERT INTO recruitment_area_services(area_id,service_id)
SELECT md5('taskly-report-fixture:area:grand-park')::uuid,id FROM services WHERE active=true AND deleted_at IS NULL
ON CONFLICT DO NOTHING;

INSERT INTO partner_applications(id,user_id,status,full_name,contact_phone,experience,transport,reason,created_at,updated_at)
SELECT md5('taskly-report-fixture:application:'||p.n)::uuid,p.id,
       CASE WHEN p.n<=7 THEN 'ACTIVE' WHEN p.n=8 THEN 'REGISTERED' WHEN p.n=12 THEN 'SUSPENDED' ELSE 'WAITLISTED' END,
       up.full_name,u.phone,'Đã có kinh nghiệm làm dịch vụ trong khu dân cư','Xe máy',
       'Hồ sơ synthetic phục vụ báo cáo vận hành 2 tháng',u.created_at,u.updated_at
FROM report_partners p JOIN users u ON u.id=p.id JOIN user_profiles up ON up.user_id=u.id;
UPDATE partner_applications a SET exam_passed=(p.n<=7),training_complete=(p.n<=7),agreements_current=(p.n<=7),profile_complete=(p.n<=7),preliminary_approved=(p.n<=7),uniform_resolved=(p.n<=7),appointment_checked_in=(p.n<=7),documents_valid=(p.n<=7),final_approved=(p.n<=7),skills_configured=(p.n<=7),areas_configured=(p.n<=7),availability_configured=(p.n<=7),activated_at=CASE WHEN p.n<=7 THEN a.created_at+interval '2 days' END
FROM report_partners p WHERE a.user_id=p.id;
INSERT INTO partner_application_areas(application_id,area_id)
SELECT a.id,md5('taskly-report-fixture:area:grand-park')::uuid FROM partner_applications a JOIN report_partners p ON p.id=a.user_id;
INSERT INTO partner_application_services(application_id,service_id)
SELECT a.id,s.id FROM partner_applications a JOIN report_partners p ON p.id=a.user_id CROSS JOIN LATERAL (SELECT id FROM services WHERE active=true AND deleted_at IS NULL ORDER BY display_order,name LIMIT (3+p.n%3)) s;

INSERT INTO partner_bank_accounts(user_id,bank_name,account_name,account_number,updated_at)
SELECT p.id,'Ngân hàng TMCP Á Châu',upper(up.full_name),'9704'||lpad((100000+p.n)::text,10,'0'),now()
FROM report_partners p JOIN user_profiles up ON up.user_id=p.id WHERE p.n<=7;
INSERT INTO partner_wallets(user_id,balance)
SELECT id,150000+p.n*50000 FROM report_partners WHERE n<=7;

-- Quote and task data: 42 jobs across the two-month launch window.
INSERT INTO customer_price_quotes(id,customer_id,service_id,rule_version,draft_payload,subtotal,platform_fee,total,currency,created_at,expires_at)
SELECT md5('taskly-report-fixture:quote:'||n)::uuid,c.id,s.id,1,
       json_build_object('addressId',md5('taskly-report-fixture:address:customer:'||c.n)::uuid,'serviceId',s.id,'duration',2)::text,
       180000+(n%6)*75000,(180000+(n%6)*7500),198000+(n%6)*82500,'VND',
       now()-interval '60 days'+(2+(n*57/42))*interval '1 day',now()+interval '15 minutes'
FROM generate_series(1,42) n
JOIN report_customers c ON c.n=7+((n-1)%18)
CROSS JOIN LATERAL (SELECT id FROM services WHERE active=true AND deleted_at IS NULL ORDER BY display_order,name OFFSET ((n-1)%GREATEST((SELECT count(*) FROM services WHERE active=true AND deleted_at IS NULL),1)) LIMIT 1) s;

INSERT INTO report_tasks
SELECT md5('taskly-report-fixture:task:'||n)::uuid,n,
       CASE WHEN n<=26 OR n=41 THEN 'PAID' WHEN n IN (27,28,42) THEN 'COMPLETED' WHEN n=29 THEN 'IN_PROGRESS' WHEN n=30 THEN 'ARRIVED' WHEN n=31 THEN 'TASKER_ON_THE_WAY' WHEN n=32 THEN 'ACCEPTED' WHEN n IN (33,34) THEN 'MATCHING' WHEN n=35 THEN 'POSTED' WHEN n=36 THEN 'CANCELLED' WHEN n IN (37,38) THEN 'REFUNDED' WHEN n=39 THEN 'DISPUTED' ELSE 'EXPIRED' END,
       c.id,CASE WHEN n IN (33,34,35,40) THEN NULL ELSE p.id END
FROM generate_series(1,42) n JOIN report_customers c ON c.n=7+((n-1)%18)
LEFT JOIN report_partners p ON p.n=1+((n-1)%7);

INSERT INTO tasks(id,customer_id,tasker_id,service_id,status,service_slug_snapshot,service_name_snapshot,category_slug_snapshot,category_name_snapshot,suggested_price_min_snapshot,suggested_price_max_snapshot,title,description,address_label_snapshot,address_line_snapshot,ward_snapshot,district_snapshot,city_snapshot,recipient_name_snapshot,recipient_phone_snapshot,address_notes_snapshot,latitude,longitude,scheduled_at,estimated_duration_minutes,budget_amount,currency,customer_notes,expires_at,created_at,updated_at,platform_fee_snapshot,building_type_snapshot,building_description_snapshot)
SELECT rt.id,rt.customer_id,rt.partner_id, q.service_id,rt.status,s.slug,s.name,cat.slug,cat.name,s.suggested_price_min,s.suggested_price_max,
       'Dịch vụ tại Vinhomes Grand Park','Mô phỏng booking của cư dân trong tháng đầu và tháng thứ hai','Căn hộ',a.address_line,a.ward,a.district,a.city,a.recipient_name,a.recipient_phone,a.notes,a.latitude,a.longitude,
       CASE WHEN rt.status IN ('POSTED','MATCHING') THEN now()+interval '2 days' ELSE q.created_at+interval '1 day' END,120,q.total,q.currency,'Dữ liệu synthetic cho báo cáo',q.created_at+interval '2 hours',q.created_at,q.created_at,q.platform_fee,'Chung cư',a.building_description
FROM report_tasks rt JOIN customer_price_quotes q ON q.id=md5('taskly-report-fixture:quote:'||rt.n)::uuid
JOIN services s ON s.id=q.service_id JOIN service_categories cat ON cat.id=s.category_id
JOIN addresses a ON a.user_id=rt.customer_id AND a.is_default=true;

INSERT INTO task_booking_payments(task_id,quote_id,method,status,amount,draft_payload,posted_at,match_deadline,cancel_after,balance_amount)
SELECT rt.id,q.id,CASE WHEN rt.n%2=0 THEN 'BANK' ELSE 'CASH' END,
       CASE WHEN rt.status='REFUNDED' THEN 'REFUNDED' WHEN rt.status IN ('PAID','COMPLETED') THEN 'PAID' ELSE 'AWAITING_CASH' END,
       q.total,q.draft_payload,q.created_at,q.created_at+interval '2 hours',q.created_at+interval '2 hours',0
FROM report_tasks rt JOIN customer_price_quotes q ON q.id=md5('taskly-report-fixture:quote:'||rt.n)::uuid;
INSERT INTO task_booking_services(task_id,service_id)
SELECT rt.id,q.service_id FROM report_tasks rt JOIN customer_price_quotes q ON q.id=md5('taskly-report-fixture:quote:'||rt.n)::uuid;

INSERT INTO task_status_history(id,task_id,from_status,to_status,actor_id,actor_role,reason,occurred_at)
SELECT md5('taskly-report-fixture:history:'||rt.n||':posted')::uuid,rt.id,NULL,'POSTED',rt.customer_id,'CUSTOMER','Customer tạo booking tại Vinhomes Grand Park',t.created_at
FROM report_tasks rt JOIN tasks t ON t.id=rt.id;
INSERT INTO task_status_history(id,task_id,from_status,to_status,actor_id,actor_role,reason,occurred_at)
SELECT md5('taskly-report-fixture:history:'||rt.n||':final')::uuid,rt.id,'POSTED',rt.status,coalesce(rt.partner_id,rt.customer_id),CASE WHEN rt.partner_id IS NULL THEN 'CUSTOMER' ELSE 'TASKER' END,'Cập nhật trạng thái theo luồng vận hành mô phỏng',t.created_at+interval '1 hour'
FROM report_tasks rt JOIN tasks t ON t.id=rt.id WHERE rt.status<>'POSTED';

INSERT INTO customer_reviews(task_id,customer_id,stars,comment,created_at)
SELECT rt.id,rt.customer_id,4+(rt.n%2),CASE WHEN rt.n%2=0 THEN 'Partner đến đúng giờ, làm việc gọn gàng.' ELSE 'Dịch vụ phù hợp với nhu cầu căn hộ.' END,t.created_at+interval '2 days'
FROM report_tasks rt JOIN tasks t ON t.id=rt.id WHERE rt.status IN ('PAID','COMPLETED') AND rt.n<=28;
INSERT INTO partner_task_settlements(task_id,partner_id,method,wallet_delta,created_at)
SELECT rt.id,rt.partner_id,'WALLET',t.budget_amount-t.platform_fee_snapshot,t.created_at+interval '2 days'
FROM report_tasks rt JOIN tasks t ON t.id=rt.id WHERE rt.status='PAID';
INSERT INTO partner_wallet_transactions(id,user_id,type,amount,status,bank_name,account_name,account_number,reference_code,note,created_at,completed_at,updated_by,user_role)
SELECT md5('taskly-report-fixture:wallet:'||p.n)::uuid,p.id,'DEPOSIT',100000+p.n*50000,'COMPLETED','Ngân hàng TMCP Á Châu',up.full_name,'9704'||lpad((100000+p.n)::text,10,'0'),'REPORT-WALLET-'||p.n,'Nạp ví mô phỏng tháng đầu',now()-interval '35 days',now()-interval '35 days'+interval '1 hour',md5('taskly-report-fixture:admin:1')::uuid,'PARTNER'
FROM report_partners p JOIN user_profiles up ON up.user_id=p.id WHERE p.n<=7;

INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at)
SELECT md5('taskly-report-fixture:notification:'||rt.n)::uuid,rt.customer_id,rt.id,'Cập nhật đơn tại Vinhomes Grand Park: '||rt.status,t.created_at
FROM report_tasks rt JOIN tasks t ON t.id=rt.id;
INSERT INTO customer_support_messages(id,user_id,sender,content,created_at,task_id)
SELECT md5('taskly-report-fixture:support:user:'||n)::uuid,c.id,'USER','Mình muốn kiểm tra tiến độ đơn tại Vinhomes Grand Park.',now()-interval '12 days',t.id
FROM generate_series(1,4) n JOIN report_customers c ON c.n=6+n JOIN tasks t ON t.id=md5('taskly-report-fixture:task:'||(35+n))::uuid;
INSERT INTO customer_support_messages(id,user_id,sender,content,created_at,task_id)
SELECT md5('taskly-report-fixture:support:staff:'||n)::uuid,c.id,'STAFF','Bộ phận hỗ trợ đã tiếp nhận và đang kiểm tra với Partner.',now()-interval '12 days'+interval '30 minutes',t.id
FROM generate_series(1,4) n JOIN report_customers c ON c.n=6+n JOIN tasks t ON t.id=md5('taskly-report-fixture:task:'||(35+n))::uuid;

UPDATE live_sync_revision SET revision=revision+1 WHERE id=1;

SELECT 'report fixture ready' AS result,
       (SELECT count(*) FROM report_customers) AS customers,
       (SELECT count(*) FROM report_partners) AS partners,
       (SELECT count(*) FROM report_tasks) AS tasks,
       (SELECT count(*) FROM customer_reviews WHERE customer_id IN (SELECT id FROM report_fixture_users)) AS reviews;
