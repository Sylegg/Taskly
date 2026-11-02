CREATE TABLE partner_uniform_packages (
 id UUID PRIMARY KEY,name VARCHAR(160) NOT NULL,description VARCHAR(2000) NOT NULL,
 price BIGINT NOT NULL CHECK(price>=0),policy VARCHAR(2000) NOT NULL,active BOOLEAN NOT NULL,
 version BIGINT NOT NULL DEFAULT 0
);
CREATE TABLE partner_uniform_inventory (
 package_id UUID NOT NULL REFERENCES partner_uniform_packages(id),size VARCHAR(10) NOT NULL,
 stock INTEGER NOT NULL CHECK(stock>=0),PRIMARY KEY(package_id,size)
);
CREATE TABLE partner_uniform_orders (
 id UUID PRIMARY KEY,application_id UUID NOT NULL REFERENCES partner_applications(id),
 package_id UUID NOT NULL REFERENCES partner_uniform_packages(id),package_version BIGINT NOT NULL,
 size VARCHAR(10) NOT NULL,price BIGINT NOT NULL CHECK(price>=0),payment_method VARCHAR(20) NOT NULL,
 payment_status VARCHAR(20) NOT NULL,status VARCHAR(20) NOT NULL,request_key VARCHAR(100) NOT NULL,
 receipt_id UUID,created_at TIMESTAMP WITH TIME ZONE NOT NULL,handed_over_at TIMESTAMP WITH TIME ZONE,
 UNIQUE(application_id,request_key)
);
