ALTER TABLE users ADD COLUMN used_customer BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN used_partner BOOLEAN NOT NULL DEFAULT FALSE;
UPDATE users SET used_customer = TRUE WHERE EXISTS (
    SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = users.id AND r.role_key = 'CUSTOMER'
);
UPDATE users SET used_partner = TRUE WHERE EXISTS (
    SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = users.id AND r.role_key = 'TASKER'
);
