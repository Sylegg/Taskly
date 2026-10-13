CREATE TABLE service_categories (
    id UUID PRIMARY KEY,
    slug VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(160) NOT NULL,
    description VARCHAR(1000),
    active BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_service_categories_public
    ON service_categories (active, display_order, name);

CREATE TABLE services (
    id UUID PRIMARY KEY,
    category_id UUID NOT NULL REFERENCES service_categories(id),
    slug VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(160) NOT NULL,
    short_description VARCHAR(500) NOT NULL,
    description VARCHAR(4000),
    suggested_price_min BIGINT NOT NULL CHECK (suggested_price_min >= 0),
    suggested_price_max BIGINT NOT NULL CHECK (suggested_price_max >= suggested_price_min),
    currency VARCHAR(3) NOT NULL,
    estimated_duration_minutes INTEGER CHECK (estimated_duration_minutes IS NULL OR estimated_duration_minutes BETWEEN 15 AND 1440),
    active BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_services_public
    ON services (category_id, active, display_order, name);
CREATE INDEX idx_services_admin
    ON services (deleted_at, category_id, display_order);
