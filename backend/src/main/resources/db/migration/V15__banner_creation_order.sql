ALTER TABLE home_banners ADD COLUMN insertion_order BIGINT GENERATED ALWAYS AS IDENTITY;
CREATE INDEX home_banners_creation_order ON home_banners(created_at,insertion_order);
