package com.taskly.task;
import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/task-activity")
public class TaskActivityController {
 private final com.taskly.recruitment.RecruitmentActivationService activation; private final JdbcTemplate db; private final com.taskly.booking.CategoryBookingSchemas schemas;
 private final com.taskly.booking.BookingCheckout checkout;
 public TaskActivityController(JdbcTemplate db,com.taskly.booking.BookingCheckout checkout,com.taskly.booking.CategoryBookingSchemas schemas,com.taskly.recruitment.RecruitmentActivationService activation){this.activation=activation;this.db=db;this.checkout=checkout;this.schemas=schemas;}
 public record Task(UUID id,String serviceName,String status,String address,Instant scheduledAt,UUID taskerId,String taskerName,String customerName,long budgetAmount,long platformFee,long partnerNetAmount,Instant originalScheduledStartAt,Instant originalScheduledEndAt,Instant approvedStartAt,Instant expectedEndAt,Instant acceptedAt,Instant checkedInAt,Instant actualStartedAt,Instant verifiedActualEndAt,UUID earlyStartRequestId){}
 public record Event(String status,Instant at,String reason){}
 public record Message(UUID id,String text,String imageData,boolean mine,Instant at){}
 public record Detail(Task task,List<Event> events,List<Message> messages,Map<String,Object> payment,Map<String,Object> booking,Map<String,Object> addressDetails,Map<String,Object> earlyStart){}
 public record Send(@Size(max=4000) String text,@NotNull UUID requestId,@Size(max=2800000) String imageData){}
 private static Instant t(java.sql.Timestamp ts){return ts==null?null:ts.toInstant();}
 private List<Task> tasks(UUID user,UUID id){return db.query("SELECT t.*,"+PartnerEarnings.FEE_SQL+" AS platform_fee,(t.budget_amount-"+PartnerEarnings.FEE_SQL+") AS partner_net_amount,u.full_name AS tasker_name,COALESCE(cu.full_name, t.recipient_name_snapshot) AS customer_name FROM tasks t LEFT JOIN service_pricing_rules r ON r.service_id=t.service_id LEFT JOIN user_profiles u ON u.user_id=t.tasker_id LEFT JOIN user_profiles cu ON cu.user_id=t.customer_id WHERE (t.customer_id=? OR t.tasker_id=?) AND t.status<>'DRAFT' "+(id==null?"":"AND t.id=? ")+"ORDER BY t.created_at DESC",(r,n)->new Task(r.getObject("id",UUID.class),r.getString("service_name_snapshot"),r.getString("status"),r.getString("address_line_snapshot"),t(r.getTimestamp("scheduled_at")),r.getObject("tasker_id",UUID.class),r.getString("tasker_name"),r.getString("customer_name"),r.getLong("budget_amount"),r.getLong("platform_fee"),r.getLong("partner_net_amount"),r.getTimestamp("original_scheduled_start_at")!=null?t(r.getTimestamp("original_scheduled_start_at")):t(r.getTimestamp("scheduled_at")),t(r.getTimestamp("original_scheduled_end_at")),t(r.getTimestamp("approved_start_at")),t(r.getTimestamp("expected_end_at")),t(r.getTimestamp("accepted_at")),t(r.getTimestamp("checked_in_at")),t(r.getTimestamp("actual_started_at")),t(r.getTimestamp("verified_actual_end_at")),r.getObject("early_start_request_id",UUID.class)),id==null?new Object[]{user,user}:new Object[]{user,user,id});}
 private Task task(UUID user,UUID id){return tasks(user,id).stream().findFirst().orElseThrow(()->new DomainException("TASK_NOT_FOUND","Không tìm thấy công việc.",HttpStatus.NOT_FOUND));}
 private String chatPortal(UUID user,UUID id,boolean partner){
  var row=db.queryForMap("SELECT customer_id,tasker_id FROM tasks WHERE id=?",id);
  boolean customer=user.equals(row.get("customer_id"));
  boolean tasker=user.equals(row.get("tasker_id"));
  if(partner && !tasker)throw new DomainException("TASK_NOT_FOUND","Không tìm thấy công việc.",HttpStatus.NOT_FOUND);
  return tasker && (!customer || partner) ? "PARTNER" : "CUSTOMER";
 }
 @GetMapping public ApiResponse<List<Task>> list(@AuthenticationPrincipal Jwt jwt,@RequestParam(defaultValue="false") boolean partner){var user=UUID.fromString(jwt.getSubject());return ApiResponse.success(tasks(user,null).stream().filter(t->!partner||user.equals(t.taskerId())).toList());}
 private Map<String,Object> earlyStart(UUID id){
  var rows=db.queryForList("SELECT id, requested_start_at AS \"requestedStartAt\", proposed_end_at AS \"proposedEndAt\", reason, status, requested_at AS \"requestedAt\", expires_at AS \"expiresAt\" FROM early_start_requests WHERE task_id=? ORDER BY requested_at DESC LIMIT 1",id);
  return rows.isEmpty()?Map.of():new LinkedHashMap<>(rows.getFirst());
 }
 @GetMapping("/{id}") public ApiResponse<Detail> detail(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@RequestParam(defaultValue="false") boolean partner){var user=UUID.fromString(jwt.getSubject());var task=task(user,id);var portal=chatPortal(user,id,partner);return ApiResponse.success(new Detail(task,db.query("SELECT to_status,occurred_at,reason FROM task_status_history WHERE task_id=? ORDER BY occurred_at,id",(r,n)->new Event(r.getString(1),r.getTimestamp(2).toInstant(),r.getString(3)),id),db.query("SELECT id,content,image_data,sender_id,created_at,sender_portal FROM task_messages WHERE task_id=? ORDER BY created_at,id",(r,n)->new Message(r.getObject(1,UUID.class),r.getString(2),r.getString(3),user.equals(r.getObject(4,UUID.class)) && (r.getString(6)==null || portal.equals(r.getString(6))),r.getTimestamp(5).toInstant()),id),checkout.payment(user,id),booking(id),addressDetails(id),earlyStart(id)));}


