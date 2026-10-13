package com.taskly.task;
import java.util.*;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import com.taskly.settings.SystemSettingsService;
import com.taskly.recruitment.PartnerSchedulingService;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.junit.jupiter.api.Assertions.*;
class CompletedScheduleTest {
 @Test void endedJobCannotReserveBuffer() {
  var db=mock(JdbcTemplate.class); var settings=mock(SystemSettingsService.class);
  when(settings.getMinBufferMinutes()).thenReturn(60);
  when(db.queryForObject(anyString(),eq(Integer.class),any(),any(),any(),any())).thenReturn(0);
  when(db.queryForObject(anyString(),eq(Integer.class),any(),any(),any())).thenReturn(0);
  when(db.queryForList(anyString(),any(),any(),any())).thenReturn(List.of(Map.of("status","COMPLETED")));
  var result=new PartnerSchedulingService(db,settings).validateSchedule(UUID.randomUUID(),UUID.randomUUID(),Instant.now().plusSeconds(60),120,null,null);
  assertTrue(result.eligible());
 }
}
