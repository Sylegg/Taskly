-- Additive only: existing users/auth/tasker profiles remain authoritative.
CREATE TABLE recruitment_areas (
 id UUID PRIMARY KEY, city VARCHAR(160) NOT NULL, name VARCHAR(160) NOT NULL,
 recruiting BOOLEAN NOT NULL DEFAULT FALSE, capacity INTEGER NOT NULL CHECK(capacity >= 0),
 version BIGINT NOT NULL DEFAULT 0, updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE recruitment_area_services (
 area_id UUID NOT NULL REFERENCES recruitment_areas(id), service_id UUID NOT NULL REFERENCES services(id),
 PRIMARY KEY(area_id, service_id)
);
CREATE TABLE partner_applications (
 id UUID PRIMARY KEY, user_id UUID NOT NULL UNIQUE REFERENCES users(id),
 status VARCHAR(40) NOT NULL DEFAULT 'REGISTERED', full_name VARCHAR(160) NOT NULL DEFAULT '',
 contact_phone VARCHAR(32), date_of_birth DATE, experience VARCHAR(1000) NOT NULL DEFAULT '',
 transport VARCHAR(40) NOT NULL DEFAULT '', referral VARCHAR(100) NOT NULL DEFAULT '',
 reason VARCHAR(1000) NOT NULL DEFAULT '', required_changes VARCHAR(2000) NOT NULL DEFAULT '[]',
 exam_passed BOOLEAN NOT NULL DEFAULT FALSE, training_complete BOOLEAN NOT NULL DEFAULT FALSE,
 agreements_current BOOLEAN NOT NULL DEFAULT FALSE, profile_complete BOOLEAN NOT NULL DEFAULT FALSE,
 preliminary_approved BOOLEAN NOT NULL DEFAULT FALSE, uniform_resolved BOOLEAN NOT NULL DEFAULT FALSE,
 appointment_checked_in BOOLEAN NOT NULL DEFAULT FALSE, documents_valid BOOLEAN NOT NULL DEFAULT FALSE,
 final_approved BOOLEAN NOT NULL DEFAULT FALSE, skills_configured BOOLEAN NOT NULL DEFAULT FALSE,
 areas_configured BOOLEAN NOT NULL DEFAULT FALSE, availability_configured BOOLEAN NOT NULL DEFAULT FALSE,
 documents_received_at TIMESTAMP WITH TIME ZONE, activated_at TIMESTAMP WITH TIME ZONE,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL, updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
 version BIGINT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX uq_recruitment_phone ON partner_applications(contact_phone);
CREATE TABLE partner_application_areas (
 application_id UUID NOT NULL REFERENCES partner_applications(id), area_id UUID NOT NULL REFERENCES recruitment_areas(id),
 PRIMARY KEY(application_id,area_id)
);
CREATE TABLE partner_application_services (
 application_id UUID NOT NULL REFERENCES partner_applications(id), service_id UUID NOT NULL REFERENCES services(id),
 PRIMARY KEY(application_id,service_id)
);
CREATE TABLE recruitment_audit (
 id UUID PRIMARY KEY, actor_id UUID NOT NULL REFERENCES users(id), application_id UUID REFERENCES partner_applications(id),
 action VARCHAR(80) NOT NULL, before_status VARCHAR(40), after_status VARCHAR(40),
 reason VARCHAR(1000) NOT NULL DEFAULT '', created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE recruitment_requests (
 actor_id UUID NOT NULL REFERENCES users(id), request_key VARCHAR(100) NOT NULL,
 payload_hash VARCHAR(64) NOT NULL, application_id UUID NOT NULL REFERENCES partner_applications(id),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL, PRIMARY KEY(actor_id,request_key)
);
CREATE TABLE recruitment_policy (
 id INTEGER PRIMARY KEY CHECK(id=1), minimum_age INTEGER NOT NULL CHECK(minimum_age >= 18),
 exam_minutes INTEGER NOT NULL CHECK(exam_minutes BETWEEN 1 AND 120),
 pass_mark INTEGER NOT NULL CHECK(pass_mark BETWEEN 1 AND 20),
 attempts_per_day INTEGER NOT NULL CHECK(attempts_per_day BETWEEN 1 AND 10),
 sla_min_hours INTEGER NOT NULL CHECK(sla_min_hours > 0), sla_max_hours INTEGER NOT NULL,
 version BIGINT NOT NULL DEFAULT 0, CHECK(sla_max_hours >= sla_min_hours)
);
INSERT INTO recruitment_policy VALUES(1,18,25,16,2,24,48,0);
INSERT INTO permissions(id,permission_key,description,created_at) VALUES
 ('20000000-0000-0000-0000-000000000020','RECRUITMENT_VIEW','Read recruitment metadata',CURRENT_TIMESTAMP),
 ('20000000-0000-0000-0000-000000000021','RECRUITMENT_CONFIG','Configure recruitment areas/policy',CURRENT_TIMESTAMP),
 ('20000000-0000-0000-0000-000000000022','RECRUITMENT_TRAINING','Manage exam and Academy',CURRENT_TIMESTAMP),
 ('20000000-0000-0000-0000-000000000023','RECRUITMENT_PRELIMINARY','Review preliminary eligibility',CURRENT_TIMESTAMP),
 ('20000000-0000-0000-0000-000000000024','RECRUITMENT_RECEPTION','Receive physical documents',CURRENT_TIMESTAMP),
 ('20000000-0000-0000-0000-000000000025','RECRUITMENT_FINANCE','Manage uniform payment',CURRENT_TIMESTAMP),
 ('20000000-0000-0000-0000-000000000026','RECRUITMENT_FINAL','Final review and suspend',CURRENT_TIMESTAMP);
INSERT INTO role_permissions(role_id,permission_id)
 SELECT r.id,p.id FROM roles r CROSS JOIN permissions p
 WHERE r.role_key='SUPER_ADMIN' AND p.permission_key LIKE 'RECRUITMENT_%';
