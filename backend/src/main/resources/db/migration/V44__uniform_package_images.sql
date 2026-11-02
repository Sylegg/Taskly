ALTER TABLE partner_uniform_packages ADD COLUMN image_url TEXT;
ALTER TABLE partner_uniform_packages ADD COLUMN items TEXT NOT NULL DEFAULT '[]';
