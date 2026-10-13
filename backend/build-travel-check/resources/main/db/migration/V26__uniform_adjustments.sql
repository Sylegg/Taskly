CREATE TABLE partner_uniform_adjustments (
 id UUID PRIMARY KEY,order_id UUID NOT NULL REFERENCES partner_uniform_orders(id),
 actor_id UUID NOT NULL REFERENCES users(id),action VARCHAR(20) NOT NULL,
 reason VARCHAR(1000) NOT NULL,request_key VARCHAR(100) NOT NULL,payload_hash VARCHAR(64) NOT NULL,
 from_size VARCHAR(10) NOT NULL,to_size VARCHAR(10),amount BIGINT NOT NULL CHECK(amount>=0),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL,UNIQUE(actor_id,request_key)
);
