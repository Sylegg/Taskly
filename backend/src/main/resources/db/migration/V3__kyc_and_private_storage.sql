CREATE TABLE tasker_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    kyc_status VARCHAR(40) NOT NULL DEFAULT 'NOT_STARTED',
    available BOOLEAN NOT NULL DEFAULT FALSE,
    service_radius_km INTEGER NOT NULL DEFAULT 10 CHECK (service_radius_km BETWEEN 1 AND 100),
    approved_at TIMESTAMP WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE stored_objects (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users(id),
    purpose VARCHAR(60) NOT NULL,
    bucket_name VARCHAR(120) NOT NULL,
    object_key VARCHAR(500) NOT NULL UNIQUE,
    original_filename VARCHAR(255),
    content_type VARCHAR(120) NOT NULL,
    size_bytes BIGINT NOT NULL CHECK (size_bytes > 0),
    sha256 VARCHAR(64) NOT NULL,
    scan_status VARCHAR(32) NOT NULL,
    private_object BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_stored_objects_owner ON stored_objects (owner_id, purpose, created_at);

CREATE TABLE identity_verifications (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(40) NOT NULL,
    legal_name VARCHAR(160),
    document_type VARCHAR(40),
    document_number_masked VARCHAR(80),
    consent_accepted_at TIMESTAMP WITH TIME ZONE,
    submitted_at TIMESTAMP WITH TIME ZONE,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewed_by UUID REFERENCES users(id),
    decision_reason VARCHAR(1000),
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX idx_verification_user ON identity_verifications (user_id, created_at);
CREATE INDEX idx_verification_queue ON identity_verifications (status, submitted_at);

CREATE TABLE verification_documents (
    id UUID PRIMARY KEY,
    verification_id UUID NOT NULL REFERENCES identity_verifications(id),
    stored_object_id UUID NOT NULL REFERENCES stored_objects(id),
    document_side VARCHAR(40) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_verification_document_side UNIQUE (verification_id, document_side)
);

CREATE TABLE verification_history (
    id UUID PRIMARY KEY,
    verification_id UUID NOT NULL REFERENCES identity_verifications(id),
    from_status VARCHAR(40),
    to_status VARCHAR(40) NOT NULL,
    actor_id UUID NOT NULL REFERENCES users(id),
    reason VARCHAR(1000),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX idx_verification_history ON verification_history (verification_id, created_at);
