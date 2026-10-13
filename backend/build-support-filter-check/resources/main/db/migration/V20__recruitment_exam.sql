CREATE TABLE recruitment_questions (
 id UUID PRIMARY KEY, text VARCHAR(2000) NOT NULL, options VARCHAR(4000) NOT NULL,
 correct_option INTEGER NOT NULL CHECK(correct_option BETWEEN 0 AND 3), category VARCHAR(100) NOT NULL,
 difficulty INTEGER NOT NULL CHECK(difficulty BETWEEN 1 AND 5), active BOOLEAN NOT NULL,
 version BIGINT NOT NULL DEFAULT 0, updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE recruitment_exam_attempts (
 id UUID PRIMARY KEY, application_id UUID NOT NULL REFERENCES partner_applications(id),
 status VARCHAR(20) NOT NULL, questions VARCHAR(100000) NOT NULL, answers VARCHAR(2000) NOT NULL DEFAULT '{}',
 score INTEGER, pass_mark INTEGER NOT NULL, config_version BIGINT NOT NULL,
 started_at TIMESTAMP WITH TIME ZONE NOT NULL, expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
 submitted_at TIMESTAMP WITH TIME ZONE
);
CREATE INDEX idx_recruitment_attempts ON recruitment_exam_attempts(application_id,started_at);
