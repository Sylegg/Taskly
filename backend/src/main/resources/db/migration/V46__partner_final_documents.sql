CREATE TABLE partner_final_documents (
 application_id UUID PRIMARY KEY REFERENCES partner_applications(id),
 portrait TEXT NOT NULL,contract TEXT NOT NULL,submitted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
