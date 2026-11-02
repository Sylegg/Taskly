package com.taskly.recruitment;
import com.taskly.common.exception.DomainException;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RecruitmentCommunicationsService {
 public record TemplateWrite(@NotBlank @Pattern(regexp="REVIEW_RESULT|DOCUMENT_RECEIPT|APPEAL_RESULT") String eventKey,@NotBlank @Size(max=200) String title,@NotBlank @Size(max=2000) String body,boolean active,@PositiveOrZero long version) {}
 public record Retry(@NotNull @Pattern(regexp="SUCCESS|FAILURE") String result) {}
 private final JdbcTemplate db;private final RecruitmentService recruitment;private final String environment;
 public RecruitmentCommunicationsService(JdbcTemplate db,RecruitmentService recruitment,@Value("${app.environment:production}") String environment){this.db=db;this.recruitment=recruitment;this.environment=environment;}
 public List<Map<String,Object>> templates(){return db.queryForList("SELECT * FROM partner_message_templates ORDER BY event_key");}
 public List<Map<String,Object>> outbox(){return db.queryForList("SELECT id,application_id,channel,status,title,message,attempts,created_at,delivered_at,last_attempt_at,last_error FROM partner_notification_outbox ORDER BY created_at DESC LIMIT 200");}
 @Transactional public Map<String,Object> save(UUID actor,UUID id,TemplateWrite w){
  for(var text:List.of(w.title(),w.body())){String residual=text.replace("{title}","").replace("{message}","");if(residual.contains("{")||residual.contains("}"))throw RecruitmentService.invalid("Chỉ hỗ trợ biến {title} và {message}.");}
  if(db.queryForObject("SELECT COUNT(*) FROM partner_message_templates WHERE event_key=? AND id<>?",Integer.class,w.eventKey(),id)>0)throw RecruitmentService.invalid("Sự kiện đã có mẫu. Sửa mẫu hiện hành.");
  if(db.queryForObject("SELECT COUNT(*) FROM partner_message_templates WHERE id=?",Integer.class,id)>0){if(db.update("UPDATE partner_message_templates SET event_key=?,title=?,body=?,active=?,version=version+1 WHERE id=? AND version=?",w.eventKey(),w.title(),w.body(),w.active(),id,w.version())!=1)throw RecruitmentService.conflict();}
  else{if(w.version()!=0)throw RecruitmentService.conflict();db.update("INSERT INTO partner_message_templates VALUES(?,?,?,?,?,0)",id,w.eventKey(),w.title(),w.body(),w.active());}
  recruitment.audit(actor,null,"MESSAGE_TEMPLATE_UPDATED",null,null,w.eventKey());return db.queryForMap("SELECT * FROM partner_message_templates WHERE id=?",id);
 }
 @Transactional public Map<String,Object> retry(UUID actor,UUID id,Retry w){
  if(!Set.of("development","dev","local","test").contains(environment))throw RecruitmentService.invalid("Retry mô phỏng chỉ hoạt động ở development/test; chưa kết nối provider gửi thật.");
  var rows=db.queryForList("SELECT * FROM partner_notification_outbox WHERE id=? FOR UPDATE",id);
  if(rows.isEmpty())throw new DomainException("MESSAGE_NOT_FOUND","Không tìm thấy thông báo.",HttpStatus.NOT_FOUND);
  var before=rows.getFirst();if(!"EMAIL".equals(before.get("channel"))||!Set.of("SIMULATED","FAILED").contains(before.get("status")))throw RecruitmentService.invalid("Chỉ retry email mô phỏng hoặc đã lỗi.");
  String status=w.result().equals("SUCCESS")?"SIMULATED":"FAILED";
  db.update("UPDATE partner_notification_outbox SET status=?,attempts=attempts+1,last_attempt_at=?,last_error=?,delivered_at=NULL WHERE id=?",status,Timestamp.from(Instant.now()),w.result().equals("FAILURE")?"DEMO: lỗi gửi mô phỏng":null,id);
  recruitment.audit(actor,(UUID)before.get("application_id"),"EMAIL_RETRY_SIMULATED",String.valueOf(before.get("status")),status,"Không gửi email thật");return db.queryForMap("SELECT * FROM partner_notification_outbox WHERE id=?",id);
 }
}
