package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import static com.taskly.recruitment.RecruitmentTrainingService.*;
@RestController @RequestMapping("/api/v1")
public class RecruitmentTrainingController {
 private final RecruitmentTrainingService service;public RecruitmentTrainingController(RecruitmentTrainingService service){this.service=service;}
 @GetMapping("/partner/training/courses") public ApiResponse<List<Progress>> courses(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.progress(user(jwt)));}
 @PostMapping("/partner/training/lessons/{id}/progress") public ApiResponse<Progress> heartbeat(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Heartbeat w){return ApiResponse.success(service.heartbeat(user(jwt),id,w));}
 @PostMapping("/partner/training/lessons/{id}/complete") public ApiResponse<Progress> quiz(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Quiz w){return ApiResponse.success(service.complete(user(jwt),id,w));}
 @GetMapping("/admin/recruitment/lessons") @PreAuthorize("hasAuthority('RECRUITMENT_TRAINING')") public ApiResponse<List<Map<String,Object>>> lessons(){return ApiResponse.success(service.adminLessons());}
 @PutMapping("/admin/recruitment/lessons/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_TRAINING')") public ApiResponse<Lesson> save(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody LessonWrite w){return ApiResponse.success(service.save(user(jwt),id,w));}
 private UUID user(Jwt jwt){return UUID.fromString(jwt.getSubject());}
}
