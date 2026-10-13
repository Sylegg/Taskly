package com.taskly.task;
import java.util.*;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.junit.jupiter.api.Assertions.*;
class TaskTravelWindowTest {
 @Test void allowsTravelFromExactlyFifteenMinutesBeforeAppointment() {
  var db=mock(JdbcTemplate.class); var task=UUID.randomUUID(); var partner=UUID.randomUUID();
  var scheduled=Instant.parse("2026-10-14T07:00:00Z");
  when(db.query(anyString(),org.mockito.ArgumentMatchers.<RowMapper<Instant>>any(),eq(task),eq(partner))).thenReturn(List.of(scheduled));
  when(db.queryForObject(anyString(),eq(Integer.class),eq(task),eq(partner))).thenReturn(0);
  assertFalse(TaskTravelPolicy.canTravel(db,task,partner,scheduled.minusSeconds(901)));
  assertTrue(TaskTravelPolicy.canTravel(db,task,partner,scheduled.minusSeconds(900)));
  assertTrue(TaskTravelPolicy.canTravel(db,task,partner,scheduled.minusSeconds(60)));
  assertTrue(TaskTravelPolicy.canTravel(db,task,partner,scheduled));
 }
}
