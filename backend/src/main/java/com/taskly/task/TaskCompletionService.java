package com.taskly.task;

import com.taskly.common.exception.DomainException;
import java.sql.Timestamp;
import java.time.Clock;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TaskCompletionService {
 public static final String PHOTO_CONTENT="Ảnh xác nhận khu vực đã hoàn thành theo yêu cầu khách hàng";
 private final JdbcTemplate db;
 private final Clock clock;
 public TaskCompletionService(JdbcTemplate db,Clock clock){this.db=db;this.clock=clock;}

 @Transactional public Map<String,Object> confirm(UUID customer,UUID id) {
  var rows=db.queryForList("SELECT status,customer_confirmed_at FROM tasks WHERE id=? AND customer_id=? FOR UPDATE",id,customer);
  if(rows.isEmpty())throw new DomainException("TASK_NOT_FOUND","Không tìm thấy công việc.",HttpStatus.NOT_FOUND);
  var task=rows.getFirst();
  if(!Set.of("COMPLETED","PAID").contains(task.get("status")))throw new DomainException("COMPLETION_NOT_READY","Đối tác chưa gửi yêu cầu xác nhận hoàn thành.",HttpStatus.CONFLICT);
  if(task.get("customer_confirmed_at")!=null)return Map.of("confirmed",true);
  int photos=db.queryForObject("SELECT COUNT(*) FROM task_messages m JOIN tasks t ON t.id=m.task_id WHERE m.task_id=? AND m.sender_id=t.tasker_id AND m.sender_portal='PARTNER' AND m.content=? AND m.image_data IS NOT NULL",Integer.class,id,PHOTO_CONTENT);
  if(photos<2)throw new DomainException("COMPLETION_PHOTOS_REQUIRED","Chưa có đủ ảnh hoàn thành. Vui lòng nhắn đối tác bổ sung ảnh.",HttpStatus.CONFLICT);
  var now=Timestamp.from(clock.instant());
  db.update("UPDATE tasks SET customer_confirmed_at=?,updated_at=?,version=version+1 WHERE id=?",now,now,id);
  db.update("INSERT INTO task_status_history(id,task_id,from_status,to_status,actor_role,reason,occurred_at) VALUES(?,?,?,?, 'CUSTOMER',?,?)",UUID.randomUUID(),id,task.get("status"),task.get("status"),"Khách hàng đã xem ảnh và xác nhận hoàn thành.",now);
  db.update("INSERT INTO task_messages(id,task_id,sender_id,content,sender_portal,created_at) VALUES(?,?,?,?,'CUSTOMER',?)",UUID.randomUUID(),id,customer,"Tôi đã xem ảnh và xác nhận công việc hoàn thành.",now);
  db.update("UPDATE live_sync_revision SET revision=revision+1 WHERE id=1");
  return Map.of("confirmed",true,"customerConfirmedAt",now.toInstant());
 }
}
