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
public class RecruitmentBenefitsController {
 public record Write(@NotBlank @Size(max=160) String name,@NotBlank @Size(max=2000) String description,@NotNull @Size(max=1000) String contentUrl,boolean requiresActive,boolean active,@PositiveOrZero long version) {}
 private final JdbcTemplate db;private final RecruitmentService recruitment;private final RecruitmentReviewService review;
 public RecruitmentBenefitsController(JdbcTemplate db,RecruitmentService recruitment,RecruitmentReviewService review){this.db=db;this.recruitment=recruitment;this.review=review;}
 @GetMapping("/partner/benefits") @Transactional public ApiResponse<List<Map<String,Object>>> partner(@AuthenticationPrincipal Jwt jwt){
  var user=UUID.fromString(jwt.getSubject());var app=recruitment.current(user);boolean active=app.status().equals("ACTIVE")&&Boolean.TRUE.equals(app.eligibility().get("final_approved"))&&review.identityReady(user)&&review.agreementsReady(user);
  return ApiResponse.success(db.queryForList("SELECT * FROM partner_benefits WHERE active=true ORDER BY name,id").stream().map(row->{boolean eligible=!Boolean.TRUE.equals(row.get("requires_active"))||active;row.put("eligible",eligible);if(!eligible)row.put("content_url","");return row;}).toList());
 }
 @GetMapping("/admin/recruitment/benefits") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<List<Map<String,Object>>> list(){return ApiResponse.success(db.queryForList("SELECT * FROM partner_benefits ORDER BY name,id"));}
 @PutMapping("/admin/recruitment/benefits/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_CONFIG')") @Transactional public ApiResponse<Map<String,Object>> save(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Write w){
  if(!w.contentUrl().isBlank()){var uri=java.net.URI.create(w.contentUrl());if(!"https".equals(uri.getScheme())||uri.getHost()==null||uri.getUserInfo()!=null)throw RecruitmentService.invalid("Nội dung phúc lợi cần URL HTTPS hợp lệ.");}
  if(db.queryForObject("SELECT COUNT(*) FROM partner_benefits WHERE id=?",Integer.class,id)>0){if(db.update("UPDATE partner_benefits SET name=?,description=?,content_url=?,requires_active=?,active=?,version=version+1 WHERE id=? AND version=?",w.name(),w.description(),w.contentUrl(),w.requiresActive(),w.active(),id,w.version())!=1)throw RecruitmentService.conflict();}
  else{if(w.version()!=0)throw RecruitmentService.conflict();db.update("INSERT INTO partner_benefits VALUES(?,?,?,?,?,?,0)",id,w.name(),w.description(),w.contentUrl(),w.requiresActive(),w.active());}
  recruitment.audit(UUID.fromString(jwt.getSubject()),null,"BENEFIT_UPDATED",null,null,"Phúc lợi "+id);return ApiResponse.success(db.queryForMap("SELECT * FROM partner_benefits WHERE id=?",id));
 }
}
