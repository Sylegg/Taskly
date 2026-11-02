package com.taskly.recruitment;
import static org.junit.jupiter.api.Assertions.*;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;
class RecruitmentSlaTest {
 private RecruitmentSlaService.Calendar calendar(List<LocalDate> holidays){return new RecruitmentSlaService.Calendar(24,48,"Asia/Bangkok",9,18,holidays,0);}
 @Test void skipsWeekendAndHolidayAndPreservesReceiptAnchor(){
  // Friday 17:00 ICT: one working hour Friday, Monday holiday, then Tuesday 10:00.
  var received=Instant.parse("2026-10-09T10:00:00Z");
  assertEquals(Instant.parse("2026-10-13T03:00:00Z"),RecruitmentSlaService.afterWorkingHours(received,2,calendar(List.of(LocalDate.of(2026,10,12)))));
  assertEquals(Instant.parse("2026-10-09T10:00:00Z"),received);
 }
 @Test void beforeOpeningAndWeekendStartNormalizeToNextWorkingDay(){
  assertEquals(Instant.parse("2026-10-12T03:00:00Z"),RecruitmentSlaService.afterWorkingHours(Instant.parse("2026-10-10T00:00:00Z"),1,calendar(List.of())));
  assertEquals(Instant.parse("2026-10-09T03:00:00Z"),RecruitmentSlaService.afterWorkingHours(Instant.parse("2026-10-09T00:00:00Z"),1,calendar(List.of())));
 }
 @Test void spansMultipleWorkingDays(){
  assertEquals(Instant.parse("2026-10-13T08:00:00Z"),RecruitmentSlaService.afterWorkingHours(Instant.parse("2026-10-09T02:00:00Z"),24,calendar(List.of())));
 }
}
