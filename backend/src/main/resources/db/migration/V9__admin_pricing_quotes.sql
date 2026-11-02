CREATE TABLE service_pricing_rules (
    service_id UUID PRIMARY KEY REFERENCES services(id),
    mode VARCHAR(16) NOT NULL CHECK (mode IN ('FIXED', 'HOURLY', 'FIELD')),
    quantity_field VARCHAR(80),
    base_amount BIGINT NOT NULL CHECK (base_amount >= 0),
    unit_amount BIGINT NOT NULL CHECK (unit_amount >= 0),
    platform_fee_amount BIGINT NOT NULL CHECK (platform_fee_amount >= 0),
    quote_ttl_minutes INTEGER NOT NULL CHECK (quote_ttl_minutes BETWEEN 1 AND 60),
    enabled BOOLEAN NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    updated_by UUID NOT NULL REFERENCES users(id),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE customer_price_quotes (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL REFERENCES users(id),
    service_id UUID NOT NULL REFERENCES services(id),
    rule_version BIGINT NOT NULL,
    draft_payload TEXT NOT NULL,
    subtotal BIGINT NOT NULL CHECK (subtotal >= 0),
    platform_fee BIGINT NOT NULL CHECK (platform_fee >= 0),
    total BIGINT NOT NULL CHECK (total > 0),
    currency VARCHAR(3) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX idx_customer_quotes_owner ON customer_price_quotes(customer_id, created_at DESC);
