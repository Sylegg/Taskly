package com.taskly.recruitment;

import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RecruitmentDossierService {
 private final JdbcTemplate db;
 private final RecruitmentService recruitment;
 public RecruitmentDossierService(JdbcTemplate db,RecruitmentService recruitment){this.db=db;this.recruitment=recruitment;}
 public record Dossier(RecruitmentDtos.Application application,List<Map<String,Object>> areas,
  List<Map<String,Object>> services,List<Map<String,Object>> exams,List<Map<String,Object>> lessons,
  List<Map<String,Object>> agreements,List<Map<String,Object>> identities,List<Map<String,Object>> documents,
  List<Map<String,Object>> uniforms,List<Map<String,Object>> appointments,List<Map<String,Object>> receipts,
  List<Map<String,Object>> decisions,List<Map<String,Object>> timeline,List<Map<String,Object>> documentChecklist,
  List<Map<String,Object>> availability,List<Map<String,Object>> identityHistory) {}

 @Transactional(readOnly=true) public Dossier detail(UUID id,boolean personalDetails,boolean identityDetails){
  var app=recruitment.dossierApplication(id,personalDetails);
  return new Dossier(app,
   rows("SELECT a.city,a.name,a.recruiting FROM recruitment_areas a JOIN partner_application_areas l ON l.area_id=a.id WHERE l.application_id=? ORDER BY a.city,a.name",id),
   rows("SELECT s.name FROM services s JOIN partner_application_services l ON l.service_id=s.id WHERE l.application_id=? ORDER BY s.name",id),
   rows("SELECT status,score,pass_mark,started_at,submitted_at,questions,answers FROM recruitment_exam_attempts WHERE application_id=? ORDER BY started_at",id),
   rows("SELECT l.title,l.required,p.watched_seconds,l.duration_seconds,p.quiz_passed,p.completed_at,p.lesson_version,l.version AS current_version FROM partner_training_lessons l LEFT JOIN partner_learning_progress p ON p.lesson_id=l.id AND p.application_id=? WHERE l.active=true OR p.application_id IS NOT NULL ORDER BY l.display_order,l.id",id),
   rows("SELECT t.document_type,t.version,t.content_url,c.accepted_at,t.active FROM terms_versions t JOIN user_consents c ON c.terms_version_id=t.id WHERE c.user_id=? AND t.document_type LIKE 'PARTNER_%' ORDER BY c.accepted_at",app.userId()),
   identityDetails?rows("SELECT id,status,legal_name,document_type,document_number_masked,document_number,submitted_at,reviewed_at,decision_reason FROM identity_verifications WHERE user_id=? ORDER BY created_at DESC",app.userId()):rows("SELECT status,submitted_at,reviewed_at FROM identity_verifications WHERE user_id=? ORDER BY created_at DESC",app.userId()),
   identityDetails?rows("SELECT d.id,d.verification_id,d.document_side,o.scan_status,d.created_at FROM verification_documents d JOIN stored_objects o ON o.id=d.stored_object_id JOIN identity_verifications v ON v.id=d.verification_id WHERE v.user_id=? ORDER BY d.created_at",app.userId()):List.of(),
   rows("SELECT o.id,p.name,o.size,o.price,o.payment_method,o.payment_status,o.status,o.created_at,o.handed_over_at FROM partner_uniform_orders o JOIN partner_uniform_packages p ON p.id=o.package_id WHERE o.application_id=? ORDER BY o.created_at",id),
   rows("SELECT a.id,s.name,s.address,s.starts_at,a.status,a.created_at,a.checked_in_at FROM partner_office_appointments a JOIN partner_office_slots s ON s.id=a.slot_id WHERE a.application_id=? ORDER BY a.created_at",id),
   rows("SELECT originals_returned,complete,notes,checklist,received_at FROM partner_document_receipts WHERE application_id=? ORDER BY received_at",id),
   rows("SELECT level,action,reason,required_changes,reviewed_at FROM partner_review_decisions WHERE application_id=? ORDER BY reviewed_at",id),
   rows("SELECT action,before_status,after_status,reason,created_at FROM recruitment_audit WHERE application_id=? ORDER BY created_at,id",id),
   rows("SELECT id,label,required FROM partner_document_checklist WHERE active=true ORDER BY label"),
   rows("SELECT starts_at,ends_at FROM partner_availability WHERE application_id=?",id),
   identityDetails?rows("SELECT h.from_status,h.to_status,h.reason,h.created_at FROM verification_history h JOIN identity_verifications v ON v.id=h.verification_id WHERE v.user_id=? ORDER BY h.created_at",app.userId()):List.of());
 }
 private List<Map<String,Object>> rows(String sql,Object... args){
  return db.queryForList(sql,args).stream().map(row->{
   Map<String,Object> normalized=new LinkedHashMap<>();
   row.forEach((key,value)->normalized.put(key.toLowerCase(Locale.ROOT),
    value instanceof Timestamp t?t.toInstant():value instanceof OffsetDateTime t?t.toInstant():value));
   return normalized;
  }).toList();
 }
}
