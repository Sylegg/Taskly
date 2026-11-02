ALTER TABLE partner_applications ADD COLUMN first_submitted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE partner_applications ADD COLUMN editable_until TIMESTAMP WITH TIME ZONE;

-- Preserve the original submission time for existing applications.
UPDATE partner_applications SET first_submitted_at = (
 SELECT MIN(created_at) FROM recruitment_audit
 WHERE application_id = partner_applications.id AND action = 'PROFILE_SUBMITTED'
);
UPDATE partner_applications SET editable_until = first_submitted_at + INTERVAL '12' HOUR
WHERE first_submitted_at IS NOT NULL;
