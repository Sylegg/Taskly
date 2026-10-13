package com.taskly.recruitment;

import com.taskly.common.api.ApiResponse;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/admin/recruitment")
public class RecruitmentDashboardController {
 private final JdbcTemplate db;private final RecruitmentSlaService sla;
 public RecruitmentDashboardController(JdbcTemplate db,RecruitmentSlaService sla){this.db=db;this.sla=sla;}
 @GetMapping("/summary")
 @PreAuthorize("hasAuthority('RECRUITMENT_VIEW')")
 @Transactional(readOnly=true)
 public ApiResponse<Map<String,Object>> summary(){
  var now=Instant.now();var calendar=sla.config();
  var result=new LinkedHashMap<String,Object>();
  result.put("total",db.queryForObject("SELECT COUNT(*) FROM partner_applications",Long.class));
  result.put("statuses",db.queryForList("SELECT status,COUNT(*) AS total FROM partner_applications GROUP BY status ORDER BY status"));
  result.put("awaitingReview",db.queryForObject("SELECT COUNT(*) FROM partner_applications WHERE status IN ('PRELIMINARY_REVIEW','DOCUMENTS_RECEIVED','FINAL_REVIEW','ESCALATED')",Long.class));
  result.put("overdueWorkingHours",db.query("SELECT documents_received_at FROM partner_applications WHERE status IN ('DOCUMENTS_RECEIVED','FINAL_REVIEW') AND documents_received_at IS NOT NULL",(r,n)->r.getTimestamp(1).toInstant()).stream().filter(received->RecruitmentSlaService.afterWorkingHours(received,calendar.maximumHours(),calendar).isBefore(now)).count());
  result.put("openAppeals",db.queryForObject("SELECT COUNT(*) FROM partner_appeals WHERE status='OPEN'",Long.class));
  result.put("failedEmailMocks",db.queryForObject("SELECT COUNT(*) FROM partner_notification_outbox WHERE channel='EMAIL' AND status='FAILED'",Long.class));
  result.put("generatedAt",now);
  return ApiResponse.success(result);
 }
}