 @GetMapping("/{id}/preview") @Transactional @org.springframework.security.access.prepost.PreAuthorize("hasRole('TASKER')")
 public ApiResponse<Detail> preview(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){
  UUID user=UUID.fromString(jwt.getSubject());
  if(activation.feed(user).stream().noneMatch(t->id.equals(t.get("id"))))throw new DomainException("TASK_NOT_AVAILABLE","Công việc không còn khả dụng.",HttpStatus.NOT_FOUND);
  var locked=db.queryForMap("SELECT customer_id,status,tasker_id FROM tasks WHERE id=? FOR UPDATE",id);
  if(!Set.of("POSTED","MATCHING").contains(locked.get("status")) || locked.get("tasker_id")!=null)throw new DomainException("TASK_NOT_AVAILABLE","Công việc không còn khả dụng.",HttpStatus.NOT_FOUND);
  UUID owner=(UUID)locked.get("customer_id");
  return ApiResponse.success(new Detail(task(owner,id),List.of(),List.of(),Map.of(),booking(id),addressDetails(id),Map.of()));
 }
 @PostMapping("/{id}/view") @Transactional @org.springframework.security.access.prepost.PreAuthorize("hasRole('TASKER')")
 public ApiResponse<Void> recordView(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){
  UUID user=UUID.fromString(jwt.getSubject());
  if(activation.feed(user).stream().noneMatch(t->id.equals(t.get("id"))))throw new DomainException("TASK_NOT_AVAILABLE","Công việc không còn khả dụng.",HttpStatus.NOT_FOUND);
  var row=db.queryForMap("SELECT customer_id,status,tasker_id FROM tasks WHERE id=? FOR UPDATE",id);
  if(!Set.of("POSTED","MATCHING").contains(row.get("status")) || row.get("tasker_id")!=null)throw new DomainException("TASK_NOT_AVAILABLE","Công việc không còn khả dụng.",HttpStatus.NOT_FOUND);
  if(user.equals(row.get("customer_id")))return ApiResponse.success(null);
  if(db.update("UPDATE task_booking_payments SET tasker_viewed_at=CURRENT_TIMESTAMP,tasker_viewed_by=? WHERE task_id=? AND tasker_viewed_by IS NULL",user,id)>0)db.update("UPDATE live_sync_revision SET revision=revision+1 WHERE id=1");
  return ApiResponse.success(null);
 }
 private Map<String,Object> addressDetails(UUID id){
  return db.queryForMap("SELECT address_label_snapshot AS label,address_line_snapshot AS street,ward_snapshot AS ward,district_snapshot AS district,city_snapshot AS city,recipient_name_snapshot AS \"recipientName\",recipient_phone_snapshot AS \"recipientPhone\",address_notes_snapshot AS notes,building_type_snapshot AS \"buildingType\",building_description_snapshot AS \"buildingDescription\" FROM tasks WHERE id=?",id);
 }
 private Map<String,Object> booking(UUID id){
  var rows=db.queryForList("SELECT p.draft_payload,q.line_items,q.subtotal,q.platform_fee,q.total FROM task_booking_payments p JOIN customer_price_quotes q ON q.id=p.quote_id WHERE p.task_id=?",id);
  if(rows.isEmpty())return Map.of();
  var json=new tools.jackson.databind.ObjectMapper();
  var draft=json.readValue(rows.getFirst().get("draft_payload").toString(),com.taskly.booking.BookingDraftController.Draft.class);
  var result=new LinkedHashMap<String,Object>();
  result.put("description",draft.description());result.put("notes",draft.notes());result.put("duration",draft.duration());
  var items=json.readValue(rows.getFirst().get("line_items").toString(),new tools.jackson.core.type.TypeReference<List<Map<String,Object>>>(){});
  for(var item:items){
   String serviceId=item.get("serviceId").toString();
   var slugs=db.queryForList("SELECT slug FROM services WHERE id=?",String.class,UUID.fromString(serviceId));
   var fields=new ArrayList<Map<String,Object>>();
   if(!slugs.isEmpty()){
    var schema=schemas.all().stream().filter(sc->sc.serviceSlugs().contains(slugs.getFirst())).findFirst();
    String prefix=serviceId.equals(draft.serviceId().toString())?"":serviceId+"_";
    if(schema.isPresent())for(var field:schema.get().fields()){
     var value=draft.details().get(prefix+field.key());
     if(value!=null)fields.add(Map.of("label",field.label(),"value",value));
    }
   }
   item.put("fields",fields);
   item.put("description",draft.details().getOrDefault("service_desc_"+serviceId,serviceId.equals(draft.serviceId().toString())?Objects.toString(draft.description(),""):""));
  }
  result.put("services",items);result.put("subtotal",rows.getFirst().get("subtotal"));result.put("platformFee",rows.getFirst().get("platform_fee"));result.put("total",rows.getFirst().get("total"));return result;
 }
 @PostMapping("/{id}/messages") @Transactional public ApiResponse<Void> send(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Send body,@RequestParam(defaultValue="false") boolean partner){
  var user=UUID.fromString(jwt.getSubject());
  db.query("SELECT id FROM tasks WHERE id=? FOR UPDATE",(r,n)->r.getObject(1,UUID.class),id);
  var task=task(user,id);
  var portal=chatPortal(user,id,partner);
  if(task.taskerId()==null)throw new DomainException("TASKER_REQUIRED","Chat mở khi công việc đã có Tasker.",HttpStatus.UNPROCESSABLE_ENTITY);
  if(Set.of("CANCELLED","REFUNDED","EXPIRED").contains(task.status()))throw new DomainException("CHAT_CLOSED","Công việc đã kết thúc. Bạn vẫn có thể xem lại tin nhắn.",HttpStatus.CONFLICT);
  if((body.text()==null||body.text().trim().isEmpty()) && (body.imageData()==null||body.imageData().trim().isEmpty()))throw new DomainException("EMPTY_MESSAGE","Nội dung tin nhắn không được để trống.",HttpStatus.BAD_REQUEST);
  validateImage(body.imageData());
  var existing=db.query("SELECT task_id,sender_id,sender_portal FROM task_messages WHERE id=?",(r,n)->Arrays.asList(r.getObject(1,UUID.class),r.getObject(2,UUID.class),r.getString(3)),body.requestId());
  if(!existing.isEmpty()){if(!existing.getFirst().subList(0,2).equals(List.of(id,user)) || (existing.getFirst().get(2)!=null && !portal.equals(existing.getFirst().get(2))))throw new DomainException("MESSAGE_CONFLICT","Mã tin nhắn không hợp lệ.",HttpStatus.CONFLICT);return ApiResponse.success(null);}
  String text=(body.text()!=null && !body.text().trim().isEmpty())?body.text().trim():"Ảnh đính kèm";
  db.update("INSERT INTO task_messages(id,task_id,sender_id,content,image_data,sender_portal) VALUES(?,?,?,?,?,?)",body.requestId(),id,user,text,body.imageData(),portal);
  var taskRows=db.queryForList("SELECT customer_id,tasker_id,service_name_snapshot FROM tasks WHERE id=?",id);
  if(!taskRows.isEmpty()){
   var t=taskRows.getFirst();
   UUID customerId=(UUID)t.get("customer_id");
   if(!user.equals(customerId)){
    var partnerName=db.queryForList("SELECT full_name FROM user_profiles WHERE user_id=?",String.class,user).stream().findFirst().orElse("Đối tác");
    String preview=text;
    if(preview.length()>60)preview=preview.substring(0,57)+"...";
    db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),customerId,id,"Đối tác "+partnerName+" vừa nhắn: \""+preview+"\"",java.sql.Timestamp.from(Instant.now()));
   }else{
    UUID taskerId=(UUID)t.get("tasker_id");
    if(taskerId!=null){
     var custName=db.queryForList("SELECT full_name FROM user_profiles WHERE user_id=?",String.class,user).stream().findFirst().orElse("Khách hàng");
     String preview=text;
     if(preview.length()>60)preview=preview.substring(0,57)+"...";
     var appIds=db.queryForList("SELECT id FROM partner_applications WHERE user_id=?",UUID.class,taskerId);
     if(!appIds.isEmpty()){
      db.update("INSERT INTO partner_notification_outbox(id,application_id,task_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,?,'IN_APP','DELIVERED',?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",
        UUID.randomUUID(),appIds.getFirst(),id,"Tin nhắn từ khách hàng "+custName,"Khách hàng vừa nhắn: \""+preview+"\". Chạm để xem và phản hồi.");
     }
    }
   }
  }
  return ApiResponse.success(null);
 }
 public static void validateImage(String image){
  if(image==null||image.isEmpty())return;
  try{
   if(!image.startsWith("data:image/png;base64,")&&!image.startsWith("data:image/jpeg;base64,"))throw new IllegalArgumentException();
   byte[] bytes=Base64.getDecoder().decode(image.substring(image.indexOf(',')+1));
   if(bytes.length>2000000)throw new IllegalArgumentException();
   try(var in=javax.imageio.ImageIO.createImageInputStream(new java.io.ByteArrayInputStream(bytes))){
    var readers=javax.imageio.ImageIO.getImageReaders(in);if(!readers.hasNext())throw new IllegalArgumentException();
    var reader=readers.next();try{reader.setInput(in);if((long)reader.getWidth(0)*reader.getHeight(0)>20000000)throw new IllegalArgumentException();}finally{reader.dispose();}
   }
  }catch(Exception e){throw new DomainException("INVALID_IMAGE","Ảnh phải là PNG hoặc JPEG, tối đa 2 MB.",HttpStatus.BAD_REQUEST);}
 }
}
