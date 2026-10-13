package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import static com.taskly.recruitment.RecruitmentActivationService.*;
@RestController @RequestMapping("/api/v1")
public class RecruitmentActivationController {
 private final RecruitmentActivationService service;public RecruitmentActivationController(RecruitmentActivationService service){this.service=service;}
 @PostMapping("/admin/recruitment/applications/{id}/reopen-at-office") @PreAuthorize("hasAuthority('RECRUITMENT_PRELIMINARY') and hasAuthority('RECRUITMENT_RECEPTION')") public ApiResponse<RecruitmentDtos.Application> reopenAtOffice(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody OfficeReopen w){return ApiResponse.success(service.reopenAtOffice(user(jwt),id,w));}
 @GetMapping("/admin/recruitment/appeals") @PreAuthorize("hasAuthority('RECRUITMENT_FINAL')") public ApiResponse<List<Map<String,Object>>> appeals(){return ApiResponse.success(service.appeals());}
 @PostMapping("/admin/recruitment/appeals/{id}/resolve") @PreAuthorize("hasAuthority('RECRUITMENT_FINAL')") public ApiResponse<RecruitmentDtos.Application> resolve(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody AppealDecision w){return ApiResponse.success(service.resolveAppeal(user(jwt),id,w));}
 @PostMapping("/admin/recruitment/applications/{id}/final-decision") @PreAuthorize("hasAuthority('RECRUITMENT_FINAL')") public ApiResponse<RecruitmentDtos.Application> decide(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody RecruitmentReviewService.Decision w){return ApiResponse.success(service.finalDecision(user(jwt),id,w));}
 @PostMapping("/partner/activation") public ApiResponse<RecruitmentDtos.Application> activate(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Activation w){return ApiResponse.success(service.activate(user(jwt),w));}
 @PostMapping("/partner/appeals") public ApiResponse<RecruitmentDtos.Application> appeal(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Appeal w){return ApiResponse.success(service.appeal(user(jwt),w));}
 @GetMapping("/partner/onboarding/sla") public ApiResponse<Map<String,Object>> sla(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.sla(user(jwt)));}
 @GetMapping("/partner/jobs") public ApiResponse<List<Map<String,Object>>> feed(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.feed(user(jwt)));}
 @GetMapping("/partner/jobs/{id}/availability") public ApiResponse<Map<String,Object>> availability(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return ApiResponse.success(service.previewAvailability(user(jwt),id));}
 @GetMapping("/partner/my-schedule") public ApiResponse<List<Map<String,Object>>> schedule(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.timeline(user(jwt)));}
 @PostMapping("/partner/jobs/{id}/accept") public ApiResponse<Map<String,Object>> accept(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return ApiResponse.success(service.accept(user(jwt),id));}
 @PostMapping("/partner/jobs/{id}/status") public ApiResponse<Map<String,Object>> progress(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody JobStatus w){return ApiResponse.success(service.progressJob(user(jwt),id,w));}
 private UUID user(Jwt jwt){return UUID.fromString(jwt.getSubject());}
 @PostMapping("/partner/jobs/{id}/complete") public ApiResponse<Map<String,Object>> complete(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Completion body){return ApiResponse.success(service.completeWithPhotos(user(jwt),id,body));}
}
