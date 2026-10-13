CREATE TABLE tasks (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL REFERENCES users(id),
    service_id UUID NOT NULL REFERENCES services(id),
    status VARCHAR(32) NOT NULL,
    service_slug_snapshot VARCHAR(100) NOT NULL,
    service_name_snapshot VARCHAR(160) NOT NULL,
    category_slug_snapshot VARCHAR(80) NOT NULL,
    category_name_snapshot VARCHAR(160) NOT NULL,
    suggested_price_min_snapshot BIGINT NOT NULL CHECK (suggested_price_min_snapshot >= 0),
    suggested_price_max_snapshot BIGINT NOT NULL CHECK (suggested_price_max_snapshot >= suggested_price_min_snapshot),
    title VARCHAR(160) NOT NULL,
    description VARCHAR(4000) NOT NULL,
    address_label_snapshot VARCHAR(100),
    address_line_snapshot VARCHAR(500) NOT NULL,
    ward_snapshot VARCHAR(160),
    district_snapshot VARCHAR(160),
    city_snapshot VARCHAR(160) NOT NULL,
    recipient_name_snapshot VARCHAR(160),
    recipient_phone_snapshot VARCHAR(32),
    address_notes_snapshot VARCHAR(1000),
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
    estimated_duration_minutes INTEGER NOT NULL CHECK (estimated_duration_minutes BETWEEN 15 AND 1440),
    budget_amount BIGINT NOT NULL CHECK (budget_amount > 0),
    currency VARCHAR(3) NOT NULL,
    customer_notes VARCHAR(2000),
    expires_at TIMESTAMP WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT chk_task_status CHECK (status IN ('DRAFT','POSTED','MATCHING','ACCEPTED','TASKER_ON_THE_WAY','ARRIVED','IN_PROGRESS','COMPLETED','PAID','CANCELLED','DISPUTED','REFUNDED','EXPIRED')),
    CONSTRAINT chk_task_coordinates CHECK ((latitude IS NULL AND longitude IS NULL) OR (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180))
);
CREATE INDEX idx_tasks_customer_created ON tasks (customer_id, created_at DESC);
CREATE INDEX idx_tasks_status_schedule ON tasks (status, scheduled_at);

CREATE TABLE task_images (
    id UUID PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES tasks(id),
    stored_object_id UUID NOT NULL REFERENCES stored_objects(id),
    image_type VARCHAR(32) NOT NULL DEFAULT 'TASK',
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_task_image_object UNIQUE (stored_object_id)
);
CREATE INDEX idx_task_images_task ON task_images (task_id, display_order);

CREATE TABLE task_status_history (
    id UUID PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES tasks(id),
    from_status VARCHAR(32),
    to_status VARCHAR(32) NOT NULL,
    actor_id UUID REFERENCES users(id),
    actor_role VARCHAR(40) NOT NULL,
    reason VARCHAR(1000),
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    accuracy_meters NUMERIC(10,2),
    metadata TEXT,
    correlation_id VARCHAR(80),
    idempotency_key VARCHAR(160),
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_task_history_idempotency UNIQUE (task_id, idempotency_key)
);
CREATE INDEX idx_task_status_history_task ON task_status_history (task_id, occurred_at);
