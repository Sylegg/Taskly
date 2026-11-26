package com.taskly.task;

import java.time.Instant;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;

public final class TaskTravelPolicy {
 private TaskTravelPolicy() {}
 public static boolean canTravel(JdbcTemplate db,UUID taskId,UUID partner,Instant now) {
  var rows=db.query("""
      SELECT COALESCE(t.approved_start_at,t.scheduled_at)
      FROM tasks t WHERE t.id=? AND t.tasker_id=? AND t.status='ACCEPTED'
      """,(r,n)->r.getTimestamp(1).toInstant(),taskId,partner);
  if(rows.isEmpty())return false;
  return !now.isBefore(rows.getFirst().minusSeconds(15 * 60L));
 }
}
