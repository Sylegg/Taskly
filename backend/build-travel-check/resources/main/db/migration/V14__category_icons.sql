ALTER TABLE service_categories ADD COLUMN icon_key VARCHAR(40);
ALTER TABLE service_categories ADD COLUMN icon_image BYTEA;
ALTER TABLE service_categories ADD COLUMN icon_image_hash VARCHAR(64);
UPDATE service_categories SET icon_key=CASE slug WHEN 'cleaning' THEN 'cleaning' WHEN 'upholstery' THEN 'sofa' WHEN 'air-conditioning' THEN 'aircon' WHEN 'appliance-repair' THEN 'repair' WHEN 'furniture' THEN 'assembly' WHEN 'moving' THEN 'moving' WHEN 'shopping' THEN 'shopping' WHEN 'pet-care' THEN 'pets' WHEN 'it-support' THEN 'computer' WHEN 'laundry' THEN 'laundry' ELSE 'grid' END;
