CREATE TABLE partner_sla_calendar (
 id INTEGER PRIMARY KEY CHECK(id=1),
 timezone VARCHAR(100) NOT NULL,
 start_hour INTEGER NOT NULL CHECK(start_hour BETWEEN 0 AND 23),
 end_hour INTEGER NOT NULL CHECK(end_hour BETWEEN 1 AND 24),
 holidays VARCHAR(8000) NOT NULL,
 version BIGINT NOT NULL DEFAULT 0,
 CHECK(end_hour>start_hour)
);
INSERT INTO partner_sla_calendar VALUES(1,'Asia/Bangkok',9,18,'[]',0);
