package com.taskly.recruitment;
import java.math.BigDecimal;
import com.taskly.common.exception.DomainException;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
@Service
public class RecruitmentActivationService {
 public record Activation(@PositiveOrZero long version,@NotNull Instant startsAt,@NotNull Instant endsAt) {}
 public record JobStatus(@NotBlank String expectedStatus,@NotNull @Pattern(regexp="TASKER_ON_THE_WAY|ARRIVED|IN_PROGRESS|COMPLETED") String status,@NotBlank @Size(max=100) String requestId) {}
 @Transactional public Map<String,Object> progressJob(UUID user,UUID id,JobStatus w){
  com.taskly.task.PartnerWorkPolicy.lock(db,user);
  var a=eligible(user);var rows=db.queryForList("SELECT id,status FROM tasks WHERE id=? AND tasker_id=? FOR UPDATE",id,user);if(rows.isEmpty())throw new DomainException("TASK_NOT_FOUND","Không tìm thấy công việc đã nhận.",HttpStatus.NOT_FOUND);
  var task=rows.getFirst();String hash=RecruitmentService.hash(id+":"+w.toString());var previous=db.queryForList("SELECT payload_hash FROM recruitment_requests WHERE actor_id=? AND request_key=?",String.class,user,w.requestId());
  if(!previous.isEmpty()){if(!previous.getFirst().equals(hash))throw RecruitmentService.conflict();return task;}
  String current=String.valueOf(task.get("status"));var transitions=Map.of("ACCEPTED","TASKER_ON_THE_WAY","TASKER_ON_THE_WAY","ARRIVED","ARRIVED","IN_PROGRESS","IN_PROGRESS","COMPLETED");
  if(!current.equals(w.expectedStatus())||!w.status().equals(transitions.get(current)))throw RecruitmentService.invalid("Trạng thái công việc đã thay đổi hoặc bước chuyển không hợp lệ.");
  if(!"COMPLETED".equals(w.status()))com.taskly.task.PartnerWorkPolicy.requireFree(db,user,id);
  var now=Timestamp.from(Instant.now());
  if("TASKER_ON_THE_WAY".equals(w.status()) && !com.taskly.task.TaskTravelPolicy.canTravel(db,id,user,now.toInstant()))
   throw new DomainException("EARLY_TRAVEL_REQUIRES_APPROVAL","Bạn có thể di chuyển trước giờ hẹn 15 phút. Nếu muốn đến sớm hơn, vui lòng gửi yêu cầu và chờ khách hàng duyệt.",HttpStatus.CONFLICT);
  if ("ARRIVED".equals(w.status())) {
   throw new DomainException("CHECKIN_PHOTO_REQUIRED","Vui lòng chụp ảnh và dùng chức năng check-in của đơn.",HttpStatus.BAD_REQUEST);
  } else if ("IN_PROGRESS".equals(w.status())) {
   db.update("UPDATE tasks SET status=?,actual_started_at=COALESCE(actual_started_at,?),updated_at=?,version=version+1 WHERE id=?",w.status(),now,now,id);
   db.update("UPDATE early_start_requests SET status='APPLIED' WHERE task_id=? AND status='APPROVED'",id);
  } else if ("COMPLETED".equals(w.status())) {
   if(db.queryForObject("SELECT COUNT(*) FROM task_messages WHERE task_id=? AND sender_id=? AND sender_portal='PARTNER' AND content='Ảnh xác nhận khu vực đã hoàn thành theo yêu cầu khách hàng' AND image_data IS NOT NULL",Integer.class,id,user)<2)
    throw new DomainException("COMPLETION_PHOTOS_REQUIRED","Chụp ít nhất 2 ảnh các khu vực đã làm và vị trí khách yêu cầu trước khi hoàn thành.",HttpStatus.BAD_REQUEST);
   com.taskly.task.PartnerTaskSettlement.settle(db,id,user);
   db.update("UPDATE tasks SET status=?,verified_actual_end_at=COALESCE(verified_actual_end_at,?),updated_at=?,version=version+1 WHERE id=?",w.status(),now,now,id);
  } else {
   db.update("UPDATE tasks SET status=?,updated_at=?,version=version+1 WHERE id=?",w.status(),now,id);
  }
  db.update("INSERT INTO task_status_history(id,task_id,from_status,to_status,actor_role,occurred_at) VALUES(?,?,?,?,'TASKER',?)",UUID.randomUUID(),id,current,w.status(),now);
  var taskInfo=db.queryForMap("SELECT customer_id,service_name_snapshot FROM tasks WHERE id=?",id);
  var partnerName=db.queryForList("SELECT full_name FROM user_profiles WHERE user_id=?",String.class,user).stream().findFirst().orElse("Đối tác");
  String noteTitle=switch(w.status()){
   case "TASKER_ON_THE_WAY"->"Đối tác "+partnerName+" đang trên đường đến địa chỉ thực hiện đơn \""+taskInfo.get("service_name_snapshot")+"\".";
   case "ARRIVED"->"Đối tác "+partnerName+" đã đến nơi. Vui lòng hỗ trợ đối tác bắt đầu công việc.";
   case "IN_PROGRESS"->"Đối tác đã bắt đầu thực hiện công việc \""+taskInfo.get("service_name_snapshot")+"\".";
   case "COMPLETED"->"Công việc \""+taskInfo.get("service_name_snapshot")+"\" đã hoàn thành! Vui lòng kiểm tra và hoàn tất thanh toán.";
   default->"Trạng thái công việc \""+taskInfo.get("service_name_snapshot")+"\" đã chuyển sang: "+w.status();
  };
  db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),taskInfo.get("customer_id"),id,noteTitle,now);
  String chatNotice = switch(w.status()) {
   case "TASKER_ON_THE_WAY" -> "Tôi đang đến địa chỉ thực hiện dịch vụ.";
   case "IN_PROGRESS" -> "Tôi đã bắt đầu thực hiện công việc.";
   case "COMPLETED" -> "Tôi đã hoàn thành công việc. Bạn vui lòng kiểm tra và xác nhận.";
   default -> noteTitle;
  };
  db.update("INSERT INTO task_messages(id,task_id,sender_id,content,sender_portal,created_at) VALUES(?,?,?,?,'PARTNER',?)",UUID.randomUUID(),id,user,chatNotice,now);
  if("COMPLETED".equals(w.status()))db.update("INSERT INTO partner_notification_outbox(id,application_id,task_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,?,'IN_APP','DELIVERED',?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",UUID.randomUUID(),a.id(),id,"Hoàn tất công việc #"+id.toString().substring(0,8).toUpperCase(),"Bạn đã hoàn thành công việc \""+taskInfo.get("service_name_snapshot")+"\". Thu nhập ước tính đã được ghi nhận vào ví đối tác.");
  db.update("INSERT INTO recruitment_requests VALUES(?,?,?,?,?)",user,w.requestId(),hash,a.id(),now);recruitment.audit(user,a.id(),"JOB_STATUS_UPDATED",current,w.status(),"Task "+id);return Map.of("id",id,"status",w.status());
 }
 public record Appeal(@NotBlank @Size(max=1000) String reason) {}
 public record Completion(@NotNull @Size(min=2,max=10) List<@NotBlank String> images,@NotBlank String requestId,boolean confirmedAllAreas) {}
 @Transactional public Map<String,Object> completeWithPhotos(UUID user,UUID task,Completion body) {
  com.taskly.task.PartnerWorkPolicy.lock(db,user);
  var rows=db.queryForList("SELECT status FROM tasks WHERE id=? AND tasker_id=? FOR UPDATE",task,user);
  if(rows.isEmpty())throw new DomainException("TASK_NOT_FOUND","Không tìm thấy đơn.",HttpStatus.NOT_FOUND);
  if(Set.of("COMPLETED","PAID").contains(rows.getFirst().get("status")))return Map.of("id",task,"status",rows.getFirst().get("status"));
  if(!body.confirmedAllAreas() || body.images()==null || body.images().size()<2 || body.images().size()>10 || new HashSet<>(body.images()).size()!=body.images().size())throw RecruitmentService.invalid("Chụp 2–10 ảnh khác nhau và xác nhận đã chụp đủ khu vực khách yêu cầu.");
  for(String image:body.images())com.taskly.task.TaskActivityController.validateImage(image);
  for(String image:body.images())db.update("INSERT INTO task_messages(id,task_id,sender_id,content,image_data,sender_portal) VALUES(?,?,?,?,?,'PARTNER')",UUID.randomUUID(),task,user,"Ảnh xác nhận khu vực đã hoàn thành theo yêu cầu khách hàng",image);
  return progressJob(user,task,new JobStatus("IN_PROGRESS","COMPLETED",body.requestId()));
 }
 public record AppealDecision(@NotBlank @Pattern(regexp="REOPEN|DECLINE") String action,@NotBlank @Size(max=1000) String reason) {}
 public record OfficeReopen(@PositiveOrZero long version,@NotBlank @Size(max=100) String requestId,@NotBlank @Size(max=1000) String reason) {}
 @Transactional public RecruitmentDtos.Application reopenAtOffice(UUID actor,UUID id,OfficeReopen w){
  UUID user=db.queryForObject("SELECT user_id FROM partner_applications WHERE id=?",UUID.class,id);
  var a=recruitment.current(user);
  String hash=RecruitmentService.hash(id+":"+w.toString());
  var prior=db.queryForList("SELECT payload_hash FROM recruitment_requests WHERE actor_id=? AND request_key=?",String.class,actor,w.requestId());
  if(!prior.isEmpty()){if(!prior.getFirst().equals(hash))throw RecruitmentService.conflict();return recruitment.detail(id);}
  if(a.version()!=w.version())throw RecruitmentService.conflict();
  if(!"REJECTED".equals(a.status()))throw RecruitmentService.invalid("Chỉ mở lại hồ sơ đã bị từ chối khi Partner đến văn phòng.");
  var now=Timestamp.from(Instant.now());
  db.update("UPDATE partner_applications SET status='PRELIMINARY_REVIEW',preliminary_approved=false,final_approved=false,activated_at=NULL,editable_until=CURRENT_TIMESTAMP,reason=?,version=version+1,updated_at=? WHERE id=?",w.reason(),now,id);
  db.update("UPDATE partner_appeals SET status='REOPENED' WHERE application_id=? AND status='OPEN'",id);
  db.update("INSERT INTO recruitment_requests VALUES(?,?,?,?,?)",actor,w.requestId(),hash,id,now);
  recruitment.audit(actor,id,"OFFICE_REVIEW_REOPENED",a.status(),"PRELIMINARY_REVIEW",w.reason());
  review.notify(id,"Hồ sơ được tiếp nhận xét duyệt lại",w.reason()+" Admin đang kiểm tra hồ sơ sau khi bạn đến văn phòng. Bạn chưa được kích hoạt nhận việc.");
  return recruitment.detail(id);
 }
 public List<Map<String,Object>> appeals(){return db.queryForList("SELECT p.id,p.application_id,p.reason,p.status,p.created_at,a.full_name,a.status AS application_status FROM partner_appeals p JOIN partner_applications a ON a.id=p.application_id ORDER BY p.created_at DESC LIMIT 200");}
 @Transactional public RecruitmentDtos.Application resolveAppeal(UUID actor,UUID id,AppealDecision w){
  var rows=db.queryForList("SELECT p.application_id,a.user_id FROM partner_appeals p JOIN partner_applications a ON a.id=p.application_id WHERE p.id=?",id);
  if(rows.isEmpty())throw new DomainException("APPEAL_NOT_FOUND","Không tìm thấy đề nghị.",HttpStatus.NOT_FOUND);
  UUID user=(UUID)rows.getFirst().get("user_id");var a=recruitment.current(user);
  String status=db.queryForObject("SELECT status FROM partner_appeals WHERE id=? FOR UPDATE",String.class,id);
  if(!"OPEN".equals(status))throw RecruitmentService.conflict();
  if(!Set.of("REJECTED","SUSPENDED").contains(a.status()))throw RecruitmentService.invalid("Hồ sơ đã chuyển bước, cần tải lại.");
  String next=w.action().equals("REOPEN")?"PRELIMINARY_REVIEW":a.status();
  String reason=w.reason().replaceAll("[0-9]{8,}","[đã ẩn]").replaceAll("[^\\s]+@[^\\s]+","[email đã ẩn]");
  db.update("UPDATE partner_appeals SET status=? WHERE id=?",w.action().equals("REOPEN")?"REOPENED":"DECLINED",id);
  if(w.action().equals("REOPEN"))db.update("UPDATE partner_applications SET status=?,preliminary_approved=false,final_approved=false,reason=?,version=version+1,updated_at=? WHERE id=?",next,reason,Timestamp.from(Instant.now()),a.id());
  recruitment.audit(actor,a.id(),"APPEAL_"+w.action(),a.status(),next,reason);review.notify(a.id(),"Kết quả đề nghị xem xét lại",reason);return recruitment.detail(a.id());
 }
 private final JdbcTemplate db;private final RecruitmentService recruitment;private final RecruitmentReviewService review;private final RecruitmentSlaService slaService;private final PartnerSchedulingService schedulingService;
 public RecruitmentActivationService(JdbcTemplate db,RecruitmentService recruitment,RecruitmentReviewService review,RecruitmentSlaService slaService,PartnerSchedulingService schedulingService){this.db=db;this.recruitment=recruitment;this.review=review;this.slaService=slaService;this.schedulingService=schedulingService;}
 private boolean ready(RecruitmentDtos.Application a){return List.of("preliminary_approved","uniform_resolved","appointment_checked_in","documents_valid","agreements_current").stream().allMatch(k->Boolean.TRUE.equals(a.eligibility().get(k)))&&a.documentsReceivedAt()!=null;}
 @Transactional public RecruitmentDtos.Application finalDecision(UUID actor,UUID id,RecruitmentReviewService.Decision w){
  var user=db.queryForObject("SELECT user_id FROM partner_applications WHERE id=?",UUID.class,id);var a=recruitment.current(user);
  String hash=RecruitmentService.hash(id+":"+w.toString());var prior=db.queryForList("SELECT payload_hash FROM recruitment_requests WHERE actor_id=? AND request_key=?",String.class,actor,w.requestId());if(!prior.isEmpty()){if(!prior.getFirst().equals(hash))throw RecruitmentService.conflict();return recruitment.detail(id);}
  if(a.version()!=w.version())throw RecruitmentService.conflict();
  if(w.action().equals("APPROVE_FINAL") && Boolean.TRUE.equals(a.eligibility().get("preliminary_approved")) && Boolean.TRUE.equals(a.eligibility().get("appointment_checked_in")) && Boolean.TRUE.equals(a.eligibility().get("uniform_resolved")) && Set.of("PRELIMINARY_APPROVED","UNIFORM_PENDING","DOCUMENT_APPOINTMENT","DOCUMENTS_RECEIVED","FINAL_REVIEW").contains(a.status())) {
   db.update("UPDATE partner_applications SET documents_valid=true,documents_received_at=COALESCE(documents_received_at,CURRENT_TIMESTAMP),status='FINAL_REVIEW' WHERE id=?",id);
   db.update("UPDATE partner_uniform_orders SET status='HANDED_OVER',handed_over_at=COALESCE(handed_over_at,CURRENT_TIMESTAMP) WHERE application_id=? AND payment_status IN ('PAID','WAIVED') AND status NOT IN ('CANCELLED','REFUNDED')",id);
   recruitment.audit(actor,id,"OFFICE_FINAL_CONFIRMATION",a.status(),"FINAL_REVIEW","Admin xác nhận hoàn tất thủ tục tại văn phòng khi duyệt chính thức.");
   a=recruitment.detail(id);
  }
  if(w.action().equals("SUSPEND")){if(!a.status().equals("ACTIVE"))throw RecruitmentService.invalid("Chỉ tạm ngưng tài khoản ACTIVE.");}
  else if(!Set.of("DOCUMENTS_RECEIVED","FINAL_REVIEW").contains(a.status()))throw RecruitmentService.invalid("Hồ sơ chưa ở bước duyệt cuối.");
  if(w.action().equals("APPROVE_FINAL")&&(!ready(a)||!review.agreementsReady(user)||!review.identityReady(user)||!review.trainingReady(user)))throw RecruitmentService.invalid("Cần đủ hồ sơ hợp lệ, check-in và thanh toán đồng phục.");
  String next=switch(w.action()){case "APPROVE_FINAL"->db.queryForObject("SELECT COUNT(*) FROM partner_final_documents WHERE application_id=?",Integer.class,id)>0?"ACTIVE":"APPROVED";case "REQUEST_CHANGES"->"ACTION_REQUIRED";case "REJECT_WITH_REASON"->"REJECTED";case "ESCALATE"->"ESCALATED";case "SUSPEND"->"SUSPENDED";default->throw RecruitmentService.invalid("Quyết định không hợp lệ.");};
  if(next.equals("ACTION_REQUIRED")&&w.requiredChanges().isEmpty())throw RecruitmentService.invalid("Chỉ rõ phần hồ sơ cần bổ sung.");
  String reason=w.reason().replaceAll("[0-9]{8,}","[đã ẩn]").replaceAll("[^\\s]+@[^\\s]+","[email đã ẩn]");
  var json=new tools.jackson.databind.ObjectMapper();
  db.update("UPDATE partner_applications SET status=?,final_approved=?,reason=?,required_changes=?,version=version+1,updated_at=? WHERE id=?",next,next.equals("ACTIVE"),reason,json.writeValueAsString(w.requiredChanges()),Timestamp.from(Instant.now()),id);
  if(next.equals("ACTIVE"))db.update("UPDATE partner_applications SET activated_at=CURRENT_TIMESTAMP,skills_configured=true,areas_configured=true WHERE id=?",id);
  db.update("INSERT INTO partner_review_decisions VALUES(?,?,'FINAL',?,?,?,?,?)",UUID.randomUUID(),id,w.action(),actor,reason,json.writeValueAsString(w.requiredChanges()),Timestamp.from(Instant.now()));db.update("INSERT INTO recruitment_requests VALUES(?,?,?,?,?)",actor,w.requestId(),hash,id,Timestamp.from(Instant.now()));recruitment.audit(actor,id,"FINAL_"+w.action(),a.status(),next,reason);review.notify(id,w.action().equals("APPROVE_FINAL")?"Chúc mừng! Bạn đã được duyệt chính thức":"Kết quả xét duyệt cuối",w.action().equals("APPROVE_FINAL")?"Chào mừng bạn trở thành đối tác TaskLy! "+reason+" Vui lòng kiểm tra trạng thái chặng 4: bổ sung ảnh chân dung và hợp đồng nếu chưa gửi. Chỉ tài khoản ACTIVE mới được nhận việc.":reason);return recruitment.detail(id);
 }
 @Transactional public RecruitmentDtos.Application activate(UUID user,Activation w){var a=recruitment.current(user);if(a.version()!=w.version())throw RecruitmentService.conflict();if(!a.status().equals("APPROVED")||!ready(a)||!a.eligibility().get("final_approved")||!review.agreementsReady(user)||!review.identityReady(user)||!review.trainingReady(user))throw RecruitmentService.invalid("Chưa được duyệt chính thức để kích hoạt.");if(a.areaIds().isEmpty()||a.serviceIds().isEmpty()||!w.endsAt().isAfter(w.startsAt())||!w.endsAt().isAfter(Instant.now())||Duration.between(w.startsAt(),w.endsAt()).toDays()>30)throw RecruitmentService.invalid("Chọn kỹ năng, khu vực và lịch rảnh hợp lệ tối đa 30 ngày.");db.update("DELETE FROM partner_availability WHERE application_id=?",a.id());db.update("INSERT INTO partner_availability VALUES(?,?,?)",a.id(),Timestamp.from(w.startsAt()),Timestamp.from(w.endsAt()));var now=Timestamp.from(Instant.now());db.update("UPDATE partner_applications SET status='ACTIVE',skills_configured=true,areas_configured=true,availability_configured=true,activated_at=?,updated_at=?,version=version+1 WHERE id=?",now,now,a.id());recruitment.audit(user,a.id(),"PARTNER_ACTIVATED","APPROVED","ACTIVE","");return recruitment.current(user);}
 @Transactional public RecruitmentDtos.Application appeal(UUID user,Appeal w){var a=recruitment.current(user);if(!Set.of("REJECTED","SUSPENDED").contains(a.status()))throw RecruitmentService.invalid("Hồ sơ không ở trạng thái cần đề nghị xem xét lại.");if(db.queryForObject("SELECT COUNT(*) FROM partner_appeals WHERE application_id=? AND status='OPEN'",Integer.class,a.id())>0)throw RecruitmentService.invalid("Đã có đề nghị đang xử lý.");db.update("INSERT INTO partner_appeals VALUES(?,?,?,'OPEN',?)",UUID.randomUUID(),a.id(),w.reason(),Timestamp.from(Instant.now()));recruitment.audit(user,a.id(),"APPEAL_CREATED",a.status(),a.status(),"Đề nghị xem xét lại");return a;}
 private RecruitmentDtos.Application eligible(UUID user){var a=recruitment.current(user);if(!a.status().equals("ACTIVE")||!ready(a)||!review.identityReady(user)||!review.trainingReady(user)||!review.agreementsReady(user)||!List.of("final_approved","skills_configured","areas_configured").stream().allMatch(k->a.eligibility().get(k)))throw new DomainException("PARTNER_NOT_ACTIVE","Chỉ Tasker ACTIVE đủ điều kiện được xem và nhận việc.",HttpStatus.FORBIDDEN);return a;}
 private Instant time(Object value){if(value instanceof OffsetDateTime d)return d.toInstant();if(value instanceof Timestamp t)return t.toInstant();if(value instanceof Instant i)return i;throw new IllegalStateException("Unexpected database time type");}
 @Transactional public List<Map<String,Object>> feed(UUID user){
  var a=eligible(user);
  Instant windowStart=Instant.now().minus(Duration.ofHours(4));
  String feeSql=com.taskly.task.PartnerEarnings.FEE_SQL;
  String query="SELECT t.id,t.title,t.description,t.city_snapshot,t.scheduled_at,t.estimated_duration_minutes,t.latitude,t.longitude,t.budget_amount,t.currency, "
      + feeSql + " AS platform_fee, "
      + "(t.budget_amount - " + feeSql + ") AS partner_net_amount "
      + "FROM tasks t "
      + "LEFT JOIN service_pricing_rules r ON r.service_id = t.service_id "
      + "WHERE t.status IN ('POSTED','MATCHING') "
      + "  AND t.tasker_id IS NULL "
      + "  AND t.service_id IN (SELECT service_id FROM partner_application_services WHERE application_id = ?) "
      + "  AND ( "
      + "    t.city_snapshot IN (SELECT r.city FROM recruitment_areas r JOIN partner_application_areas pa ON pa.area_id = r.id WHERE pa.application_id = ?) "
      + "    OR EXISTS ( "
      + "      SELECT 1 FROM recruitment_areas r JOIN partner_application_areas pa ON pa.area_id = r.id "
      + "      WHERE pa.application_id = ? "
      + "        AND ( "
      + "          LOWER(TRIM(r.city)) = LOWER(TRIM(t.city_snapshot)) "
      + "          OR (LOWER(r.city) LIKE '%hồ chí minh%' AND LOWER(t.city_snapshot) LIKE '%hồ chí minh%') "
      + "          OR (LOWER(r.city) LIKE '%hà nội%' AND LOWER(t.city_snapshot) LIKE '%hà nội%') "
      + "          OR (LOWER(r.city) LIKE '%đà nẵng%' AND LOWER(t.city_snapshot) LIKE '%đà nẵng%') "
      + "        ) "
      + "    ) "
      + "  ) "
      + "  AND (t.expires_at IS NULL OR t.expires_at > CURRENT_TIMESTAMP) "
      + "  AND NOT EXISTS ( "
      + "    SELECT 1 FROM task_booking_services bs "
      + "    WHERE bs.task_id = t.id AND bs.service_id NOT IN (SELECT service_id FROM partner_application_services WHERE application_id = ?) "
      + "  ) "
      + "  AND (t.scheduled_at >= ? OR (t.expires_at IS NOT NULL AND t.expires_at > CURRENT_TIMESTAMP)) "
      + "ORDER BY t.scheduled_at ASC LIMIT 100";
  var rows=db.queryForList(query, a.id(), a.id(), a.id(), a.id(), Timestamp.from(windowStart));
  var list=new ArrayList<Map<String,Object>>();
  for(var row:rows){
   var map=new LinkedHashMap<String,Object>(row);
   Instant start=time(map.get("scheduled_at"));
   int duration=((Number)map.get("estimated_duration_minutes")).intValue();
   BigDecimal lat=(BigDecimal)map.get("latitude");
   BigDecimal lng=(BigDecimal)map.get("longitude");
   var val=schedulingService.validateSchedule(user,(UUID)map.get("id"),start,duration,lat,lng);
   map.put("eligible",val.eligible());
   map.put("reasonCode",val.reasonCode());
   map.put("reasonMessage",val.message());
   map.put("statusTag",val.eligible()?"ELIGIBLE":val.reasonCode());
   map.put("statusTagLabel",val.eligible()?"Có thể nhận":("PARTNER_DAILY_LIMIT".equals(val.reasonCode())?"Đủ 3 lịch hôm nay":("PARTNER_ADVANCE_LIMIT".equals(val.reasonCode())?"Đã có lịch đặt trước":("SCHEDULE_CONFLICT".equals(val.reasonCode())?"Trùng lịch":"Thiếu buffer"))));
   map.put("earliestEligibleStartAt",val.earliestEligibleStartAt());
   map.put("requiredBufferMinutes",val.requiredBufferMinutes());
   map.put("scheduled_end_at",start.plusSeconds(duration*60L));
   list.add(map);
  }
  return list;
 }
 @Transactional public Map<String,Object> accept(UUID user,UUID task){
  com.taskly.task.PartnerWorkPolicy.lock(db,user);
  var previous=db.queryForList("SELECT id,status FROM tasks WHERE id=? AND tasker_id=?",task,user);
  if(!previous.isEmpty())return previous.getFirst();
  com.taskly.task.PartnerAcceptanceBalance.require(db,user);
  var appRows=db.queryForList("SELECT id,status FROM partner_applications WHERE user_id=? FOR UPDATE",user);
  if(appRows.isEmpty())throw new DomainException("PARTNER_NOT_FOUND","Không tìm thấy hồ sơ đối tác.",HttpStatus.FORBIDDEN);
  var a=eligible(user);
  if(db.queryForObject("SELECT COUNT(*) FROM partner_bank_accounts WHERE user_id=?",Integer.class,user)==0)throw RecruitmentService.invalid("Vui lòng thêm ngân hàng trước khi nhận việc.");
  var taskRows=db.queryForList("SELECT t.id,t.status,t.tasker_id,t.scheduled_at,t.estimated_duration_minutes,t.latitude,t.longitude,t.expires_at,t.service_id,t.city_snapshot,t.service_name_snapshot,t.customer_id FROM tasks t WHERE t.id=? FOR UPDATE",task);
  if(taskRows.isEmpty())throw new DomainException("TASK_NOT_FOUND","Không tìm thấy công việc.",HttpStatus.NOT_FOUND);
  var candidate=taskRows.getFirst();
  UUID currentTasker=(UUID)candidate.get("tasker_id");
  if(currentTasker!=null){
   if(currentTasker.equals(user))return Map.of("id",task,"status",candidate.get("status"));
   throw new DomainException("JOB_ALREADY_ASSIGNED","Công việc này đã được đối tác khác tiếp nhận.",HttpStatus.CONFLICT);
  }
  String currentStatus=(String)candidate.get("status");
  if(Set.of("CANCELLED","REFUNDED","EXPIRED").contains(currentStatus))throw new DomainException("TASK_NOT_AVAILABLE","Dịch vụ không còn nữa. Vui lòng tìm dịch vụ khác.",HttpStatus.CONFLICT);
  if(!Set.of("POSTED","MATCHING").contains(currentStatus))throw new DomainException("JOB_ALREADY_ASSIGNED","Công việc không còn ở trạng thái có thể nhận.",HttpStatus.CONFLICT);
  Object rawExpires=candidate.get("expires_at");
  if(rawExpires!=null&&time(rawExpires).isBefore(Instant.now()))throw new DomainException("UNAVAILABLE_SLOT","Công việc đã hết hạn nhận.",HttpStatus.CONFLICT);
  UUID serviceId=(UUID)candidate.get("service_id");
  String city=(String)candidate.get("city_snapshot");
  boolean skillMatch=db.queryForObject("SELECT COUNT(*) FROM partner_application_services WHERE application_id=? AND service_id=?",Integer.class,a.id(),serviceId)>0;
  boolean areaMatch=db.queryForObject("""
      SELECT COUNT(*) FROM recruitment_areas r JOIN partner_application_areas pa ON pa.area_id=r.id
      WHERE pa.application_id=? AND (
        r.city=?
        OR LOWER(TRIM(r.city))=LOWER(TRIM(?))
        OR (LOWER(r.city) LIKE '%hồ chí minh%' AND LOWER(?) LIKE '%hồ chí minh%')
        OR (LOWER(r.city) LIKE '%hà nội%' AND LOWER(?) LIKE '%hà nội%')
        OR (LOWER(r.city) LIKE '%đà nẵng%' AND LOWER(?) LIKE '%đà nẵng%')
      )
      """, Integer.class, a.id(), city, city, city, city, city) > 0;
  if(!skillMatch||!areaMatch)throw RecruitmentService.invalid("Công việc không phù hợp kỹ năng hoặc khu vực hoạt động của bạn.");
  Instant scheduledAt=time(candidate.get("scheduled_at"));
  int durationMinutes=((Number)candidate.get("estimated_duration_minutes")).intValue();
  BigDecimal lat=(BigDecimal)candidate.get("latitude");
  BigDecimal lng=(BigDecimal)candidate.get("longitude");
  var validation=schedulingService.validateSchedule(user,task,scheduledAt,durationMinutes,lat,lng);
  if(!validation.eligible()){
   throw new DomainException(validation.reasonCode(),validation.message(),HttpStatus.CONFLICT);
  }
  var now=Timestamp.from(Instant.now());
  var schedStartTs=Timestamp.from(scheduledAt);
  var schedEndTs=Timestamp.from(scheduledAt.plus(java.time.Duration.ofMinutes(durationMinutes)));
  int updated=db.update("UPDATE tasks SET tasker_id=?,status='ACCEPTED',accepted_at=COALESCE(accepted_at,?),original_scheduled_start_at=COALESCE(original_scheduled_start_at,?),original_scheduled_end_at=COALESCE(original_scheduled_end_at,?),expected_end_at=COALESCE(expected_end_at,?),updated_at=?,version=version+1,platform_fee_snapshot=(SELECT "+com.taskly.task.PartnerEarnings.FEE_SQL+" FROM tasks t LEFT JOIN service_pricing_rules r ON r.service_id=t.service_id WHERE t.id=tasks.id) WHERE id=? AND tasker_id IS NULL AND status IN ('POSTED','MATCHING')",user,now,schedStartTs,schedEndTs,schedEndTs,now,task);
  if(updated!=1)throw new DomainException("JOB_ALREADY_ASSIGNED","Công việc này đã được đối tác khác tiếp nhận.",HttpStatus.CONFLICT);
  db.update("INSERT INTO task_status_history(id,task_id,to_status,actor_role,occurred_at) VALUES(?,?,'ACCEPTED','TASKER',?)",UUID.randomUUID(),task,now);
  var partnerName=db.queryForList("SELECT full_name FROM user_profiles WHERE user_id=?",String.class,user).stream().findFirst().orElse("Đối tác TaskLy");
  db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),candidate.get("customer_id"),task,"Đối tác "+partnerName+" đã nhận đơn \""+candidate.get("service_name_snapshot")+"\" của bạn. Vui lòng theo dõi tiến độ.",now);
  db.update("INSERT INTO task_messages(id,task_id,sender_id,content,sender_portal,created_at) VALUES(?,?,?,?,'PARTNER',?)",UUID.randomUUID(),task,user,"Tôi đã nhận đơn dịch vụ của bạn.",now);
  db.update("INSERT INTO partner_notification_outbox(id,application_id,task_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,?,'IN_APP','DELIVERED',?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",UUID.randomUUID(),a.id(),task,"Nhận việc thành công #"+task.toString().substring(0,8).toUpperCase(),"Bạn đã nhận công việc \""+candidate.get("service_name_snapshot")+"\". Vui lòng kiểm tra địa chỉ và di chuyển đúng hẹn.");
  recruitment.audit(user,a.id(),"JOB_ACCEPTED",null,null,"Task "+task);
  return Map.of("id",task,"status","ACCEPTED");
 }
 public Map<String,Object> previewAvailability(UUID user,UUID task){
  var a=eligible(user);
  var taskRows=db.queryForList("SELECT id,scheduled_at,estimated_duration_minutes,latitude,longitude FROM tasks WHERE id=?",task);
  if(taskRows.isEmpty())throw new DomainException("TASK_NOT_FOUND","Không tìm thấy công việc.",HttpStatus.NOT_FOUND);
  var t=taskRows.getFirst();
  Instant start=time(t.get("scheduled_at"));
  int dur=((Number)t.get("estimated_duration_minutes")).intValue();
  BigDecimal lat=(BigDecimal)t.get("latitude");
  BigDecimal lng=(BigDecimal)t.get("longitude");
  var val=schedulingService.validateSchedule(user,task,start,dur,lat,lng);
  var res=new LinkedHashMap<String,Object>();
  res.put("eligible",val.eligible());
  res.put("reasonCode",val.reasonCode());
  res.put("message",val.message());
  res.put("conflictingTaskId",val.conflictingTaskId());
  res.put("earliestEligibleStartAt",val.earliestEligibleStartAt());
  res.put("requiredBufferMinutes",val.requiredBufferMinutes());
  return res;
 }
 public List<Map<String,Object>> timeline(UUID user){eligible(user);return schedulingService.getPartnerTimeline(user);}
 public Map<String,Object> sla(UUID user){return slaService.window(recruitment.current(user).documentsReceivedAt());}
}




