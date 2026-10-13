package com.taskly.user;

import com.taskly.common.api.ApiResponse;
import com.taskly.common.exception.DomainException;
import com.taskly.auth.RefreshTokenService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Clock;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/admin/customers")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
public class AdminCustomerController {
    private final com.taskly.recruitment.RecruitmentDossierService dossiers;
    private final JdbcTemplate db;
    private final RefreshTokenService refresh;
    private final Clock clock;
    public AdminCustomerController(JdbcTemplate db, RefreshTokenService refresh, Clock clock, com.taskly.recruitment.RecruitmentDossierService dossiers) {
        this.dossiers=dossiers; this.db = db; this.refresh = refresh; this.clock = clock;
    }
    public record PartnerBatch(@NotNull @Size(min=1,max=50) List<@Valid PartnerEdit> edits) {}
    @PatchMapping("/{id}/details/batch") @Transactional
    public ApiResponse<Map<String,Object>> editBatch(@PathVariable UUID id,@Valid @RequestBody PartnerBatch batch,@org.springframework.security.core.annotation.AuthenticationPrincipal org.springframework.security.oauth2.jwt.Jwt jwt){
        for(var edit:batch.edits())editDetails(id,edit,jwt);
        return details(id);
    }
    public record PartnerEdit(@NotBlank String section, UUID recordId, @NotNull Map<String,Object> values) {}
    @PatchMapping("/{id}/details") @Transactional
    public ApiResponse<Map<String,Object>> editDetails(@PathVariable UUID id,@Valid @RequestBody PartnerEdit edit,@org.springframework.security.core.annotation.AuthenticationPrincipal org.springframework.security.oauth2.jwt.Jwt jwt) {
        requireCustomer(id);
        var before=details(id).data();
        String section=edit.section(); var v=edit.values();
        if(section.equals("profile")) {
            String name=editText(v,"full_name",160,true),phone=editText(v,"phone",32,true),email=editText(v,"email",254,true);
            if(name.length()<2||!phone.matches("0[0-9]{9}")||!email.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+"))throw badEdit();
            if(db.queryForObject("SELECT COUNT(*) FROM users WHERE id<>? AND (email=? OR phone=?)",Integer.class,id,email,phone)>0)throw new DomainException("CONTACT_EXISTS","Email hoặc điện thoại đã được sử dụng.",HttpStatus.CONFLICT);
            db.update("UPDATE users SET email=?,phone=?,updated_at=CURRENT_TIMESTAMP,version=version+1 WHERE id=?",email,phone,id);
            db.update("UPDATE user_profiles SET full_name=?,updated_at=CURRENT_TIMESTAMP WHERE user_id=?",name,id);
            db.update("UPDATE partner_applications SET full_name=?,contact_phone=?,updated_at=CURRENT_TIMESTAMP,version=version+1 WHERE user_id=?",name,phone,id);
        } else if(section.equals("bank")) {
            String bank=editText(v,"bank_name",100,true),name=editText(v,"account_name",150,true),number=editText(v,"account_number",34,true);
            if(!number.matches("[0-9]{6,34}"))throw badEdit();
            if(db.update("UPDATE partner_bank_accounts SET bank_name=?,account_name=?,account_number=?,updated_at=CURRENT_TIMESTAMP WHERE user_id=?",bank,name,number,id)==0)db.update("INSERT INTO partner_bank_accounts(user_id,bank_name,account_name,account_number) VALUES(?,?,?,?)",id,bank,name,number);
        } else if(section.equals("application")) {
            String dob=editText(v,"dateOfBirth",10,false); java.time.LocalDate date=dob.isBlank()?null:editDate(dob);
            if(date!=null&&date.isAfter(java.time.LocalDate.now(clock)))throw badEdit();
            db.update("UPDATE partner_applications SET date_of_birth=?,experience=?,transport=?,referral=?,updated_at=CURRENT_TIMESTAMP,version=version+1 WHERE user_id=?",date,editText(v,"experience",1000,false),editText(v,"transport",40,false),editText(v,"referral",100,false),id);
        } else if(section.equals("identity")) {
            String number=editText(v,"document_number",12,true),name=editText(v,"legal_name",160,true);if(!number.matches("[0-9]{12}")||name.length()<2)throw badEdit();
            if(db.update("UPDATE identity_verifications SET legal_name=?,document_number=?,document_number_masked=?,updated_at=CURRENT_TIMESTAMP,version=version+1 WHERE id=? AND user_id=?",name,number,"********"+number.substring(8),edit.recordId(),id)!=1)throw badEdit();
        } else if(section.equals("address")) {
            var keys=List.of("label","recipient_name","recipient_phone","address_line","ward","district","city","building_type","building_description","notes"); var args=new java.util.ArrayList<Object>();
            for(String key:keys){String text=editText(v,key,key.equals("notes")||key.equals("address_line")||key.equals("building_description")?500:160,!List.of("ward","district","notes").contains(key));if(key.equals("recipient_phone")&&!text.matches("0[0-9]{9}"))throw badEdit();args.add(text);}args.add(edit.recordId());args.add(id);
            if(db.update("UPDATE addresses SET label=?,recipient_name=?,recipient_phone=?,address_line=?,ward=?,district=?,city=?,building_type=?,building_description=?,notes=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND user_id=? AND deleted_at IS NULL",args.toArray())!=1)throw badEdit();
        } else if(section.equals("work")) {
            UUID app=db.queryForObject("SELECT id FROM partner_applications WHERE user_id=?",UUID.class,id);
            for(String kind:List.of("area","service")){
                Object raw=v.get(kind+"Ids");if(!(raw instanceof List<?> list)||list.isEmpty()||list.size()>30)throw badEdit();
                var ids=new java.util.LinkedHashSet<UUID>();for(Object value:list)ids.add(editUuid(value.toString()));
                String table=kind.equals("area")?"recruitment_areas":"services";
                for(UUID value:ids)if(db.queryForObject("SELECT COUNT(*) FROM "+table+" WHERE id=?",Integer.class,value)!=1)throw badEdit();
                db.update("DELETE FROM partner_application_"+kind+"s WHERE application_id=?",app);
                for(UUID value:ids)db.update("INSERT INTO partner_application_"+kind+"s(application_id,"+kind+"_id) VALUES(?,?)",app,value);
            }
            java.time.Instant start=editInstant(editText(v,"starts_at",50,true)),end=editInstant(editText(v,"ends_at",50,true));if(!end.isAfter(start)||java.time.Duration.between(start,end).toDays()>30)throw badEdit();
            db.update("DELETE FROM partner_availability WHERE application_id=?",app);db.update("INSERT INTO partner_availability(application_id,starts_at,ends_at) VALUES(?,?,?)",app,start,end);
            db.update("UPDATE partner_applications SET skills_configured=true,areas_configured=true,availability_configured=true,updated_at=CURRENT_TIMESTAMP,version=version+1 WHERE id=?",app);
        } else throw badEdit();
        var result=details(id);var json=new tools.jackson.databind.ObjectMapper();
        db.update("INSERT INTO audit_logs(id,actor_id,actor_type,action,entity_type,entity_id,old_value_summary,new_value_summary,created_at) VALUES(?,?,'ADMIN',?,'Partner',?,?,?,CURRENT_TIMESTAMP)",UUID.randomUUID(),UUID.fromString(jwt.getSubject()),"EDIT_PARTNER_"+section.toUpperCase(),id,json.writeValueAsString(before),json.writeValueAsString(result.data()));
        return result;
    }
    private String editText(Map<String,Object> values,String key,int limit,boolean required){Object value=values.get(key);if(value!=null&&!(value instanceof String))throw badEdit();String text=value==null?"":value.toString().trim();if(text.length()>limit||(required&&text.isBlank()))throw badEdit();return text;}
    private java.time.LocalDate editDate(String value){try{return java.time.LocalDate.parse(value);}catch(RuntimeException e){throw badEdit();}}
    private java.time.Instant editInstant(String value){try{return java.time.Instant.parse(value);}catch(RuntimeException e){throw badEdit();}}
    private UUID editUuid(String value){try{return UUID.fromString(value);}catch(RuntimeException e){throw badEdit();}}
    private DomainException badEdit(){return new DomainException("INVALID_PARTNER_EDIT","Thông tin chỉnh sửa không hợp lệ.",HttpStatus.BAD_REQUEST);}
    @GetMapping("/{id}/details")
    public ApiResponse<Map<String,Object>> details(@PathVariable UUID id) {
        var users=db.queryForList("SELECT u.id,u.email,u.phone,u.status,u.created_at,p.full_name,p.language FROM users u LEFT JOIN user_profiles p ON p.user_id=u.id WHERE u.id=?",id);
        if(users.isEmpty())throw new DomainException("USER_NOT_FOUND","Không tìm thấy tài khoản.",HttpStatus.NOT_FOUND);
        var result=new java.util.LinkedHashMap<String,Object>();
        result.put("profile",users.getFirst());
        result.put("performance",db.queryForMap("SELECT COUNT(*) AS accepted_jobs, COALESCE(SUM(CASE WHEN status IN ('COMPLETED','PAID') THEN 1 ELSE 0 END),0) AS completed_jobs FROM tasks WHERE tasker_id=?",id));
        result.put("bank",db.queryForList("SELECT bank_name,account_name,account_number,updated_at FROM partner_bank_accounts WHERE user_id=?",id));
        result.put("addresses",db.queryForList("SELECT id,label,recipient_name,recipient_phone,address_line,ward,district,city,building_type,building_description,notes FROM addresses WHERE user_id=? AND deleted_at IS NULL",id));
        var applications=db.queryForList("SELECT id FROM partner_applications WHERE user_id=?",UUID.class,id);
        result.put("workOptions",Map.of("areas",db.queryForList("SELECT id,name,city FROM recruitment_areas ORDER BY city,name"),"services",db.queryForList("SELECT id,name FROM services WHERE deleted_at IS NULL AND active=true ORDER BY name")));
        result.put("dossier",applications.isEmpty()?null:dossiers.detail(applications.getFirst(),true,true));
        return ApiResponse.success(result);
    }
    @GetMapping("/{id}/customer-details")
    public ApiResponse<Map<String,Object>> customerDetails(@PathVariable UUID id) {
        var users=db.queryForList("SELECT u.id,u.email,u.phone,u.status,u.created_at,p.full_name FROM users u LEFT JOIN user_profiles p ON p.user_id=u.id WHERE u.id=?",id);
        if(users.isEmpty())throw new DomainException("USER_NOT_FOUND","Không tìm thấy tài khoản.",HttpStatus.NOT_FOUND);
        var result=new java.util.LinkedHashMap<String,Object>();
        result.put("profile",users.getFirst());
        result.put("addresses",db.queryForList("SELECT id,label,recipient_name,recipient_phone,address_line,ward,district,city,building_type,building_description,notes FROM addresses WHERE user_id=? AND deleted_at IS NULL",id));
        result.put("orders",db.queryForList("SELECT id,service_name_snapshot AS service_name,status,budget_amount AS total,scheduled_at,CONCAT_WS(', ',NULLIF(address_line_snapshot,''),NULLIF(ward_snapshot,''),NULLIF(district_snapshot,''),NULLIF(city_snapshot,'')) AS location FROM tasks WHERE customer_id=? AND status<>'DRAFT' ORDER BY created_at DESC",id));
        return ApiResponse.success(result);
    }
    @GetMapping
    public ApiResponse<List<Map<String,Object>>> customers() {
        var rows = db.queryForList("""
            SELECT u.id, COALESCE(NULLIF(p.full_name, ''), NULLIF(a.full_name, ''), '') AS name,
              u.email, COALESCE(u.phone, a.contact_phone, '') AS phone, u.status,
              (SELECT f.portrait FROM partner_final_documents f WHERE f.application_id=a.id) AS avatar,
              u.used_customer AS customer_app, (u.used_partner OR a.id IS NOT NULL) AS partner_app,
              u.created_at AS created,
              (SELECT COUNT(*) FROM tasks t WHERE t.customer_id=u.id AND t.status<>'DRAFT') AS bookings,
              (SELECT COUNT(*) FROM tasks t WHERE t.tasker_id=u.id) AS accepted_jobs,
              (SELECT COUNT(*) FROM tasks t WHERE t.tasker_id=u.id AND t.status IN ('COMPLETED','PAID')) AS completed_jobs,
              a.id AS application_id, COALESCE(a.status, 'NOT_REGISTERED') AS recruitment_status,
              COALESCE((SELECT v.status FROM identity_verifications v WHERE v.user_id=u.id ORDER BY v.created_at DESC, v.id DESC LIMIT 1), 'NOT_SUBMITTED') AS kyc,
              a.reason AS review_reason, a.updated_at AS recruitment_updated_at,
              COALESCE((SELECT v.status NOT IN ('REJECTED','EXPIRED') AND v.document_type='NATIONAL_ID' AND LENGTH(v.document_number)=12 AND LENGTH(TRIM(v.legal_name))>=2 AND (SELECT COUNT(DISTINCT d.document_side) FROM verification_documents d JOIN stored_objects o ON o.id=d.stored_object_id WHERE d.verification_id=v.id AND d.document_side IN ('FRONT','BACK','SELFIE') AND o.scan_status='CLEAN')=3 FROM identity_verifications v WHERE v.user_id=u.id ORDER BY v.created_at DESC,v.id DESC LIMIT 1),false) AS identity_complete,
              COALESCE((SELECT v.status='APPROVED' AND v.document_type='NATIONAL_ID' AND v.reviewed_by IS NOT NULL AND v.reviewed_at IS NOT NULL FROM identity_verifications v WHERE v.user_id=u.id ORDER BY v.created_at DESC,v.id DESC LIMIT 1),false) AS identity_approved,
              a.exam_passed, a.training_complete, a.agreements_current, a.profile_complete,
              a.preliminary_approved, a.uniform_resolved, a.appointment_checked_in, a.documents_valid,
              a.final_approved, a.skills_configured, a.areas_configured, a.availability_configured
            FROM users u LEFT JOIN user_profiles p ON p.user_id=u.id
              LEFT JOIN partner_applications a ON a.user_id=u.id
            WHERE (u.used_partner=true OR a.id IS NOT NULL OR EXISTS
              (SELECT 1 FROM user_roles ur JOIN roles r ON r.id=ur.role_id WHERE ur.user_id=u.id AND r.role_key IN ('CUSTOMER','TASKER')))
              AND NOT EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id=ur.role_id WHERE ur.user_id=u.id AND r.role_key IN ('ADMIN','SUPER_ADMIN'))
            ORDER BY u.created_at DESC, u.id
            """);
        for (var row : rows) {
            var checks = new java.util.LinkedHashMap<String,Boolean>();
            for (String key : List.of("exam_passed", "training_complete", "agreements_current", "profile_complete",
                "preliminary_approved", "uniform_resolved", "appointment_checked_in", "documents_valid", "identity_approved", "identity_complete",
                "final_approved", "skills_configured", "areas_configured", "availability_configured")) {
                checks.put(key, Boolean.TRUE.equals(row.remove(key)));
            }
            row.put("partner_checks", checks);
        }
        return ApiResponse.success(rows);
    }
    public record UpdateCustomerRequest(
        @NotBlank @Size(min=2, max=160) String name,
        @NotBlank @Pattern(regexp="^0[0-9]{9}$") String phone) {}
    public record StatusRequest(@NotBlank @Pattern(regexp="ACTIVE|SUSPENDED") String status) {}
    private void requireCustomer(UUID id) {
        if (db.queryForObject("SELECT COUNT(*) FROM users u WHERE u.id = ? AND EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = u.id AND r.role_key IN ('CUSTOMER','TASKER')) AND NOT EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = u.id AND r.role_key IN ('ADMIN','SUPER_ADMIN'))", Integer.class, id) == 0)
            throw new DomainException("CUSTOMER_NOT_FOUND", "Không tìm thấy khách hàng.", HttpStatus.NOT_FOUND);
        db.queryForObject("SELECT id FROM users WHERE id = ? FOR UPDATE", UUID.class, id);
    }
    @PatchMapping("/{id}")
    @Transactional
    public ApiResponse<Void> update(@PathVariable UUID id, @Valid @RequestBody UpdateCustomerRequest body) {
        requireCustomer(id);
        if (body.name().trim().length() < 2)
            throw new DomainException("INVALID_NAME", "Họ tên cần ít nhất 2 ký tự.", HttpStatus.UNPROCESSABLE_ENTITY);
        if (db.queryForObject("SELECT COUNT(*) FROM users WHERE phone = ? AND id <> ?", Integer.class, body.phone(), id) > 0)
            throw new DomainException("PHONE_EXISTS", "Số điện thoại đã được sử dụng.", HttpStatus.CONFLICT);
        db.update("UPDATE users SET phone = ?, updated_at = ?, version = version + 1 WHERE id = ?", body.phone(), clock.instant(), id);
        db.update("UPDATE user_profiles SET full_name = ?, updated_at = ? WHERE user_id = ?", body.name().trim(), clock.instant(), id);
        return ApiResponse.success(null);
    }
    @PatchMapping("/{id}/status")
    @Transactional
    public ApiResponse<Void> status(@PathVariable UUID id, @Valid @RequestBody StatusRequest body) {
        requireCustomer(id);
        String current = db.queryForObject("SELECT status FROM users WHERE id = ?", String.class, id);
        if (!List.of("ACTIVE", "SUSPENDED").contains(current))
            throw new DomainException("STATUS_NOT_ALLOWED", "Chỉ có thể khóa hoặc mở khóa tài khoản đã xác minh.", HttpStatus.UNPROCESSABLE_ENTITY);
        db.update("UPDATE users SET status = ?, updated_at = ?, version = version + 1 WHERE id = ?", body.status(), clock.instant(), id);
        if (body.status().equals("SUSPENDED")) refresh.revokeAll(id, clock.instant());
        return ApiResponse.success(null);
    }
}
