package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/admin/recruitment/sla-calendar")
public class RecruitmentSlaController {
 private final RecruitmentSlaService service;public RecruitmentSlaController(RecruitmentSlaService service){this.service=service;}
 @GetMapping @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<RecruitmentSlaService.Calendar> get(){return ApiResponse.success(service.config());}
 @PutMapping @PreAuthorize("hasAuthority('RECRUITMENT_CONFIG')") public ApiResponse<RecruitmentSlaService.Calendar> save(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody RecruitmentSlaService.Calendar value){return ApiResponse.success(service.save(UUID.fromString(jwt.getSubject()),value));}
}
