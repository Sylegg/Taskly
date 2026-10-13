CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(320) NOT NULL UNIQUE,
    phone VARCHAR(32) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    status VARCHAR(40) NOT NULL,
    active_mode VARCHAR(24) NOT NULL DEFAULT 'CUSTOMER',
    email_verified_at TIMESTAMP WITH TIME ZONE,
    phone_verified_at TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0 CHECK (failed_login_attempts >= 0),
    locked_until TIMESTAMP WITH TIME ZONE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX idx_users_status ON users (status);
CREATE INDEX idx_users_created_at ON users (created_at);

CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    full_name VARCHAR(160) NOT NULL,
    avatar_object_key VARCHAR(500),
    date_of_birth DATE,
    bio VARCHAR(1000),
    language VARCHAR(12) NOT NULL DEFAULT 'vi',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE roles (
    id UUID PRIMARY KEY,
    role_key VARCHAR(80) NOT NULL UNIQUE,
    description VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE permissions (
    id UUID PRIMARY KEY,
    permission_key VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id),
    role_id UUID NOT NULL REFERENCES roles(id),
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL,
    granted_by UUID,
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id),
    permission_id UUID NOT NULL REFERENCES permissions(id),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    family_id UUID NOT NULL,
    parent_id UUID,
    device_name VARCHAR(200),
    user_agent VARCHAR(500),
    ip_address VARCHAR(64),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_used_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE,
    replaced_by UUID
);

CREATE INDEX idx_refresh_user_active ON refresh_tokens (user_id, revoked_at, expires_at);
CREATE INDEX idx_refresh_family ON refresh_tokens (family_id);

CREATE TABLE addresses (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    label VARCHAR(100) NOT NULL,
    recipient_name VARCHAR(160),
    recipient_phone VARCHAR(32),
    address_line VARCHAR(500) NOT NULL,
    ward VARCHAR(160),
    district VARCHAR(160),
    city VARCHAR(160) NOT NULL,
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7),
    notes VARCHAR(500),
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT chk_address_latitude CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90)),
    CONSTRAINT chk_address_longitude CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180))
);

CREATE INDEX idx_addresses_user ON addresses (user_id, deleted_at);

CREATE TABLE terms_versions (
    id UUID PRIMARY KEY,
    document_type VARCHAR(40) NOT NULL,
    version VARCHAR(40) NOT NULL,
    content_url VARCHAR(500) NOT NULL,
    effective_at TIMESTAMP WITH TIME ZONE NOT NULL,
    requires_reacceptance BOOLEAN NOT NULL DEFAULT FALSE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_terms_type_version UNIQUE (document_type, version)
);

CREATE TABLE user_consents (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    terms_version_id UUID NOT NULL REFERENCES terms_versions(id),
    accepted_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ip_address VARCHAR(64),
    user_agent VARCHAR(500),
    CONSTRAINT uq_user_terms_consent UNIQUE (user_id, terms_version_id)
);

CREATE TABLE account_deletion_requests (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(40) NOT NULL,
    reason VARCHAR(1000),
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL,
    grace_ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    processed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_deletion_due ON account_deletion_requests (status, grace_ends_at);

INSERT INTO roles (id, role_key, description, created_at) VALUES
('10000000-0000-0000-0000-000000000001', 'CUSTOMER', 'Customer marketplace mode', CURRENT_TIMESTAMP),
('10000000-0000-0000-0000-000000000002', 'TASKER', 'Tasker marketplace mode', CURRENT_TIMESTAMP),
('10000000-0000-0000-0000-000000000003', 'SUPER_ADMIN', 'All administrative permissions', CURRENT_TIMESTAMP),
('10000000-0000-0000-0000-000000000004', 'KYC_ADMIN', 'KYC review permissions', CURRENT_TIMESTAMP),
('10000000-0000-0000-0000-000000000005', 'SUPPORT_ADMIN', 'Support and complaint permissions', CURRENT_TIMESTAMP),
('10000000-0000-0000-0000-000000000006', 'FINANCE_ADMIN', 'Finance permissions', CURRENT_TIMESTAMP),
('10000000-0000-0000-0000-000000000007', 'CONTENT_ADMIN', 'Catalogue and notification content permissions', CURRENT_TIMESTAMP);

INSERT INTO permissions (id, permission_key, description, created_at) VALUES
('20000000-0000-0000-0000-000000000001', 'USER_MANAGE', 'Manage users and account restrictions', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000002', 'KYC_REVIEW', 'Review identity verification cases', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000003', 'TASK_MANAGE', 'Inspect and administratively act on tasks', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000004', 'SERVICE_MANAGE', 'Manage service catalogue', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000005', 'PAYMENT_VIEW', 'View payments and reconciliation', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000006', 'PAYMENT_MANAGE', 'Manage payment operations', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000007', 'REFUND_APPROVE', 'Approve refunds', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000008', 'COMPLAINT_REVIEW', 'Review complaints and disputes', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000009', 'CONFIG_MANAGE', 'Manage system and financial configuration', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000010', 'NOTIFICATION_MANAGE', 'Manage system notifications', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000011', 'AUDIT_VIEW', 'View audit logs', CURRENT_TIMESTAMP),
('20000000-0000-0000-0000-000000000012', 'AI_LOG_VIEW', 'View redacted AI logs', CURRENT_TIMESTAMP);

INSERT INTO role_permissions (role_id, permission_id)
SELECT '10000000-0000-0000-0000-000000000003', id FROM permissions;

INSERT INTO role_permissions (role_id, permission_id) VALUES
('10000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000002'),
('10000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000001'),
('10000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000003'),
('10000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000008'),
('10000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000005'),
('10000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000006'),
('10000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000007'),
('10000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000004'),
('10000000-0000-0000-0000-000000000007', '20000000-0000-0000-0000-000000000010');
