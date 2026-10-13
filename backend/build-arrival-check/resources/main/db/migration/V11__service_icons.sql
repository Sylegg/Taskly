ALTER TABLE services ADD COLUMN icon_key VARCHAR(40);
ALTER TABLE services ADD COLUMN icon_image BYTEA;
ALTER TABLE services ADD COLUMN icon_image_hash VARCHAR(64);

ALTER TABLE services ADD CONSTRAINT ck_services_icon_image_hash
    CHECK ((icon_image IS NULL AND icon_image_hash IS NULL)
        OR (icon_image IS NOT NULL AND icon_image_hash IS NOT NULL));
