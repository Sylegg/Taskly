CREATE TABLE partner_training_lessons (
 id UUID PRIMARY KEY, title VARCHAR(200) NOT NULL, video_url VARCHAR(1000) NOT NULL,
 duration_seconds INTEGER NOT NULL CHECK(duration_seconds BETWEEN 10 AND 14400),
 watch_ratio DECIMAL(4,3) NOT NULL CHECK(watch_ratio BETWEEN 0.5 AND 1),
 quiz_text VARCHAR(2000) NOT NULL, quiz_options VARCHAR(4000) NOT NULL,
 correct_option INTEGER NOT NULL CHECK(correct_option BETWEEN 0 AND 3),
 required BOOLEAN NOT NULL, demo BOOLEAN NOT NULL, active BOOLEAN NOT NULL,
 display_order INTEGER NOT NULL CHECK(display_order >= 0), version BIGINT NOT NULL DEFAULT 0
);
CREATE TABLE partner_learning_progress (
 application_id UUID NOT NULL REFERENCES partner_applications(id), lesson_id UUID NOT NULL REFERENCES partner_training_lessons(id),
 lesson_version BIGINT NOT NULL, position_seconds INTEGER NOT NULL DEFAULT 0,
 watched_seconds INTEGER NOT NULL DEFAULT 0, quiz_passed BOOLEAN NOT NULL DEFAULT FALSE,
 completed_at TIMESTAMP WITH TIME ZONE, last_heartbeat_at TIMESTAMP WITH TIME ZONE NOT NULL,
 PRIMARY KEY(application_id,lesson_id)
);
