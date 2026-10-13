package com.taskly.recruitment;

import jakarta.validation.constraints.*;
import java.time.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
public class RecruitmentSlaService {
 public record Calendar(@Min(1) @Max(720) int minimumHours,@Min(1) @Max(720) int maximumHours,@NotBlank @Size(max=100) String timezone,@Min(0) @Max(23) int startHour,@Min(1) @Max(24) int endHour,@NotNull @Size(max=366) List<@NotNull LocalDate> holidays,@PositiveOrZero long version) {}
 private final JdbcTemplate db;private final RecruitmentService recruitment;private final ObjectMapper json=new ObjectMapper();
 public RecruitmentSlaService(JdbcTemplate db,RecruitmentService recruitment){this.db=db;this.recruitment=recruitment;}
 public Calendar config(){var row=db.queryForMap("SELECT c.*,p.sla_min_hours,p.sla_max_hours FROM partner_sla_calendar c JOIN recruitment_policy p ON p.id=c.id WHERE c.id=1");return new Calendar(((Number)row.get("sla_min_hours")).intValue(),((Number)row.get("sla_max_hours")).intValue(),(String)row.get("timezone"),((Number)row.get("start_hour")).intValue(),((Number)row.get("end_hour")).intValue(),json.readValue((String)row.get("holidays"),new TypeReference<List<LocalDate>>(){}),((Number)row.get("version")).longValue());}
 @Transactional public Calendar save(UUID actor,Calendar value){
  try{ZoneId.of(value.timezone());}catch(DateTimeException e){throw RecruitmentService.invalid("Múi giờ không hợp lệ.");}
  if(value.maximumHours()<value.minimumHours()||value.endHour()<=value.startHour())throw RecruitmentService.invalid("Khoảng SLA và giờ làm việc không hợp lệ.");
  if(db.update("UPDATE partner_sla_calendar SET timezone=?,start_hour=?,end_hour=?,holidays=?,version=version+1 WHERE id=1 AND version=?",value.timezone(),value.startHour(),value.endHour(),json.writeValueAsString(value.holidays().stream().distinct().sorted().toList()),value.version())!=1)throw RecruitmentService.conflict();
  db.update("UPDATE recruitment_policy SET sla_min_hours=?,sla_max_hours=?,version=version+1 WHERE id=1",value.minimumHours(),value.maximumHours());
  recruitment.audit(actor,null,"SLA_CALENDAR_UPDATED",null,null,"Giờ làm việc và ngày nghỉ");return config();
 }
 public static Instant afterWorkingHours(Instant received,int hours,Calendar config){
  var zone=ZoneId.of(config.timezone());var holidays=new HashSet<>(config.holidays());long remaining=hours*3600L;var cursor=received;
  for(int day=0;day<20000;day++){
   var date=cursor.atZone(zone).toLocalDate();var opening=date.atTime(config.startHour(),0).atZone(zone).toInstant();var closing=(config.endHour()==24?date.plusDays(1).atStartOfDay():date.atTime(config.endHour(),0)).atZone(zone).toInstant();
   if(date.getDayOfWeek()==DayOfWeek.SATURDAY||date.getDayOfWeek()==DayOfWeek.SUNDAY||holidays.contains(date)||!cursor.isBefore(closing)){cursor=date.plusDays(1).atStartOfDay(zone).toInstant();continue;}
   if(cursor.isBefore(opening))cursor=opening;long available=Duration.between(cursor,closing).getSeconds();
   if(remaining<=available)return cursor.plusSeconds(remaining);remaining-=available;cursor=date.plusDays(1).atStartOfDay(zone).toInstant();
  }
  throw new IllegalStateException("SLA calendar exceeded bounded calculation");
 }
 public Map<String,Object> window(Instant received){var config=config();var result=new LinkedHashMap<String,Object>();result.put("sla_min_hours",config.minimumHours());result.put("sla_max_hours",config.maximumHours());result.put("timezone",config.timezone());result.put("workingHours",true);result.put("documentsReceivedAt",received);if(received!=null){result.put("expectedFrom",afterWorkingHours(received,config.minimumHours(),config));result.put("expectedUntil",afterWorkingHours(received,config.maximumHours(),config));}return result;}
}
