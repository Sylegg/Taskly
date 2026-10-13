package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/admin/recruitment") @PreAuthorize("hasAuthority('RECRUITMENT_CONFIG')")
public class RecruitmentCommunicationsController {
 private final RecruitmentCommunicationsService service;public RecruitmentCommunicationsController(RecruitmentCommunicationsService service){this.service=service;}
 @GetMapping("/message-templates") public ApiResponse<List<Map<String,Object>>> templates(){return ApiResponse.success(service.templates());}
 @PutMapping("/message-templates/{id}") public ApiResponse<Map<String,Object>> save(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody RecruitmentCommunicationsService.TemplateWrite w){return ApiResponse.success(service.save(UUID.fromString(jwt.getSubject()),id,w));}
 @GetMapping("/outbox") public ApiResponse<List<Map<String,Object>>> outbox(){return ApiResponse.success(service.outbox());}
 @PostMapping("/outbox/{id}/retry") public ApiResponse<Map<String,Object>> retry(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody RecruitmentCommunicationsService.Retry w){return ApiResponse.success(service.retry(UUID.fromString(jwt.getSubject()),id,w));}
}
