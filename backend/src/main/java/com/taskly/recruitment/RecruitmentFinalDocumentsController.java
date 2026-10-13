package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1")
public class RecruitmentFinalDocumentsController {
 private final JdbcTemplate db;private final RecruitmentService recruitment;private final RecruitmentReviewService review;
 public RecruitmentFinalDocumentsController(JdbcTemplate db,RecruitmentService recruitment,RecruitmentReviewService review){this.db=db;this.recruitment=recruitment;this.review=review;}
 public record Images(@NotBlank @Size(max=2800000) String portrait,@NotBlank @Size(max=2800000) String contract){}
 @GetMapping("/partner/final-documents") public ApiResponse<List<Map<String,Object>>> own(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(rows(recruitment.current(UUID.fromString(jwt.getSubject())).id()));}
 @GetMapping("/admin/recruitment/applications/{id}/final-documents") @PreAuthorize("hasAuthority('RECRUITMENT_FINAL')") public ApiResponse<List<Map<String,Object>>> admin(@PathVariable UUID id){return ApiResponse.success(rows(id));}
 private List<Map<String,Object>> rows(UUID id){return db.queryForList("SELECT d.portrait,d.contract,d.submitted_at,(a.final_approved OR a.status IN ('ACTIVE','SUSPENDED')) AS read_only,(a.final_approved OR a.status IN ('ACTIVE','SUSPENDED')) AS approved FROM partner_final_documents d JOIN partner_applications a ON a.id=d.application_id WHERE d.application_id=?",id);}
 @PostMapping("/partner/final-documents") @Transactional public ApiResponse<RecruitmentDtos.Application> submit(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Images images){
  var user=UUID.fromString(jwt.getSubject());var app=recruitment.current(user);
  db.queryForObject("SELECT id FROM partner_applications WHERE id=? FOR UPDATE",UUID.class,app.id());
  app=recruitment.detail(app.id());
  if(Boolean.TRUE.equals(app.eligibility().get("final_approved"))||Set.of("ACTIVE","SUSPENDED").contains(app.status()))throw RecruitmentService.invalid("Hồ sơ đã được duyệt chính thức. Partner chỉ có thể xem, không được thay đổi.");
  if(!"APPROVED".equals(app.status()))throw RecruitmentService.invalid("Chờ admin xác nhận thủ tục trước khi gửi ảnh chặng 4.");
  for(var image:List.of(images.portrait(),images.contract())){if(!image.startsWith("data:image/jpeg;base64,")&&!image.startsWith("data:image/png;base64,"))throw RecruitmentService.invalid("Chọn ảnh JPG hoặc PNG.");try{var data=Base64.getDecoder().decode(image.substring(image.indexOf(',')+1));if(data.length<8||data.length>2000000||!((data[0]==(byte)0xff&&data[1]==(byte)0xd8)||(data[0]==(byte)0x89&&data[1]==0x50&&data[2]==0x4e&&data[3]==0x47)))throw new IllegalArgumentException();}catch(IllegalArgumentException e){throw RecruitmentService.invalid("Ảnh không hợp lệ hoặc vượt 2 MB.");}}
  db.update("INSERT INTO partner_final_documents VALUES(?,?,?,CURRENT_TIMESTAMP) ON CONFLICT(application_id) DO UPDATE SET portrait=EXCLUDED.portrait,contract=EXCLUDED.contract,submitted_at=CURRENT_TIMESTAMP",app.id(),images.portrait(),images.contract());
  db.update("UPDATE partner_applications SET status='FINAL_REVIEW',version=version+1,updated_at=CURRENT_TIMESTAMP WHERE id=?",app.id());
  recruitment.audit(user,app.id(),"FINAL_DOCUMENTS_SUBMITTED",app.status(),"FINAL_REVIEW","Đã gửi ảnh chân dung và hợp đồng chặng 4.");review.notify(app.id(),"Đã nhận ảnh chặng 4","Admin sẽ kiểm tra ảnh chân dung và hợp đồng trước khi duyệt chính thức, kích hoạt tài khoản.");return ApiResponse.success(recruitment.current(user));
 }
}
