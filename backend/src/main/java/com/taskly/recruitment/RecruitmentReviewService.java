package com.taskly.recruitment;
import com.taskly.common.exception.DomainException;
import jakarta.validation.constraints.*;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

@Service
public class RecruitmentReviewService {
 public record Agreement(UUID id,String documentType,String version,String contentUrl,Instant effectiveAt,boolean accepted) {}
 public record AgreementWrite(@NotBlank @Size(max=40) String documentType,@NotBlank @Size(max=40) String version,@NotBlank @Size(max=500) String contentUrl,@NotNull Instant effectiveAt,boolean active) {}
 public record Decision(@PositiveOrZero long version,@NotBlank @Size(max=100) String requestId,@NotBlank String action,@NotBlank @Size(max=1000) String reason,@NotNull @Size(max=20) List<@NotBlank @Size(max=100) String> requiredChanges,@Min(1) @Max(1440) Integer reviewMinutes) {
  public Decision(long version,String requestId,String action,String reason,List<String> requiredChanges){this(version,requestId,action,reason,requiredChanges,null);}
 }
 private static final Set<String> DOC_TYPES=Set.of("PARTNER_CONDUCT","PARTNER_SAFETY","PARTNER_COOPERATION","PARTNER_PRIVACY","PARTNER_UNIFORM");
 private final JdbcTemplate db;private final RecruitmentService recruitment;private final RecruitmentTrainingService training;private final ObjectMapper json=new ObjectMapper();
 private final Clock clock;
 @org.springframework.beans.factory.annotation.Value("${app.environment:production}") private String environment;
 @org.springframework.beans.factory.annotation.Autowired private com.taskly.user.UserService users;
 @jakarta.persistence.PersistenceContext private jakarta.persistence.EntityManager entities;
 @org.springframework.beans.factory.annotation.Autowired @org.springframework.context.annotation.Lazy private com.taskly.verification.VerificationService verification;
 public RecruitmentReviewService(JdbcTemplate db,RecruitmentService recruitment,RecruitmentTrainingService training,Clock clock){this.db=db;this.recruitment=recruitment;this.training=training;this.clock=clock;}
 @Transactional public RecruitmentDtos.Application demoIdentity(UUID user){
  if(!Set.of("development","dev","local","test").contains(environment))throw RecruitmentService.invalid("Hồ sơ định danh DEMO chỉ bật trong development/test.");
  var app=recruitment.current(user);if(!Set.of("PROFILE_INCOMPLETE","ACTION_REQUIRED").contains(app.status())||!agreementsReady(user))throw RecruitmentService.invalid("Hoàn tất cam kết trước khi tạo hồ sơ mẫu.");
  users.enableTasker(user);
  if(db.queryForObject("SELECT COUNT(*) FROM identity_verifications WHERE user_id=? AND status IN ('SUBMITTED','UNDER_REVIEW','APPROVED')",Integer.class,user)==0){var id=UUID.randomUUID();var now=Timestamp.from(Instant.now());db.update("INSERT INTO identity_verifications(id,user_id,status,legal_name,document_type,document_number_masked,consent_accepted_at,submitted_at,created_at,updated_at) VALUES(?,?,'SUBMITTED',?,'DEMO','KHÔNG CÓ GIẤY TỜ THẬT',?,?,?,?)",id,user,"Ứng viên mẫu DEMO",now,now,now,now);db.update("INSERT INTO verification_history(id,verification_id,to_status,actor_id,reason,created_at) VALUES(?,?,'SUBMITTED',?,'DEMO metadata only; no identity evidence',?)",UUID.randomUUID(),id,user,now);recruitment.audit(user,app.id(),"DEMO_IDENTITY_SUBMITTED",app.status(),app.status(),"DEMO: không có giấy tờ thật");}
  return submitProfile(user);
 }
 public List<Agreement> agreements(UUID user){return db.query("SELECT t.* FROM terms_versions t WHERE document_type LIKE 'PARTNER_%' AND active=true AND effective_at<=? ORDER BY document_type,effective_at DESC",(r,n)->new Agreement(r.getObject("id",UUID.class),r.getString("document_type"),r.getString("version"),r.getString("content_url"),r.getTimestamp("effective_at").toInstant(),db.queryForObject("SELECT COUNT(*) FROM user_consents WHERE user_id=? AND terms_version_id=?",Integer.class,user,r.getObject("id",UUID.class))>0),Timestamp.from(Instant.now()));}
 boolean agreementsReady(UUID user){var docs=agreements(user);return docs.stream().map(Agreement::documentType).collect(java.util.stream.Collectors.toSet()).containsAll(DOC_TYPES)&&docs.stream().allMatch(Agreement::accepted);}
 boolean identityReady(UUID user){entities.flush();return db.queryForObject("SELECT COUNT(*) FROM identity_verifications WHERE user_id=? AND status='APPROVED' AND (document_type<>'DEMO' OR ?)",Integer.class,user,Set.of("development","dev","local","test").contains(environment))>0;}
 boolean trainingReady(UUID user){
  return Boolean.TRUE.equals(recruitment.current(user).eligibility().get("exam_passed"));
 }
 @Transactional public Agreement saveAgreement(UUID actor,UUID id,AgreementWrite w){
  if(!DOC_TYPES.contains(w.documentType()))throw RecruitmentService.invalid("Loại tài liệu Partner không hợp lệ.");
  var uri=java.net.URI.create(w.contentUrl());if(!"https".equals(uri.getScheme())||uri.getHost()==null||uri.getUserInfo()!=null)throw RecruitmentService.invalid("Tài liệu cần URL HTTPS hợp lệ.");
  // Immutable version: create a new terms version rather than editing consent evidence.
  if(db.queryForObject("SELECT COUNT(*) FROM terms_versions WHERE id=? OR (document_type=? AND version=?)",Integer.class,id,w.documentType(),w.version())>0)throw RecruitmentService.invalid("Phiên bản tài liệu đã tồn tại. Tạo phiên bản mới.");
  if(w.active()&&!w.effectiveAt().isAfter(Instant.now()))db.update("UPDATE terms_versions SET active=false WHERE document_type=?",w.documentType());
  db.update("INSERT INTO terms_versions VALUES(?,?,?,?,?,true,?,?)",id,w.documentType(),w.version(),w.contentUrl(),Timestamp.from(w.effectiveAt()),w.active(),Timestamp.from(Instant.now()));
  recruitment.audit(actor,null,"PARTNER_AGREEMENT_CREATED",null,null,w.documentType()+" v"+w.version());return new Agreement(id,w.documentType(),w.version(),w.contentUrl(),w.effectiveAt(),false);
 }
 @Transactional public RecruitmentDtos.Application accept(UUID user,UUID id){
  var app=recruitment.current(user);
  if(agreements(user).stream().noneMatch(a->a.id().equals(id)))throw RecruitmentService.invalid("Tài liệu chưa có hiệu lực.");
  if(db.queryForObject("SELECT COUNT(*) FROM user_consents WHERE user_id=? AND terms_version_id=?",Integer.class,user,id)==0)db.update("INSERT INTO user_consents(id,user_id,terms_version_id,accepted_at) VALUES(?,?,?,?)",UUID.randomUUID(),user,id,Timestamp.from(Instant.now()));
  boolean ready=agreementsReady(user);db.update("UPDATE partner_applications SET agreements_current=?,status=?,version=version+1,updated_at=? WHERE id=?",ready,ready&&app.status().equals("AGREEMENT_REQUIRED")?"PROFILE_INCOMPLETE":app.status(),Timestamp.from(Instant.now()),app.id());
  recruitment.audit(user,app.id(),"AGREEMENT_ACCEPTED",app.status(),ready?"PROFILE_INCOMPLETE":app.status(),"Phiên bản "+id);return recruitment.current(user);
 }
 @Transactional public RecruitmentDtos.Application acceptAll(UUID user){
  var list=agreements(user);
  if(!list.stream().map(Agreement::documentType).collect(java.util.stream.Collectors.toSet()).containsAll(DOC_TYPES))throw RecruitmentService.invalid("Chưa cấu hình đủ cam kết Partner hiện hành.");
  for(var a:list){
   if(!a.accepted()){
    accept(user,a.id());
   }
  }
  return recruitment.current(user);
 }
 @Transactional public RecruitmentDtos.Application submitProfile(UUID user){
  var a=recruitment.current(user);
  if(a.status().equals("PRELIMINARY_REVIEW")) return a; // Retrying never extends the first submission window.
  if(!Set.of("PROFILE_INCOMPLETE","ACTION_REQUIRED").contains(a.status()))throw RecruitmentService.invalid("Hồ sơ chưa ở bước có thể nộp.");
  if(a.status().equals("ACTION_REQUIRED")&&Boolean.TRUE.equals(a.eligibility().get("preliminary_approved")))throw RecruitmentService.invalid("Hồ sơ đã duyệt sơ bộ cần đặt lịch tiếp nhận bổ sung tại văn phòng.");
  if(!a.eligibility().get("exam_passed")||!agreementsReady(user)||training.progress(user).stream().anyMatch(p->p.lesson().required()&&!p.status().equals("COMPLETED")))throw RecruitmentService.invalid("Hoàn tất bài thi, Academy và cam kết hiện hành.");
  if(db.queryForObject("SELECT COUNT(*) FROM identity_verifications WHERE user_id=? AND status IN ('SUBMITTED','UNDER_REVIEW','APPROVED')",Integer.class,user)==0)throw RecruitmentService.invalid("Nộp hồ sơ định danh qua chức năng xác minh trước.");
  var now=clock.instant();
  db.update("UPDATE partner_applications SET first_submitted_at=COALESCE(first_submitted_at,?),editable_until=?,profile_complete=true,agreements_current=true,status='PRELIMINARY_REVIEW',reason='',required_changes='[]',version=version+1,updated_at=? WHERE id=?",Timestamp.from(now),null,Timestamp.from(now),a.id());recruitment.audit(user,a.id(),"PROFILE_SUBMITTED",a.status(),"PRELIMINARY_REVIEW","");return recruitment.current(user);
 }
 @Transactional public RecruitmentDtos.Application preliminary(UUID actor,UUID id,Decision w){
  var user=db.queryForObject("SELECT user_id FROM partner_applications WHERE id=?",UUID.class,id);var a=recruitment.current(user);
  String signature=RecruitmentService.hash(id+":"+json.writeValueAsString(w));var prior=db.queryForList("SELECT payload_hash FROM recruitment_requests WHERE actor_id=? AND request_key=?",String.class,actor,w.requestId());
  if(!prior.isEmpty()){if(!signature.equals(prior.getFirst()))throw RecruitmentService.conflict();return recruitment.detail(id);}
  if(a.version()!=w.version())throw RecruitmentService.conflict();if(!Set.of("PRELIMINARY_REVIEW","ESCALATED").contains(a.status()))throw RecruitmentService.invalid("Hồ sơ chưa chờ duyệt sơ bộ.");
  recruitment.requireReviewReady(a);
  String next=switch(w.action()){case "APPROVE_PRELIMINARY"->"PRELIMINARY_APPROVED";case "REQUEST_CHANGES"->"ACTION_REQUIRED";case "REJECT_WITH_REASON"->"REJECTED";case "ESCALATE","EXTEND_REVIEW"->"ESCALATED";default->throw RecruitmentService.invalid("Quyết định không hợp lệ.");};
  if(next.equals("ACTION_REQUIRED")&&w.requiredChanges().isEmpty())throw RecruitmentService.invalid("Chỉ rõ từng mục cần bổ sung.");
  if(next.equals("PRELIMINARY_APPROVED")) {
   if(!agreementsReady(user))throw RecruitmentService.invalid("Hoàn tất cam kết hiện hành trước khi duyệt sơ bộ.");
   var latest=verification.current(user);
   if(latest==null)throw RecruitmentService.invalid("Chưa có hồ sơ CCCD để xác minh.");
   if(latest.status()!=com.taskly.verification.entity.VerificationStatus.APPROVED) {
    var auth=org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
    if(auth==null||auth.getAuthorities().stream().noneMatch(authority->authority.getAuthority().equals("KYC_REVIEW")))throw RecruitmentService.invalid("Cần quyền xác minh CCCD để phê duyệt hồ sơ chưa được xác minh.");
    verification.decide(actor,latest.id(),com.taskly.verification.entity.VerificationStatus.APPROVED,w.reason());
   }
   if(!identityReady(user))throw RecruitmentService.invalid("CCCD chưa đủ điều kiện xác minh.");
  }
  String reason=redact(w.reason());
  if(next.equals("ACTION_REQUIRED") && w.requiredChanges().stream().anyMatch(item->item.toLowerCase(Locale.ROOT).contains("cccd")||item.toLowerCase(Locale.ROOT).contains("định danh")||item.toLowerCase(Locale.ROOT).contains("chân dung"))) {
   entities.flush();
   db.update("UPDATE identity_verifications SET status='SUBMITTED',reviewed_by=NULL,reviewed_at=NULL,decision_reason=?,version=version+1,updated_at=? WHERE id=(SELECT id FROM identity_verifications WHERE user_id=? ORDER BY created_at DESC,id DESC LIMIT 1) AND status IN ('APPROVED','UNDER_REVIEW','SUBMITTED')",reason,Timestamp.from(clock.instant()),user);
   entities.clear();
  }
  if(w.action().equals("EXTEND_REVIEW")){if(w.reviewMinutes()==null||w.reviewMinutes()<1||w.reviewMinutes()>1440)throw RecruitmentService.invalid("Nhập thời gian xem xét từ 1 đến 1440 phút.");var deadline=clock.instant().plus(Duration.ofMinutes(w.reviewMinutes()));db.update("UPDATE partner_applications SET editable_until=? WHERE id=?",Timestamp.from(deadline),id);reason=reason.substring(0,Math.min(850,reason.length()))+" Thêm "+w.reviewMinutes()+" phút xem xét, dự kiến phản hồi trước "+deadline.atZone(ZoneId.of("Asia/Ho_Chi_Minh")).format(java.time.format.DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy"))+" (giờ Việt Nam).";}
  db.update("UPDATE partner_applications SET status=?,preliminary_approved=?,reason=?,required_changes=?,version=version+1,updated_at=? WHERE id=?",next,next.equals("PRELIMINARY_APPROVED"),reason,json.writeValueAsString(w.requiredChanges()),Timestamp.from(Instant.now()),id);
  db.update("INSERT INTO partner_review_decisions VALUES(?,?,'PRELIMINARY',?,?,?,?,?)",UUID.randomUUID(),id,w.action(),actor,reason,json.writeValueAsString(w.requiredChanges()),Timestamp.from(Instant.now()));
  db.update("INSERT INTO recruitment_requests VALUES(?,?,?,?,?)",actor,w.requestId(),signature,id,Timestamp.from(Instant.now()));
  recruitment.audit(actor,id,"PRELIMINARY_"+w.action(),a.status(),next,reason);notify(id,"Kết quả xét duyệt hồ sơ",next.equals("ACTION_REQUIRED")?reason+" Cần bổ sung: "+String.join(", ",w.requiredChanges()):reason);return recruitment.detail(id);
 }
 private String redact(String text){return text.replaceAll("[0-9]{8,}","[đã ẩn]").replaceAll("[^\\s]+@[^\\s]+","[email đã ẩn]");}
 void notify(UUID app,String title,String message){
  String event=title.equals("Chào mừng Partner đến văn phòng!")?"OFFICE_CHECKED_IN":title.equals("Bạn đã nhận đồng phục TaskLy!")?"UNIFORM_HANDED_OVER":title.equals("Chúc mừng! Bạn đã được duyệt chính thức")?"FINAL_APPROVED":title.equals("Biên nhận hồ sơ")?"DOCUMENT_RECEIPT":title.equals("Kết quả đề nghị xem xét lại")?"APPEAL_RESULT":"REVIEW_RESULT";
  var templates=db.queryForList("SELECT title,body FROM partner_message_templates WHERE event_key=? AND active=true",event);
  String safe=redact(message),subject=title,body=safe;
  if(!templates.isEmpty()){var template=templates.getFirst();subject=String.valueOf(template.get("title")).replace("{title}",title).replace("{message}",safe);body=String.valueOf(template.get("body")).replace("{title}",title).replace("{message}",safe);}
  subject=subject.substring(0,Math.min(200,subject.length()));body=body.substring(0,Math.min(2000,body.length()));
  for(String channel:List.of("IN_APP","EMAIL"))db.update("INSERT INTO partner_notification_outbox(id,application_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,?,?,?,?,?,?)",UUID.randomUUID(),app,channel,channel.equals("IN_APP")?"DELIVERED":"SIMULATED",subject,body,Timestamp.from(Instant.now()),channel.equals("IN_APP")?Timestamp.from(Instant.now()):null);
 }
 public record ReadNotifications(@jakarta.validation.constraints.NotEmpty @jakarta.validation.constraints.Size(max=1000) List<UUID> ids) {}
 @Transactional public Map<String,Object> markNotificationsRead(UUID user,ReadNotifications request){var app=recruitment.current(user);for(var id:request.ids())db.update("UPDATE partner_notification_outbox SET read_at=COALESCE(read_at,CURRENT_TIMESTAMP) WHERE id=? AND application_id=? AND channel='IN_APP'",id,app.id());return Map.of("updated",true);}
 @Transactional public Map<String,Object> markAllNotificationsRead(UUID user){var app=recruitment.current(user);db.update("UPDATE partner_notification_outbox SET read_at=COALESCE(read_at,CURRENT_TIMESTAMP) WHERE application_id=? AND channel='IN_APP' AND read_at IS NULL",app.id());return Map.of("updated",true);}
 @Transactional public Map<String,Object> markSingleNotificationRead(UUID user,UUID notificationId){var app=recruitment.current(user);db.update("UPDATE partner_notification_outbox SET read_at=COALESCE(read_at,CURRENT_TIMESTAMP) WHERE id=? AND application_id=? AND channel='IN_APP'",notificationId,app.id());return Map.of("updated",true);}
 @Transactional public void seedPartnerNotifications(UUID user,UUID appId){
  var tasks=db.queryForList("SELECT id,service_name_snapshot,status,budget_amount FROM tasks WHERE tasker_id=? ORDER BY created_at DESC LIMIT 5",user);
  for(var t:tasks){
   UUID tid=(UUID)t.get("id");
   String sName=String.valueOf(t.get("service_name_snapshot"));
   String st=String.valueOf(t.get("status"));
   db.update("INSERT INTO partner_notification_outbox(id,application_id,task_id,channel,status,title,message,created_at,delivered_at,read_at) VALUES(?,?,?,'IN_APP','DELIVERED',?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",
     UUID.randomUUID(),appId,tid,"Nhận việc: "+sName+" #"+tid.toString().substring(0,8).toUpperCase(),"Bạn đã được phân công thực hiện công việc "+sName+".");
   if("COMPLETED".equals(st)){
    long budget=((Number)t.get("budget_amount")).longValue();
    db.update("INSERT INTO partner_notification_outbox(id,application_id,task_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,?,'IN_APP','DELIVERED',?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",
      UUID.randomUUID(),appId,tid,"Hoàn tất công việc #"+tid.toString().substring(0,8).toUpperCase(),"Bạn đã hoàn thành dịch vụ "+sName+". Thu nhập ước tính "+String.format("%,d",budget)+"đ đã ghi nhận vào ví đối tác.");
   }
  }
  var count=db.queryForObject("SELECT COUNT(*) FROM partner_notification_outbox WHERE application_id=? AND channel='IN_APP'",Integer.class,appId);
  if(count==null||count==0){
   db.update("INSERT INTO partner_notification_outbox(id,application_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,'IN_APP','DELIVERED',?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",
     UUID.randomUUID(),appId,"Chào mừng bạn đến với TaskLy Partner!","Chúc mừng bạn đã gia nhập mạng lưới đối tác dịch vụ TaskLy. Hãy luôn duy trì trạng thái trực tuyến để nhận thông báo đơn mới.");
   db.update("INSERT INTO partner_notification_outbox(id,application_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,'IN_APP','DELIVERED',?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",
     UUID.randomUUID(),appId,"Mẹo tăng thu nhập mỗi ngày","Hoàn thành từ 3 đơn dịch vụ trở lên trong ngày để nhận thêm thưởng mốc ngày hấp dẫn từ chương trình hỗ trợ đối tác.");
  }
 }
 public List<Map<String,Object>> notifications(UUID user){
  var a=recruitment.current(user);
  return db.queryForList("SELECT id,channel,status,title,message,created_at,read_at,task_id FROM partner_notification_outbox WHERE application_id=? ORDER BY created_at DESC",a.id());
 }
 public List<Map<String,Object>> controllerNotifications(UUID user){
  var a=recruitment.current(user);
  var list=notifications(user);
  if(list.isEmpty()){
   seedPartnerNotifications(user,a.id());
   list=notifications(user);
  }
  return list;
 }
}

