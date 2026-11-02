CREATE TABLE category_quantity_fields (
 category_id UUID PRIMARY KEY REFERENCES service_categories(id),
 fields TEXT NOT NULL DEFAULT '[]',
 version INTEGER NOT NULL DEFAULT 1,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
