package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import static com.taskly.recruitment.RecruitmentDtos.*;

@RestController @RequestMapping("/api/v1")
public class RecruitmentController {
 private final RecruitmentService service;
 private final RecruitmentDossierService dossiers;
 public RecruitmentController(RecruitmentService service,RecruitmentDossierService dossiers) {this.service=service;this.dossiers=dossiers;}
 @GetMapping("/admin/recruitment/applications/{id}/dossier") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')")
 public ApiResponse<RecruitmentDossierService.Dossier> dossier(@PathVariable UUID id,org.springframework.security.core.Authentication authentication) {
  var authorities=authentication.getAuthorities().stream().map(org.springframework.security.core.GrantedAuthority::getAuthority).toList();
  return ApiResponse.success(dossiers.detail(id,authorities.stream().anyMatch(a->Set.of("RECRUITMENT_PRELIMINARY","RECRUITMENT_FINAL","KYC_REVIEW").contains(a)),authorities.contains("KYC_REVIEW")));
 }
 @GetMapping("/partner/onboarding") public ApiResponse<Application> current(@AuthenticationPrincipal Jwt jwt) {return ApiResponse.success(service.current(user(jwt)));}
 @PutMapping("/partner/onboarding") public ApiResponse<Application> save(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Registration w) {return ApiResponse.success(service.save(user(jwt),w));}
 @PostMapping("/partner/onboarding/submit") public ApiResponse<Application> submit(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Submit w) {return ApiResponse.success(service.submit(user(jwt),w));}
 @GetMapping("/partner/work-areas") public ApiResponse<RecruitmentService.WorkAreas> workAreas(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.workAreas(user(jwt)));}
 @PutMapping("/partner/work-areas") public ApiResponse<RecruitmentService.WorkAreas> workAreas(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody RecruitmentService.WorkAreasWrite w){return ApiResponse.success(service.saveWorkAreas(user(jwt),w));}
 @GetMapping("/public/work-areas") public ApiResponse<List<Area>> customerAreas() {return ApiResponse.success(service.areas());}
 @GetMapping("/partner/recruitment-areas") public ApiResponse<List<Area>> areas() {return ApiResponse.success(service.recruitingAreas());}
 @GetMapping("/admin/recruitment/applications") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<List<Application>> queue() {return ApiResponse.success(service.queue());}
 @GetMapping("/admin/recruitment/applications-page") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<RecruitmentService.ApplicationPage> page(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="50") int size,@RequestParam(defaultValue="") String query,@RequestParam(defaultValue="") String status,@RequestParam(required=false) UUID area,@RequestParam(required=false) UUID service){return ApiResponse.success(this.service.page(page,size,query,status,area,service));}
 @GetMapping("/admin/recruitment/applications/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<Application> detail(@PathVariable UUID id) {return ApiResponse.success(service.detail(id));}
 @GetMapping("/admin/recruitment/areas") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<List<Area>> adminAreas() {return ApiResponse.success(service.areas());}
 @PutMapping("/admin/recruitment/areas/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_CONFIG')") public ApiResponse<Area> area(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody AreaWrite w) {return ApiResponse.success(service.saveArea(user(jwt),id,w));}
 @DeleteMapping("/admin/recruitment/areas/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_CONFIG')") public ApiResponse<Void> deleteArea(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {service.deleteArea(user(jwt),id); return ApiResponse.success(null);}
 @GetMapping("/admin/recruitment/audit") @PreAuthorize("hasAuthority('AUDIT_VIEW')") public ApiResponse<List<Map<String,Object>>> audit() {return ApiResponse.success(service.auditLog());}
 private UUID user(Jwt jwt) {return UUID.fromString(jwt.getSubject());}
}
