CREATE TABLE partner_office_slots (
 id UUID PRIMARY KEY,name VARCHAR(160) NOT NULL,address VARCHAR(500) NOT NULL,
 starts_at TIMESTAMP WITH TIME ZONE NOT NULL,capacity INTEGER NOT NULL CHECK(capacity BETWEEN 1 AND 1000),
 active BOOLEAN NOT NULL,version BIGINT NOT NULL DEFAULT 0
);
CREATE TABLE partner_office_appointments (
 id UUID PRIMARY KEY,application_id UUID NOT NULL REFERENCES partner_applications(id),
 slot_id UUID NOT NULL REFERENCES partner_office_slots(id),status VARCHAR(20) NOT NULL,
 checkin_code VARCHAR(20) NOT NULL UNIQUE,request_key VARCHAR(100) NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL,checked_in_at TIMESTAMP WITH TIME ZONE,
 UNIQUE(application_id,request_key)
);
CREATE TABLE partner_document_checklist (
 id UUID PRIMARY KEY,label VARCHAR(200) NOT NULL,required BOOLEAN NOT NULL,active BOOLEAN NOT NULL
);
CREATE TABLE partner_document_receipts (
 id UUID PRIMARY KEY,application_id UUID NOT NULL REFERENCES partner_applications(id),
 appointment_id UUID NOT NULL REFERENCES partner_office_appointments(id),receptionist_id UUID NOT NULL REFERENCES users(id),
 originals_returned BOOLEAN NOT NULL,complete BOOLEAN NOT NULL,notes VARCHAR(1000) NOT NULL,
 checklist VARCHAR(5000) NOT NULL,received_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE partner_appeals (
 id UUID PRIMARY KEY,application_id UUID NOT NULL REFERENCES partner_applications(id),
 reason VARCHAR(1000) NOT NULL,status VARCHAR(20) NOT NULL,created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE partner_availability (
 application_id UUID PRIMARY KEY REFERENCES partner_applications(id),
 starts_at TIMESTAMP WITH TIME ZONE NOT NULL,ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
 CHECK(ends_at>starts_at)
);
