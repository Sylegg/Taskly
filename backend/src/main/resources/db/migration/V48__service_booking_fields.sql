CREATE TABLE service_booking_fields (
 service_id UUID PRIMARY KEY REFERENCES services(id),
 fields TEXT NOT NULL DEFAULT '[]',
 version INTEGER NOT NULL DEFAULT 1
);
