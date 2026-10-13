package com.taskly.recruitment;

import com.taskly.common.exception.DomainException;
import com.taskly.user.repository.UserProfileRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.*;
import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;
import static com.taskly.recruitment.RecruitmentDtos.*;

@Service
public class RecruitmentService {
 private final JdbcTemplate db;
 private final UserProfileRepository profiles;
 private final Clock clock;
 private final ObjectMapper json = new ObjectMapper();
 public RecruitmentService(JdbcTemplate db,UserProfileRepository profiles,Clock clock) {this.db=db;this.profiles=profiles;this.clock=clock;}
 static DomainException invalid(String message) {return new DomainException("RECRUITMENT_INVALID",message,HttpStatus.UNPROCESSABLE_ENTITY);}
 static DomainException conflict() {return new DomainException("RECRUITMENT_CONFLICT","Hồ sơ đã thay đổi. Vui lòng tải lại.",HttpStatus.CONFLICT);}
 private void account(UUID user) {
  var rows=db.queryForList("SELECT status,email_verified_at FROM users WHERE id=?",user);
  if(rows.isEmpty()) throw new DomainException("USER_NOT_FOUND","Vui lòng đăng nhập lại.",HttpStatus.UNAUTHORIZED);
  if(!"ACTIVE".equals(rows.getFirst().get("status")) || rows.getFirst().get("email_verified_at")==null)
   throw new DomainException("ACCOUNT_NOT_VERIFIED","Tài khoản cần xác minh email và đang hoạt động.",HttpStatus.FORBIDDEN);
 }
 @Transactional public Application current(UUID user) {
  account(user);
  // Serializes first creation and every mutation per existing account, including concurrent requests.
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,user);
  var ids=db.queryForList("SELECT id FROM partner_applications WHERE user_id=?",UUID.class,user);
  if(ids.isEmpty()) {
   var id=UUID.randomUUID(); var now=Timestamp.from(Instant.now());
   db.update("INSERT INTO partner_applications(id,user_id,full_name,contact_phone,created_at,updated_at) SELECT ?,u.id,COALESCE(p.full_name,''),u.phone,?,? FROM users u LEFT JOIN user_profiles p ON p.user_id=u.id WHERE u.id=?",id,now,now,user);
   audit(user,id,"APPLICATION_CREATED",null,"REGISTERED","");
   return find(id,false);
  }
  return find(ids.getFirst(),false);
 }
 public List<Area> areas() {
  return db.query("SELECT * FROM recruitment_areas ORDER BY city,name,id",(r,n)->new Area(r.getObject("id",UUID.class),r.getString("city"),r.getString("name"),r.getBoolean("recruiting"),r.getInt("capacity"),r.getLong("version"),
   db.queryForList("SELECT service_id FROM recruitment_area_services WHERE area_id=? ORDER BY service_id",UUID.class,r.getObject("id",UUID.class))));
 }
 public record WorkAreasWrite(@jakarta.validation.constraints.PositiveOrZero long version,
   @jakarta.validation.constraints.NotEmpty @jakarta.validation.constraints.Size(max=10) List<@jakarta.validation.constraints.NotNull UUID> areaIds) {}
 public record WorkAreas(long version,List<UUID> areaIds,List<Area> areas) {}
 @Transactional public WorkAreas workAreas(UUID user) {
  var app=current(user);var available=new ArrayList<>(areas());
  available.sort(Comparator.comparing(Area::city));
  return new WorkAreas(app.version(),app.areaIds(),available);
 }
 @Transactional public WorkAreas saveWorkAreas(UUID user,WorkAreasWrite w) {
  var app=current(user);
  if(!Set.of("APPROVED","ACTIVE").contains(app.status()))throw invalid("Chỉ Partner đã được duyệt chính thức mới chỉnh sửa khu vực nhận việc trong tài khoản.");
  if(app.version()!=w.version())throw conflict();
  if(w.areaIds().isEmpty()||w.areaIds().size()>10||new HashSet<>(w.areaIds()).size()!=w.areaIds().size())throw invalid("Chọn từ 1 đến 10 khu vực, không chọn trùng.");
  for(var id:w.areaIds().stream().sorted().toList()) {
   if(db.queryForList("SELECT id FROM recruitment_areas WHERE id=? FOR UPDATE",UUID.class,id).isEmpty()) {
    throw invalid("Khu vực đang bảo trì hoặc chưa được mở. Vui lòng chọn khu vực khác.");
   }
  }
  for(var id:w.areaIds())if(db.queryForObject("SELECT COUNT(*) FROM recruitment_areas WHERE id=? AND recruiting=true",Integer.class,id)==0)throw invalid("Khu vực đang bảo trì. Vui lòng chọn khu vực khác để tiếp tục làm việc.");
  db.update("DELETE FROM partner_application_areas WHERE application_id=?",app.id());
  for(var id:w.areaIds())db.update("INSERT INTO partner_application_areas(application_id,area_id) VALUES(?,?)",app.id(),id);
  db.update("UPDATE partner_applications SET areas_configured=true,version=version+1,updated_at=CURRENT_TIMESTAMP WHERE id=?",app.id());
  audit(user,app.id(),"WORK_AREAS_UPDATED",app.status(),app.status(),"Partner cập nhật "+w.areaIds().size()+" khu vực làm việc.");
  return workAreas(user);
 }
 public List<Area> recruitingAreas() {
  return areas().stream().filter(Area::recruiting).toList();
 }
 public List<Application> queue() {
  return db.queryForList("SELECT id FROM partner_applications ORDER BY updated_at DESC,id LIMIT 200",UUID.class).stream().map(id->find(id,false)).toList();
 }
 public record ApplicationPage(List<Application> items,long total,int page,int size) {}
 @Transactional(readOnly=true) public ApplicationPage page(int page,int size,String query,String status,UUID area,UUID service){
  if(page<0||page>100000||size<1||size>100||query.length()>160||status.length()>40)throw invalid("Bộ lọc hoặc trang không hợp lệ.");
  var where=new StringBuilder(" WHERE 1=1");var args=new ArrayList<Object>();
  if(!query.isBlank()){where.append(" AND LOWER(full_name) LIKE ? ESCAPE '!'");args.add("%"+query.trim().toLowerCase(Locale.ROOT).replace("!","!!").replace("%","!%").replace("_","!_")+"%");}
  if(!status.isBlank()){where.append(" AND status=?");args.add(status);}
  if(area!=null){where.append(" AND id IN (SELECT application_id FROM partner_application_areas WHERE area_id=?)");args.add(area);}
  if(service!=null){where.append(" AND id IN (SELECT application_id FROM partner_application_services WHERE service_id=?)");args.add(service);}
  long total=db.queryForObject("SELECT COUNT(*) FROM partner_applications"+where,Long.class,args.toArray());
  args.add(size);args.add(page*size);
  var ids=db.queryForList("SELECT id FROM partner_applications"+where+" ORDER BY updated_at DESC,id LIMIT ? OFFSET ?",UUID.class,args.toArray());
  return new ApplicationPage(ids.stream().map(id->find(id,false)).toList(),total,page,size);
 }
 public Application detail(UUID id) {return find(id,false);}
 private Application find(UUID id,boolean masked) {
  var result=db.query("SELECT a.*,u.email,COALESCE(NULLIF(TRIM(a.full_name),''),p.full_name,'') AS registration_name,COALESCE(NULLIF(TRIM(a.contact_phone),''),u.phone,'') AS registration_phone FROM partner_applications a JOIN users u ON u.id=a.user_id LEFT JOIN user_profiles p ON p.user_id=u.id WHERE a.id=?",(r,n)-> {
   var flags=new LinkedHashMap<String,Boolean>();
   for(String key:List.of("exam_passed","training_complete","agreements_current","profile_complete","preliminary_approved","uniform_resolved","appointment_checked_in","documents_valid","final_approved","skills_configured","areas_configured","availability_configured")) flags.put(key,r.getBoolean(key));
   flags.put("registration_submitted", r.getTimestamp("registration_confirmed_at")!=null);
   flags.put("identity_approved", Boolean.TRUE.equals(db.queryForObject("SELECT COALESCE((SELECT v.status='APPROVED' AND v.document_type='NATIONAL_ID' AND v.reviewed_by IS NOT NULL AND v.reviewed_at IS NOT NULL FROM identity_verifications v WHERE v.user_id=? ORDER BY v.created_at DESC,v.id DESC LIMIT 1),false)",Boolean.class,r.getObject("user_id",UUID.class))));
   flags.put("registration_complete", !r.getString("registration_name").isBlank() && r.getString("registration_phone")!=null && !r.getString("registration_phone").isBlank() && r.getObject("date_of_birth")!=null
     && db.queryForObject("SELECT COUNT(*) FROM partner_application_areas WHERE application_id=?",Integer.class,id)>0
     && db.queryForObject("SELECT COUNT(*) FROM partner_application_services WHERE application_id=?",Integer.class,id)>0);
   flags.put("identity_complete", db.queryForObject("SELECT COUNT(*) FROM identity_verifications v WHERE v.user_id=? AND v.id=(SELECT id FROM identity_verifications WHERE user_id=? ORDER BY created_at DESC LIMIT 1) AND v.status NOT IN ('REJECTED','EXPIRED') AND v.document_type='NATIONAL_ID' AND LENGTH(v.document_number_masked)=12 AND v.legal_name IS NOT NULL AND LENGTH(TRIM(v.legal_name))>=2 AND (SELECT COUNT(DISTINCT d.document_side) FROM verification_documents d JOIN stored_objects o ON o.id=d.stored_object_id WHERE d.verification_id=v.id AND d.document_side IN ('FRONT','BACK','SELFIE') AND o.scan_status='CLEAN')=3",Integer.class,r.getObject("user_id",UUID.class),r.getObject("user_id",UUID.class))>0);
   flags.put("uniform_ordered",db.queryForObject("SELECT COUNT(*) FROM partner_uniform_orders WHERE application_id=? AND status NOT IN ('CANCELLED','REFUNDED')",Integer.class,id)>0);
   flags.put("office_visit_confirmed",db.queryForObject("SELECT COUNT(*) FROM recruitment_audit WHERE application_id=? AND action='OFFICE_VISIT_CONFIRMED'",Integer.class,id)>0);
   String phone=r.getString("registration_phone");
   if(masked && phone!=null && !phone.isBlank()) phone="••••"+phone.substring(Math.max(0,phone.length()-4));
   return new Application(id,r.getObject("user_id",UUID.class),r.getString("status"),r.getString("registration_name"),phone,
    masked?"[email đã ẩn]":r.getString("email"),masked?null:r.getObject("date_of_birth",LocalDate.class),r.getString("experience"),r.getString("transport"),r.getString("referral"),
    db.queryForList("SELECT area_id FROM partner_application_areas WHERE application_id=? ORDER BY area_id",UUID.class,id),
    db.queryForList("SELECT service_id FROM partner_application_services WHERE application_id=? ORDER BY service_id",UUID.class,id),r.getString("reason"),json.readValue(r.getString("required_changes"),new tools.jackson.core.type.TypeReference<List<String>>(){}),flags,
    instant(r,"documents_received_at"),instant(r,"activated_at"),instant(r,"created_at"),instant(r,"updated_at"),r.getLong("version"),
    instant(r,"first_submitted_at"),r.getString("status").equals("ESCALATED")?instant(r,"editable_until"):null,editable(r.getString("status"),instant(r,"editable_until")),
    true);
  },id);
  if(result.isEmpty()) throw new DomainException("APPLICATION_NOT_FOUND","Không tìm thấy hồ sơ.",HttpStatus.NOT_FOUND);
  return result.getFirst();
 }
 private Instant instant(ResultSet r,String key) throws SQLException {var t=r.getTimestamp(key);return t==null?null:t.toInstant();}
 private boolean editable(String status,Instant deadline) {
  return Set.of("REGISTERED","WAITLISTED","EXAM_REQUIRED","EXAM_IN_PROGRESS","EXAM_FAILED","TRAINING_REQUIRED","AGREEMENT_REQUIRED","ACTION_REQUIRED","PROFILE_INCOMPLETE").contains(status)
   ;
 }
 public void requireReviewReady(Application application) {
  if(!Set.of("PRELIMINARY_REVIEW","ESCALATED","DOCUMENTS_RECEIVED","FINAL_REVIEW","ACTIVE").contains(application.status())) throw invalid("Hồ sơ chưa ở bước xét duyệt.");
 }
 public void notifyIdentityApproved(UUID user,String reason) {
  var ids=db.queryForList("SELECT id FROM partner_applications WHERE user_id=?",UUID.class,user);
  if(ids.isEmpty())return;
  String safe=reason.replaceAll("[0-9]{8,}","[đã ẩn]").replaceAll("[^\\s]+@[^\\s]+","[email đã ẩn]");
  db.update("INSERT INTO partner_notification_outbox(id,application_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,'IN_APP','DELIVERED',?,?,?,?)",UUID.randomUUID(),ids.getFirst(),"CCCD đã được xác nhận hợp lệ","Admin đã kiểm tra và xác nhận giấy tờ CCCD của bạn hợp lệ. "+safe+" Hồ sơ tiếp tục được xét duyệt sơ bộ; đây chưa phải thông báo kích hoạt tài khoản.",Timestamp.from(clock.instant()),Timestamp.from(clock.instant()));
 }
 @Transactional public Application verificationApplication(UUID user) {
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,user);
  var ids=db.queryForList("SELECT id FROM partner_applications WHERE user_id=?",UUID.class,user);
  return ids.isEmpty()?null:find(ids.getFirst(),false);
 }
 @Transactional public void requireVerificationReviewReady(UUID verificationId) {
  var user=db.queryForObject("SELECT user_id FROM identity_verifications WHERE id=?",UUID.class,verificationId);
  var application=verificationApplication(user);
  if(application!=null) requireReviewReady(application);
 }
 public Application dossierApplication(UUID id,boolean personalDetails) {return find(id,!personalDetails);}
 @Transactional public Application save(UUID user,Registration w) {
  var a=current(user);
  if(a.version()!=w.version()) throw conflict();
  if(!a.editable()) throw invalid("Hết thời hạn chỉnh sửa hồ sơ hoặc hồ sơ đã được xét duyệt.");
  if(a.firstSubmittedAt()!=null && !a.status().equals("ACTION_REQUIRED") &&
    (!new HashSet<>(w.areaIds()).equals(new HashSet<>(a.areaIds())) || !new HashSet<>(w.serviceIds()).equals(new HashSet<>(a.serviceIds())))) throw invalid("Hồ sơ đã nộp; không được thay đổi khu vực và dịch vụ tuyển dụng.");
  if(a.firstSubmittedAt()!=null && Set.of("ACTION_REQUIRED","PROFILE_INCOMPLETE","PRELIMINARY_REVIEW").contains(a.status())){
   if(a.status().equals("ACTION_REQUIRED")) {
    var allowed=a.requiredChanges();
    if((!Objects.equals(w.fullName().trim(),a.fullName())&&!allowed.contains("Họ và tên")) || (!Objects.equals(w.contactPhone(),a.contactPhone())&&!allowed.contains("Số điện thoại liên hệ")) || (!Objects.equals(w.dateOfBirth(),a.dateOfBirth())&&!allowed.contains("Ngày sinh")))throw invalid("Chỉ được sửa các mục admin yêu cầu bổ sung.");
   }
   if(a.status().equals("ACTION_REQUIRED") && ((!new HashSet<>(w.areaIds()).equals(new HashSet<>(a.areaIds())) && a.requiredChanges().stream().noneMatch(item->item.contains("Khu vực")))||(!new HashSet<>(w.serviceIds()).equals(new HashSet<>(a.serviceIds())) && a.requiredChanges().stream().noneMatch(item->item.contains("Dịch vụ")||item.contains("Kỹ năng")))))throw invalid("Bổ sung hồ sơ không được thay đổi kỹ năng hoặc khu vực đã tuyển.");
   int minimum=db.queryForObject("SELECT minimum_age FROM recruitment_policy WHERE id=1",Integer.class);
   if(w.fullName().isBlank()||w.contactPhone().isBlank()||w.dateOfBirth()==null||w.areaIds().isEmpty()||w.serviceIds().isEmpty()||Period.between(w.dateOfBirth(),LocalDate.now()).getYears()<minimum)throw invalid("Thông tin bổ sung phải đầy đủ, chọn khu vực và dịch vụ, và đủ tuổi tuyển dụng.");
  }
  if(new HashSet<>(w.areaIds()).size()!=w.areaIds().size() || new HashSet<>(w.serviceIds()).size()!=w.serviceIds().size()) throw invalid("Không chọn trùng khu vực hoặc dịch vụ.");
  var known=areas();
  if(w.areaIds().stream().anyMatch(id->known.stream().noneMatch(ar->ar.id().equals(id)))) throw invalid("Khu vực không tồn tại.");
  if(Set.of("REGISTERED","WAITLISTED").contains(a.status()) && w.areaIds().stream().anyMatch(id->known.stream().noneMatch(ar->ar.id().equals(id)&&ar.recruiting()))) throw invalid("Khu vực đã ngừng tuyển. Vui lòng chọn khu vực đang mở tuyển.");
  if(w.serviceIds().stream().anyMatch(id->db.queryForObject("SELECT COUNT(*) FROM services WHERE id=? AND active=true",Integer.class,id)==0)) throw invalid("Dịch vụ không tồn tại hoặc đã ngừng hoạt động.");
  if(Set.of("PROFILE_INCOMPLETE","PRELIMINARY_REVIEW","ACTION_REQUIRED").contains(a.status()) &&
     (!new HashSet<>(w.areaIds()).equals(new HashSet<>(a.areaIds())) || !new HashSet<>(w.serviceIds()).equals(new HashSet<>(a.serviceIds())))) {
   // Keep quota checks serialized with registration submission and area configuration.
   for(var area:w.areaIds().stream().sorted().toList())db.queryForObject("SELECT id FROM recruitment_areas WHERE id=? FOR UPDATE",UUID.class,area);
   var selected=areas().stream().filter(ar->w.areaIds().contains(ar.id())).toList();
   if(selected.stream().map(Area::city).distinct().count()!=1) throw invalid("Chọn khu vực trong cùng một tỉnh/thành phố.");
   if(w.serviceIds().stream().anyMatch(id->selected.stream().noneMatch(ar->ar.serviceIds().contains(id)))) throw invalid("Dịch vụ chưa tuyển tại khu vực đã chọn.");
   if(selected.stream().filter(ar->!a.areaIds().contains(ar.id())).anyMatch(ar->!ar.recruiting() || ar.capacity()<=db.queryForObject("SELECT COUNT(*) FROM partner_application_areas link JOIN partner_applications app ON app.id=link.application_id WHERE link.area_id=? AND app.id<>? AND app.status NOT IN ('REGISTERED','WAITLISTED','REJECTED','SUSPENDED')",Integer.class,ar.id(),a.id()))) throw invalid("Khu vực mới đã ngừng tuyển hoặc hết chỉ tiêu.");
  }
  String phone=w.contactPhone().replaceAll("[\\s().-]","");
  if(!phone.isEmpty() && !phone.matches("(?:\\+84|0)[0-9]{9}")) throw invalid("Số điện thoại liên hệ không hợp lệ.");
  if(!phone.isEmpty() && db.queryForObject("SELECT COUNT(*) FROM partner_applications WHERE contact_phone=? AND user_id<>?",Integer.class,phone,user)>0) throw invalid("Số điện thoại đã được dùng trong hồ sơ khác.");
  if(w.dateOfBirth()!=null && (w.dateOfBirth().isAfter(LocalDate.now()) || w.dateOfBirth().isBefore(LocalDate.now().minusYears(110)))) throw invalid("Ngày sinh không hợp lệ.");
  db.update("UPDATE partner_applications SET full_name=?,contact_phone=?,date_of_birth=?,experience=?,transport=?,referral=?,updated_at=?,version=version+1 WHERE id=?",w.fullName().trim(),phone.isEmpty()?null:phone,w.dateOfBirth(),w.experience().trim(),w.transport().trim(),w.referral().trim(),Timestamp.from(Instant.now()),a.id());
  // Keep the account name in the same transaction; an incomplete draft must not erase it.
  if(!w.fullName().isBlank()) {
   var profile=profiles.findById(user).orElseThrow(()->new IllegalStateException("User profile is missing"));
   profile.update(w.fullName().trim(),profile.getLanguage(),Instant.now());
  }
  db.update("DELETE FROM partner_application_areas WHERE application_id=?",a.id());
  for(var id:w.areaIds()) db.update("INSERT INTO partner_application_areas VALUES(?,?)",a.id(),id);
  db.update("DELETE FROM partner_application_services WHERE application_id=?",a.id());
  for(var id:w.serviceIds()) db.update("INSERT INTO partner_application_services VALUES(?,?)",a.id(),id);
  audit(user,a.id(),"REGISTRATION_DRAFT_SAVED",a.status(),a.status(),"");
  return find(a.id(),false);
 }
 @Transactional public Application submit(UUID user,Submit w) {
  var a=current(user);
  String hash=hash(a.id()+":registration:"+w.version());
  var prior=db.queryForList("SELECT payload_hash FROM recruitment_requests WHERE actor_id=? AND request_key=?",String.class,user,w.requestId());
  if(!prior.isEmpty()) {if(!prior.getFirst().equals(hash)) throw conflict(); return a;}
  if(a.version()!=w.version()) throw conflict();
  if(!Set.of("REGISTERED","WAITLISTED","EXAM_REQUIRED","EXAM_IN_PROGRESS","EXAM_FAILED","TRAINING_REQUIRED","AGREEMENT_REQUIRED","PROFILE_INCOMPLETE").contains(a.status())) throw invalid("Hồ sơ đã được gửi.");
  if(a.fullName().isBlank() || a.contactPhone()==null || a.dateOfBirth()==null || a.areaIds().isEmpty() || a.serviceIds().isEmpty()) throw invalid("Điền họ tên, điện thoại, ngày sinh, khu vực và ít nhất một dịch vụ.");
  int minimum=db.queryForObject("SELECT minimum_age FROM recruitment_policy WHERE id=1",Integer.class);
  if(Period.between(a.dateOfBirth(),LocalDate.now()).getYears()<minimum) throw invalid("Chưa đủ tuổi tham gia tuyển dụng.");
  // Lock shared quotas in deterministic order, in addition to the per-account lock.
  for(var area:a.areaIds().stream().sorted().toList())db.queryForObject("SELECT id FROM recruitment_areas WHERE id=? FOR UPDATE",UUID.class,area);
  var selected=areas().stream().filter(ar->a.areaIds().contains(ar.id())).toList();
  if(selected.stream().map(Area::city).distinct().count()!=1) throw invalid("Chọn khu vực trong cùng một tỉnh/thành phố.");
  if(a.serviceIds().stream().anyMatch(id->selected.stream().noneMatch(ar->ar.serviceIds().contains(id)))) throw invalid("Dịch vụ chưa tuyển tại khu vực đã chọn.");
  boolean recruiting=selected.stream().allMatch(ar->ar.recruiting() && ar.capacity()>db.queryForObject("SELECT COUNT(*) FROM partner_application_areas link JOIN partner_applications app ON app.id=link.application_id WHERE link.area_id=? AND app.id<>? AND app.status NOT IN ('REGISTERED','WAITLISTED','REJECTED','SUSPENDED')",Integer.class,ar.id(),a.id()));
  String status=Set.of("REGISTERED","WAITLISTED").contains(a.status())?(recruiting?"EXAM_REQUIRED":"WAITLISTED"):a.status();
  db.update("UPDATE partner_applications SET status=?,registration_confirmed_at=?,updated_at=?,version=version+1 WHERE id=?",status,Timestamp.from(Instant.now()),Timestamp.from(Instant.now()),a.id());
  audit(user,a.id(),"REGISTRATION_SUBMITTED",a.status(),status,"");
  db.update("INSERT INTO recruitment_requests VALUES(?,?,?,?,?)",user,w.requestId(),hash,a.id(),Timestamp.from(Instant.now()));
  return find(a.id(),false);
 }
 @Transactional public Area saveArea(UUID actor,UUID id,AreaWrite w) {
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,actor);
  String city=w.city().trim();
  if(db.queryForObject("SELECT COUNT(*) FROM recruitment_areas WHERE lower(btrim(city))=lower(?) AND id<>?",Integer.class,city,id)>0)throw invalid("Tỉnh/thành phố này đã có trong danh sách. Vui lòng chỉnh sửa mục hiện có.");
  for(var service:w.serviceIds()) if(db.queryForObject("SELECT COUNT(*) FROM services WHERE id=?",Integer.class,service)==0) throw invalid("Dịch vụ không tồn tại.");
  if(new HashSet<>(w.serviceIds()).size()!=w.serviceIds().size()) throw invalid("Dịch vụ bị trùng.");
  var existing=areas().stream().filter(ar->ar.id().equals(id)).findFirst();
  if(existing.isPresent()) {
   if(db.update("UPDATE recruitment_areas SET city=?,name=?,recruiting=?,capacity=?,version=version+1,updated_at=? WHERE id=? AND version=?",city,city,w.recruiting(),w.capacity(),Timestamp.from(Instant.now()),id,w.version())!=1) throw conflict();
  } else {if(w.version()!=0) throw conflict(); db.update("INSERT INTO recruitment_areas VALUES(?,?,?,?,?,0,?)",id,city,city,w.recruiting(),w.capacity(),Timestamp.from(Instant.now()));}
  if(existing.isPresent() && existing.get().recruiting() && (!w.recruiting() || !existing.get().city().equals(city)))notifyAreaClosed(id,existing.get().city());
  db.update("DELETE FROM recruitment_area_services WHERE area_id=?",id);
  for(var service:w.serviceIds()) db.update("INSERT INTO recruitment_area_services VALUES(?,?)",id,service);
  audit(actor,null,"RECRUITMENT_AREA_UPDATED",null,null,"Khu vực "+id);
  return areas().stream().filter(ar->ar.id().equals(id)).findFirst().orElseThrow();
 }
 private void notifyAreaClosed(UUID area,String city) {
  for(var app:db.queryForList("SELECT application_id FROM partner_application_areas WHERE area_id=?",UUID.class,area))
   db.update("INSERT INTO partner_notification_outbox(id,application_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,'IN_APP','DELIVERED',?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",UUID.randomUUID(),app,"Khu vực làm việc đang bảo trì",city+" đã đóng hoặc đang bảo trì. Vui lòng vào Hồ sơ → Khu vực làm việc và đổi sang khu vực đang mở để tiếp tục nhận việc.");
 }
 public static void requireOpenCity(JdbcTemplate db,String city) {
  if(city==null || db.queryForList("SELECT id FROM recruitment_areas WHERE lower(btrim(city))=lower(btrim(?)) AND recruiting=true FOR UPDATE",UUID.class,city).isEmpty())
   throw new DomainException("AREA_MAINTENANCE","Khu vực đang bảo trì hoặc chưa được mở. Vui lòng đổi địa chỉ sang khu vực đang hoạt động.",HttpStatus.UNPROCESSABLE_ENTITY);
 }
 @Transactional public void deleteArea(UUID actor,UUID id) {
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,actor);
  var city=db.queryForList("SELECT city FROM recruitment_areas WHERE id=?",String.class,id);
  if(!city.isEmpty())notifyAreaClosed(id,city.getFirst());
  db.update("DELETE FROM recruitment_area_services WHERE area_id=?",id);
  db.update("DELETE FROM partner_application_areas WHERE area_id=?",id);
  db.update("DELETE FROM recruitment_areas WHERE id=?",id);
  audit(actor,null,"RECRUITMENT_AREA_DELETED",null,null,"Xóa khu vực "+id);
 }
 public List<Map<String,Object>> auditLog() {return db.queryForList("SELECT * FROM recruitment_audit ORDER BY created_at DESC,id LIMIT 500");}
 void audit(UUID actor,UUID app,String action,String before,String after,String reason) {
  db.update("INSERT INTO recruitment_audit VALUES(?,?,?,?,?,?,?,?)",UUID.randomUUID(),actor,app,action,before,after,reason,Timestamp.from(Instant.now()));
 }
 static String hash(String value) {
  try {return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));}
  catch(Exception e) {throw new IllegalStateException(e);}
 }
}
