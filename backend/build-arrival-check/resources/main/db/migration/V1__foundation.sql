CREATE TABLE system_configs (
    id UUID PRIMARY KEY,
    config_key VARCHAR(120) NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    value_type VARCHAR(32) NOT NULL,
    sensitive BOOLEAN NOT NULL DEFAULT FALSE,
    description VARCHAR(500),
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_by UUID,
    updated_by UUID
);

CREATE TABLE feature_flags (
    id UUID PRIMARY KEY,
    flag_key VARCHAR(120) NOT NULL UNIQUE,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    description VARCHAR(500),
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_by UUID
);

CREATE TABLE idempotency_records (
    id UUID PRIMARY KEY,
    scope VARCHAR(80) NOT NULL,
    idempotency_key VARCHAR(160) NOT NULL,
    request_hash VARCHAR(128) NOT NULL,
    resource_type VARCHAR(80),
    resource_id UUID,
    response_status INTEGER,
    response_body TEXT,
    processing_status VARCHAR(32) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uq_idempotency_scope_key UNIQUE (scope, idempotency_key)
);

CREATE INDEX idx_idempotency_expiry ON idempotency_records (expires_at);

CREATE TABLE outbox_events (
    id UUID PRIMARY KEY,
    aggregate_type VARCHAR(80) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    payload TEXT NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    processing_status VARCHAR(32) NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    next_attempt_at TIMESTAMP WITH TIME ZONE,
    processed_at TIMESTAMP WITH TIME ZONE,
    last_error VARCHAR(2000),
    correlation_id VARCHAR(80)
);

CREATE INDEX idx_outbox_dispatch ON outbox_events (processing_status, next_attempt_at, occurred_at);

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY,
    actor_id UUID,
    actor_type VARCHAR(40) NOT NULL,
    action VARCHAR(120) NOT NULL,
    entity_type VARCHAR(80),
    entity_id UUID,
    old_value_summary TEXT,
    new_value_summary TEXT,
    ip_address VARCHAR(64),
    user_agent VARCHAR(500),
    correlation_id VARCHAR(80),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX idx_audit_entity ON audit_logs (entity_type, entity_id, created_at);
CREATE INDEX idx_audit_actor ON audit_logs (actor_id, created_at);

INSERT INTO feature_flags (id, flag_key, enabled, description, created_at, updated_at)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'CHAT_ENABLED', TRUE, 'Enable assignment chat', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000002', 'AI_TASK_DRAFT_ENABLED', FALSE, 'Enable AI task draft adapter', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000003', 'AI_PRICE_ENABLED', FALSE, 'Enable AI price suggestions', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000004', 'AI_MATCHING_ENABLED', FALSE, 'Enable AI matching recommendations', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000005', 'PAYMENT_ENABLED', FALSE, 'Enable payment intent creation', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000006', 'AUTO_RELEASE_ENABLED', FALSE, 'Enable configured completion auto release', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000007', 'WEB_PUSH_ENABLED', FALSE, 'Enable web push notifications', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000008', 'MAKER_CHECKER_ENABLED', FALSE, 'Require second approver for configured finance actions', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('00000000-0000-0000-0000-000000000009', 'NEW_TASK_CREATION_ENABLED', TRUE, 'Allow Customers to create tasks', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
