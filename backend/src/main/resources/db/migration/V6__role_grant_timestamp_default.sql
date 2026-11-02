-- Hibernate's user_roles join mapping inserts only user_id and role_id.
-- Let the database timestamp every new grant without rewriting historical migrations.
ALTER TABLE user_roles ALTER COLUMN granted_at SET DEFAULT CURRENT_TIMESTAMP;
