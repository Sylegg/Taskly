ALTER TABLE community_articles ADD COLUMN author_name VARCHAR(100) NOT NULL DEFAULT 'TaskLy';
ALTER TABLE community_articles ADD COLUMN hashtag VARCHAR(60) NOT NULL DEFAULT 'TaskLyNews';
ALTER TABLE community_articles ADD COLUMN group_name VARCHAR(100) NOT NULL DEFAULT '';
ALTER TABLE community_articles ADD COLUMN featured BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE community_articles ADD COLUMN submitted_by UUID REFERENCES users(id);
CREATE TABLE community_reactions (
 article_id UUID NOT NULL REFERENCES community_articles(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 kind VARCHAR(10) NOT NULL CHECK (kind IN ('LIKE','REPOST')),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(article_id,user_id,kind)
);
CREATE TABLE community_comments (
 id UUID PRIMARY KEY,
 article_id UUID NOT NULL REFERENCES community_articles(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 content VARCHAR(2000) NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_community_comments_article ON community_comments(article_id,created_at);
