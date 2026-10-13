package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import static com.taskly.recruitment.RecruitmentReviewService.*;
@RestController @RequestMapping("/api/v1")
public class RecruitmentReviewController {
 private final RecruitmentReviewService service;public RecruitmentReviewController(RecruitmentReviewService service){this.service=service;}
 @GetMapping("/partner/agreements") public ApiResponse<List<Agreement>> agreements(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.agreements(user(jwt)));}
 @PostMapping("/partner/agreements/{id}/accept") public ApiResponse<RecruitmentDtos.Application> accept(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return ApiResponse.success(service.accept(user(jwt),id));}
 @PostMapping("/partner/agreements/accept-all") public ApiResponse<RecruitmentDtos.Application> acceptAll(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.acceptAll(user(jwt)));}
 @PostMapping("/partner/kyc/submit") public ApiResponse<RecruitmentDtos.Application> submit(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.submitProfile(user(jwt)));}
 @PostMapping("/partner/kyc/demo") public ApiResponse<RecruitmentDtos.Application> demo(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.demoIdentity(user(jwt)));}
 @GetMapping("/partner/notifications") public ApiResponse<List<Map<String,Object>>> notifications(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.controllerNotifications(user(jwt)));}
 @PostMapping("/partner/notifications/read") public ApiResponse<Map<String,Object>> readNotifications(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody RecruitmentReviewService.ReadNotifications request){return ApiResponse.success(service.markNotificationsRead(user(jwt),request));}
 @PostMapping("/partner/notifications/read-all") public ApiResponse<Map<String,Object>> readAllNotifications(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.markAllNotificationsRead(user(jwt)));}
 @PostMapping("/partner/notifications/{id}/read") public ApiResponse<Map<String,Object>> readSingleNotification(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return ApiResponse.success(service.markSingleNotificationRead(user(jwt),id));}
 @GetMapping("/admin/recruitment/agreements") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<List<Agreement>> adminAgreements(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.agreements(user(jwt)));}
 @PutMapping("/admin/recruitment/agreements/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_CONFIG')") public ApiResponse<Agreement> save(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody AgreementWrite w){return ApiResponse.success(service.saveAgreement(user(jwt),id,w));}
 @PostMapping("/admin/recruitment/applications/{id}/preliminary-decision") @PreAuthorize("hasAuthority('RECRUITMENT_PRELIMINARY')") public ApiResponse<RecruitmentDtos.Application> preliminary(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Decision w){return ApiResponse.success(service.preliminary(user(jwt),id,w));}
 private UUID user(Jwt jwt){return UUID.fromString(jwt.getSubject());}
}
