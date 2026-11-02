package com.taskly.task;
import com.taskly.common.exception.DomainException;
import java.time.*;
import java.sql.Timestamp;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;

public final class PartnerWorkPolicy {
 private PartnerWorkPolicy() {}
 public static void lock(JdbcTemplate db,UUID partner){
  db.queryForList("SELECT id FROM users WHERE id=? FOR UPDATE",partner);
 }
 public static boolean hasOtherWork(JdbcTemplate db,UUID partner,UUID task){
  return db.queryForObject("SELECT COUNT(*) FROM tasks WHERE tasker_id=? AND id<>? AND status IN ('TASKER_ON_THE_WAY','ARRIVED','IN_PROGRESS')",Integer.class,partner,task)>0;
 }
 public static final String BUSY_MESSAGE="Bạn đang thực hiện một công việc. Vui lòng hoàn thành hoặc kết thúc công việc đó trước khi làm dịch vụ khác.";
 public static void requireFree(JdbcTemplate db,UUID partner,UUID task){
  if(hasOtherWork(db,partner,task))throw new DomainException("PARTNER_WORK_IN_PROGRESS",BUSY_MESSAGE,HttpStatus.CONFLICT);
 }
 public record Limit(String code,String message) {}
 public static Limit bookingLimit(JdbcTemplate db,UUID partner,UUID task,Instant start,Instant now){
  var zone=ZoneId.of("Asia/Ho_Chi_Minh");var today=now.atZone(zone).toLocalDate();
  var date=start.atZone(zone).toLocalDate();
  var dayStart=Timestamp.from(today.atStartOfDay(zone).toInstant());
  var tomorrow=Timestamp.from(today.plusDays(1).atStartOfDay(zone).toInstant());
  if(date.equals(today)) {
   int count=db.queryForObject("SELECT COUNT(*) FROM tasks WHERE tasker_id=? AND id<>? AND scheduled_at>=? AND scheduled_at<? AND status IN ('ACCEPTED','TASKER_ON_THE_WAY','ARRIVED','IN_PROGRESS','COMPLETED','PAID','DISPUTED')",Integer.class,partner,task,dayStart,tomorrow);
   if(count>=3)return new Limit("PARTNER_DAILY_LIMIT","Bạn đã nhận đủ 3 lịch trong hôm nay. Không thể nhận thêm lịch hôm nay.");
  } else if(date.isAfter(today)) {
   int count=db.queryForObject("SELECT COUNT(*) FROM tasks WHERE tasker_id=? AND id<>? AND scheduled_at>=? AND status IN ('ACCEPTED','TASKER_ON_THE_WAY','ARRIVED','IN_PROGRESS','DISPUTED')",Integer.class,partner,task,tomorrow);
   if(count>=1)return new Limit("PARTNER_ADVANCE_LIMIT","Bạn đã có 1 dịch vụ đặt trước cho các ngày sau. Vui lòng kết thúc hoặc hủy dịch vụ đó trước khi nhận thêm.");
  }
  return null;
 }
}
