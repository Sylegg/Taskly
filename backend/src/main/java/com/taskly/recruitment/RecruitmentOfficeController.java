package com.taskly.recruitment;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import static com.taskly.recruitment.RecruitmentOfficeService.*;
@RestController @RequestMapping("/api/v1")
public class RecruitmentOfficeController {
 private final RecruitmentOfficeService service;public RecruitmentOfficeController(RecruitmentOfficeService service){this.service=service;}
 @GetMapping("/partner/offices") public ApiResponse<List<Map<String,Object>>> offices(){return ApiResponse.success(service.offices());}
 @PostMapping("/partner/office-visit-confirmation") public ApiResponse<Map<String,Object>> confirmVisit(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.confirmVisit(user(jwt)));}
 @PostMapping("/admin/recruitment/applications/{id}/checkin") @PreAuthorize("hasAuthority('RECRUITMENT_RECEPTION')") public ApiResponse<Map<String,Object>> confirmCheckin(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return ApiResponse.success(service.confirmCheckin(user(jwt),id));}
 @GetMapping("/partner/appointment-slots") public ApiResponse<List<Map<String,Object>>> slots(){return ApiResponse.success(service.slots());}
 @GetMapping("/partner/appointments") public ApiResponse<List<Map<String,Object>>> appointments(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.appointments(user(jwt)));}
 @PostMapping("/partner/appointments") public ApiResponse<Map<String,Object>> book(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody AppointmentWrite w){return ApiResponse.success(service.book(user(jwt),w));}
 @PostMapping("/partner/appointments/{id}/cancel") public ApiResponse<Map<String,Object>> cancel(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){return ApiResponse.success(service.cancel(user(jwt),id));}
 @GetMapping("/partner/document-checklist") public ApiResponse<List<Map<String,Object>>> checklist(){return ApiResponse.success(service.checklist());}
 @GetMapping("/partner/document-receipts") public ApiResponse<List<Map<String,Object>>> receipts(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(service.receipts(user(jwt)));}
 @GetMapping("/admin/recruitment/appointments") @PreAuthorize("hasAuthority('RECRUITMENT_RECEPTION')") public ApiResponse<List<Map<String,Object>>> queue(){return ApiResponse.success(service.queue());}
 @GetMapping("/admin/recruitment/office-slots") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<List<Map<String,Object>>> adminSlots(){return ApiResponse.success(service.slots());}
 @PutMapping("/admin/recruitment/office-slots/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_CONFIG')") public ApiResponse<Map<String,Object>> save(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody SlotWrite w){return ApiResponse.success(service.saveSlot(user(jwt),id,w));}
 @GetMapping("/admin/recruitment/document-checklist") @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')") public ApiResponse<List<Map<String,Object>>> adminChecklist(){return ApiResponse.success(service.checklist());}
 @PutMapping("/admin/recruitment/document-checklist/{id}") @PreAuthorize("hasAuthority('RECRUITMENT_CONFIG')") public ApiResponse<Map<String,Object>> saveChecklist(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody ChecklistWrite w){return ApiResponse.success(service.saveChecklist(user(jwt),id,w));}
 @PostMapping("/admin/recruitment/appointments/{id}/checkin") @PreAuthorize("hasAuthority('RECRUITMENT_RECEPTION')") public ApiResponse<Map<String,Object>> checkin(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Checkin w){return ApiResponse.success(service.checkin(user(jwt),id,w));}
 @PostMapping("/admin/recruitment/appointments/{id}/receive-documents") @PreAuthorize("hasAuthority('RECRUITMENT_RECEPTION')") public ApiResponse<Map<String,Object>> receive(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Receive w){return ApiResponse.success(service.receive(user(jwt),id,w));}
 private UUID user(Jwt jwt){return UUID.fromString(jwt.getSubject());}
}
