package com.taskly.task;

import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import java.time.Instant;
import java.sql.Timestamp;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/task-activity/{id}/arrival-report")
public class TaskArrivalReportController {
 private final JdbcTemplate db;
 public TaskArrivalReportController(JdbcTemplate db) { this.db=db; }
 public record ArrivalState(Instant serverNow, Instant scheduledAt, Instant reportAvailableAt, boolean eligible, boolean reported, String reportType, boolean visible) {}
 private Map<String,Object> owned(UUID user, UUID id, boolean lock) {
  var rows=db.queryForList("SELECT * FROM tasks WHERE id=? AND customer_id=?"+(lock?" FOR UPDATE":""),id,user);
  if(rows.isEmpty())throw new DomainException("TASK_NOT_FOUND","Không tìm thấy đơn dịch vụ.",HttpStatus.NOT_FOUND);
  return rows.getFirst();
 }
 private ArrivalState state(UUID id, Map<String,Object> task) {
  var now=Instant.now();
  boolean waiting=task.get("tasker_id")==null && Set.of("POSTED","MATCHING").contains(task.get("status"));
  String type=waiting?"NO_TASKER":"LATE_ARRIVAL";
  boolean reported=db.queryForObject("SELECT COUNT(*) FROM task_arrival_reports WHERE task_id=? AND report_type=?",Integer.class,id,type)>0;
  var starts=db.queryForList("SELECT occurred_at FROM task_status_history WHERE task_id=? AND to_status='TASKER_ON_THE_WAY' ORDER BY occurred_at DESC",Timestamp.class,id);
  var scheduled=db.queryForObject("SELECT scheduled_at FROM tasks WHERE id=?",(r,n)->r.getTimestamp(1).toInstant(),id);
  var start=starts.isEmpty()?null:starts.getFirst().toInstant();
  // An early departure must not consume the customer's grace period before the appointment.
  var deadline=waiting?scheduled.plusSeconds(1800):start==null?null:(start.isBefore(scheduled)?scheduled:start).plusSeconds(1800);
  boolean visible=(waiting && !now.isBefore(scheduled)) || (task.get("tasker_id")!=null && "TASKER_ON_THE_WAY".equals(task.get("status")) && !now.isBefore(scheduled));
  boolean eligible=visible && deadline!=null && !now.isBefore(deadline) && !reported;
  return new ArrivalState(now,scheduled,deadline,eligible,reported,type,visible);
 }
 @GetMapping public ApiResponse<ArrivalState> get(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  return ApiResponse.success(state(id,owned(UUID.fromString(jwt.getSubject()),id,false)));
 }
 @PostMapping @Transactional public ApiResponse<ArrivalState> report(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  var user=UUID.fromString(jwt.getSubject());
  // Lock the same task row as arrival/status transitions to prevent a stale report.
  var task=owned(user,id,true);var current=state(id,task);
  if(current.reported())return ApiResponse.success(current);
  if(!current.eligible())throw new DomainException("ARRIVAL_REPORT_NOT_AVAILABLE","Chỉ có thể báo cáo sau 30 phút chờ nhận việc hoặc chờ Tasker đến.",HttpStatus.CONFLICT);
  var names=db.queryForList("SELECT full_name FROM user_profiles WHERE user_id=?",String.class,task.get("tasker_id"));
  task.put("tasker_name",names.isEmpty()?null:names.getFirst());
  var message=UUID.randomUUID();
  String title=current.reportType().equals("NO_TASKER")?"Báo cáo chưa có Tasker nhận việc sau 30 phút":"Báo cáo Tasker chưa tới sau 30 phút";
  String content=title+"\nĐơn dịch vụ: "+id+"\nDịch vụ: "+task.get("service_name_snapshot")+"\nTasker: "+(task.get("tasker_id")==null?"Chưa có người nhận":Objects.toString(task.get("tasker_name"),"Chưa cập nhật")+" ("+task.get("tasker_id")+")")+"\nĐịa chỉ: "+task.get("address_line_snapshot")+"\nKhách hàng đề nghị admin kiểm tra và hỗ trợ.";
  db.update("INSERT INTO customer_support_messages(id,user_id,sender,content,task_id) VALUES(?,?,'USER',?,?)",message,user,content,id);
  db.update("INSERT INTO task_arrival_reports(task_id,customer_id,tasker_id,message_id,report_type) VALUES(?,?,?,?,?)",id,user,task.get("tasker_id"),message,current.reportType());
  return ApiResponse.success(state(id,task));
 }
}
