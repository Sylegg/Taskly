package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import static com.taskly.recruitment.RecruitmentUniformService.*;
@RestController @RequestMapping("/api/v1")
public class RecruitmentUniformController {
 private final RecruitmentUniformService service;public RecruitmentUniformController(RecruitmentUniformService service){this.service=service;}
 @PostMapping("/partner/uniform-orders/{id}/cash-payment") public ApiResponse<Map<String,Object>> chooseCash(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return ApiResponse.success(service.chooseCash(user(jwt),id));}
 @PostMapping("/admin/recruitment/uniform-orders/{id}/adjust") @PreAuthorize("hasAuthority('RECRUITMENT_FINANCE')") public ApiResponse<Map<String,Object>> adjust(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Adjustment w){return ApiResponse.success(service.adjust(user(jwt),id,w));}
 @GetMapping("/partner/uniforms") public ApiResponse<List<RecruitmentUniformService.Package>> catalog(){return ApiResponse.success(service.catalog().stream().filter(RecruitmentUniformService.Package::active).toList());}
 @GetMapping("/partner/uniform-orders") public ApiResponse<List<Map<String,Object>>> orders(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.orders(user(jwt)));}
 @PostMapping("/partner/uniform-orders") public ApiResponse<Map<String,Object>> order(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody OrderWrite w){return ApiResponse.success(service.order(user(jwt),w));}
 @PostMapping("/partner/uniform-orders/{id}/payment") public ApiResponse<Map<String,Object>> payment(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Payment w){return ApiResponse.success(service.sandboxPay(user(jwt),id,w));}
 @PostMapping("/partner/uniform-orders/{id}/cancel") public ApiResponse<Map<String,Object>> cancel(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return ApiResponse.success(service.cancel(user(jwt),id));}
 @GetMapping("/admin/recruitment/uniforms") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<List<RecruitmentUniformService.Package>> admin(){return ApiResponse.success(service.catalog());}
 @PutMapping("/admin/recruitment/uniforms/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_CONFIG')") public ApiResponse<RecruitmentUniformService.Package> save(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody PackageWrite w){return ApiResponse.success(service.save(user(jwt),id,w));}
 @GetMapping("/admin/recruitment/uniform-orders") @PreAuthorize("hasAuthority('RECRUITMENT_FINANCE')") public ApiResponse<List<Map<String,Object>>> queue(){return ApiResponse.success(service.queue());}
 @PostMapping("/admin/recruitment/uniform-orders/{id}/confirm-office-payment") @PreAuthorize("hasAuthority('RECRUITMENT_FINANCE')") public ApiResponse<Map<String,Object>> confirm(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return ApiResponse.success(service.confirmOffice(user(jwt),id));}
 private UUID user(Jwt jwt){return UUID.fromString(jwt.getSubject());}
}
