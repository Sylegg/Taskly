package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import static com.taskly.recruitment.RecruitmentExamService.*;
@RestController @RequestMapping("/api/v1")
public class RecruitmentExamController {
 private final RecruitmentExamService service;public RecruitmentExamController(RecruitmentExamService service){this.service=service;}
 @GetMapping("/partner/exam") public ApiResponse<Map<String,Object>> config(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.partnerConfig(user(jwt)));}
 @GetMapping("/partner/exam/results") public ApiResponse<List<Attempt>> results(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.results(user(jwt)));}
 @PostMapping("/partner/exam/attempts") public ApiResponse<Attempt> start(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.start(user(jwt)));}
 @PutMapping("/partner/exam/attempts/{id}/answers") public ApiResponse<Attempt> save(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody AnswerWrite w){return ApiResponse.success(service.saveAnswers(user(jwt),id,w));}
 @PostMapping("/partner/exam/attempts/{id}/submit") public ApiResponse<Attempt> submit(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody AnswerWrite w){return ApiResponse.success(service.submit(user(jwt),id,w));}
 @GetMapping("/admin/recruitment/questions") @PreAuthorize("hasAuthority('RECRUITMENT_TRAINING')") public ApiResponse<List<Question>> questions(){return ApiResponse.success(service.questions());}
 @PutMapping("/admin/recruitment/questions/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_TRAINING')") public ApiResponse<Question> question(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody QuestionWrite w){return ApiResponse.success(service.save(user(jwt),id,w));}
 @DeleteMapping("/admin/recruitment/questions/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_TRAINING')") public ApiResponse<Void> delete(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){service.remove(user(jwt),id);return ApiResponse.success(null);}
 @GetMapping("/admin/recruitment/exam-config") @PreAuthorize("hasAuthority('RECRUITMENT_TRAINING')") public ApiResponse<Map<String,Object>> adminConfig(){return ApiResponse.success(service.config());}
 @PutMapping("/admin/recruitment/exam-config") @PreAuthorize("hasAuthority('RECRUITMENT_TRAINING')") public ApiResponse<Map<String,Object>> config(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody ConfigWrite w){return ApiResponse.success(service.saveConfig(user(jwt),w));}
 private UUID user(Jwt jwt){return UUID.fromString(jwt.getSubject());}
}
