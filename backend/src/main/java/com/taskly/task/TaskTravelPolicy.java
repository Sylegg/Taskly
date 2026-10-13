package com.taskly.task;

import java.time.Instant;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;

public final class TaskTravelPolicy {
 private TaskTravelPolicy() {}
 public static boolean canTravel(JdbcTemplate db,UUID taskId,UUID partner,Instant now) {
  var rows=db.query("SELECT scheduled_at FROM tasks WHERE id=? AND tasker_id=? AND status='ACCEPTED'",(r,n)->r.getTimestamp(1).toInstant(),taskId,partner);
  if(rows.isEmpty())return false;
  if(!now.isBefore(rows.getFirst().minusSeconds(15 * 60L)))return true;
  return db.queryForObject("SELECT COUNT(*) FROM early_start_requests r JOIN tasks t ON t.id=r.task_id WHERE t.id=? AND r.partner_id=? AND r.status='APPROVED' AND t.early_start_request_id=r.id AND t.approved_start_at IS NOT NULL",Integer.class,taskId,partner)>0;
 }
}
