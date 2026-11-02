CREATE TABLE community_video_likes (
 video_id UUID NOT NULL REFERENCES community_videos(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 PRIMARY KEY(video_id,user_id)
);
