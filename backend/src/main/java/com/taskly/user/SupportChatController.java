package com.taskly.user;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1")
public class SupportChatController {
 private final JdbcTemplate db;
 public SupportChatController(JdbcTemplate db){this.db=db;}
 public record Send(@NotNull UUID requestId,@NotBlank @Size(max=4000) String text,@Size(max=2800000) String imageData,UUID taskId){}
 private List<Map<String,Object>> messages(UUID user){return db.queryForList("SELECT id,sender,content,image_data,created_at,task_id FROM support_messages WHERE user_id=? ORDER BY created_at,id",user);}
 @GetMapping("/support/messages") public ApiResponse<List<Map<String,Object>>> list(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(messages(UUID.fromString(jwt.getSubject())));}
 @PostMapping("/support/messages") @Transactional public ApiResponse<Void> send(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Send body){
  validateImage(body.imageData());
  var user=UUID.fromString(jwt.getSubject());
  validateTask(user,body.taskId());
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,user);
  if(db.queryForObject("SELECT COUNT(*) FROM support_messages WHERE id=? AND user_id=?",Integer.class,body.requestId(),user)>0)return ApiResponse.success(null);
  db.update("INSERT INTO support_messages(id,user_id,sender,content,image_data,task_id) VALUES(?,?,'USER',?,?,?)",body.requestId(),user,body.text().trim(),body.imageData(),body.taskId());return ApiResponse.success(null);
 }

 private void validateTask(UUID user,UUID task) {
  if(task!=null && db.queryForObject("SELECT COUNT(*) FROM tasks WHERE id=? AND tasker_id=? AND status<>'DRAFT'",Integer.class,task,user)==0)
   throw new com.taskly.common.exception.DomainException("TASK_NOT_FOUND","Không tìm thấy đơn dịch vụ của bạn.",org.springframework.http.HttpStatus.NOT_FOUND);
 }
 @GetMapping("/support/tasks") public ApiResponse<List<Map<String,Object>>> supportTasks(@AuthenticationPrincipal Jwt jwt) {
  return ApiResponse.success(db.queryForList("SELECT id,service_name_snapshot AS \"serviceName\",status,scheduled_at AS \"scheduledAt\",address_line_snapshot AS address FROM tasks WHERE tasker_id=? AND status IN ('POSTED','MATCHING','ACCEPTED','TASKER_ON_THE_WAY','ARRIVED','IN_PROGRESS','DISPUTED') ORDER BY created_at DESC",UUID.fromString(jwt.getSubject())));
 }
 private void validateImage(String image) {
  if(image==null)return;
  try {
   if(!image.startsWith("data:image/png;base64,")&&!image.startsWith("data:image/jpeg;base64,"))throw new IllegalArgumentException();
   byte[] bytes=Base64.getDecoder().decode(image.substring(image.indexOf(',')+1));
   if(bytes.length>2000000)throw new IllegalArgumentException();
   try(var in=javax.imageio.ImageIO.createImageInputStream(new java.io.ByteArrayInputStream(bytes))) {
    var readers=javax.imageio.ImageIO.getImageReaders(in);if(!readers.hasNext())throw new IllegalArgumentException();
    var reader=readers.next();try {reader.setInput(in);if((long)reader.getWidth(0)*reader.getHeight(0)>20000000)throw new IllegalArgumentException();}finally{reader.dispose();}
   }
  }catch(Exception e){throw new com.taskly.common.exception.DomainException("INVALID_IMAGE","Ảnh phải là PNG hoặc JPEG, tối đa 2 MB.",org.springframework.http.HttpStatus.BAD_REQUEST);}
 }
 @GetMapping("/admin/support/conversations") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<List<Map<String,Object>>> queue(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(db.queryForList("SELECT m.user_id,p.full_name,m.updated_at,(SELECT MAX(sm.created_at) FROM support_messages sm WHERE sm.user_id=m.user_id AND sm.sender='USER') AS last_incoming_at,f.portrait AS avatar,(SELECT COUNT(*) FROM support_messages sm WHERE sm.user_id=m.user_id AND sm.sender='USER' AND NOT EXISTS(SELECT 1 FROM support_message_reads r WHERE r.message_id=sm.id AND r.admin_id=?)) AS unread_count FROM (SELECT user_id,MAX(created_at) AS updated_at FROM support_messages GROUP BY user_id) m LEFT JOIN user_profiles p ON p.user_id=m.user_id LEFT JOIN partner_applications a ON a.user_id=m.user_id LEFT JOIN partner_final_documents f ON f.application_id=a.id ORDER BY m.updated_at DESC",UUID.fromString(jwt.getSubject())));}
 @GetMapping("/admin/support/{user}/messages") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<List<Map<String,Object>>> detail(@PathVariable UUID user){return ApiResponse.success(messages(user));}
 public record Read(@NotNull @Size(max=1000) List<UUID> messageIds){}
 @PostMapping("/admin/support/{user}/read") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") @Transactional public ApiResponse<Void> read(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID user,@Valid @RequestBody Read body){
  var admin=UUID.fromString(jwt.getSubject());
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,admin);
  for(var id:body.messageIds()) db.update("INSERT INTO support_message_reads(message_id,admin_id) SELECT id,? FROM support_messages WHERE id=? AND user_id=? AND sender='USER' AND NOT EXISTS(SELECT 1 FROM support_message_reads WHERE message_id=? AND admin_id=?)",admin,id,user,id,admin);
  return ApiResponse.success(null);
 }
 @PostMapping("/admin/support/{user}/messages") @PreAuthorize("hasAuthority('RECRUITMENT_PRELIMINARY')") @Transactional public ApiResponse<Void> reply(@PathVariable UUID user,@Valid @RequestBody Send body){
  db.update("INSERT INTO support_messages(id,user_id,sender,content) VALUES(?,?,'STAFF',?)",body.requestId(),user,body.text().trim());
  String preview=body.text().trim();
  if(preview.length()>60)preview=preview.substring(0,57)+"...";
  db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,NULL,?,CURRENT_TIMESTAMP)",UUID.randomUUID(),user,"Hỗ trợ viên TaskLy: \""+preview+"\"");
  return ApiResponse.success(null);
 }
}
