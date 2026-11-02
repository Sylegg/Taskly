package com.taskly.task;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import com.taskly.recruitment.PartnerSchedulingService;
import com.taskly.settings.SystemSettingsService;
import com.taskly.common.exception.DomainException;

class EarlyStartExpiryTest {
 static class MutableClock extends Clock {
  Instant now=Instant.parse("2026-10-20T07:00:00Z");
  public ZoneId getZone(){return ZoneOffset.UTC;}
  public Clock withZone(ZoneId zone){return this;}
  public Instant instant(){return now;}
 }
 JdbcTemplate db;
 EarlyStartService service;
 MutableClock clock;
 UUID task,customer,partner,request;
 Instant scheduled,expiry,requested;
 @BeforeEach void setup() {
  var source=new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1","sa","");
  db=new JdbcTemplate(source);clock=new MutableClock();
  db.execute("CREATE TABLE tasks(id UUID PRIMARY KEY,customer_id UUID,tasker_id UUID,status VARCHAR(32),scheduled_at TIMESTAMP WITH TIME ZONE,estimated_duration_minutes INTEGER,original_scheduled_start_at TIMESTAMP WITH TIME ZONE,approved_start_at TIMESTAMP WITH TIME ZONE,checked_in_at TIMESTAMP WITH TIME ZONE,actual_started_at TIMESTAMP WITH TIME ZONE,expected_end_at TIMESTAMP WITH TIME ZONE,verified_actual_end_at TIMESTAMP WITH TIME ZONE,latitude DECIMAL,longitude DECIMAL,service_name_snapshot VARCHAR(200),version BIGINT DEFAULT 0,updated_at TIMESTAMP WITH TIME ZONE,early_start_request_id UUID)");
  db.execute("CREATE TABLE early_start_requests(id UUID PRIMARY KEY,task_id UUID,partner_id UUID,requested_start_at TIMESTAMP WITH TIME ZONE,proposed_end_at TIMESTAMP WITH TIME ZONE,reason VARCHAR(500),status VARCHAR(32),requested_at TIMESTAMP WITH TIME ZONE,responded_at TIMESTAMP WITH TIME ZONE,responded_by UUID,expires_at TIMESTAMP WITH TIME ZONE,version BIGINT DEFAULT 0)");
  db.execute("CREATE TABLE partner_applications(id UUID,user_id UUID)");
  var settings=mock(SystemSettingsService.class);
  when(settings.getEarlyCheckinWindowMinutes()).thenReturn(15);
  when(settings.getMinBufferMinutes()).thenReturn(60);
  when(settings.getMaxEarlyStartMinutes()).thenReturn(60);
  var scheduling=mock(PartnerSchedulingService.class);
  when(scheduling.validateSchedule(any(),any(),any(),anyInt(),any(),any())).thenReturn(PartnerSchedulingService.ScheduleValidationResult.ok(60));
  var proxy=new ProxyFactory(new EarlyStartService(db,settings,scheduling,clock));
  proxy.setProxyTargetClass(true);
  proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(source),new AnnotationTransactionAttributeSource()));
  service=(EarlyStartService)proxy.getProxy();
  task=UUID.randomUUID();customer=UUID.randomUUID();partner=UUID.randomUUID();request=UUID.randomUUID();
  scheduled=clock.now.plusSeconds(600);expiry=clock.now.plusSeconds(300);requested=scheduled.minusSeconds(120);
  db.update("INSERT INTO tasks(id,customer_id,tasker_id,status,scheduled_at,estimated_duration_minutes,checked_in_at,service_name_snapshot) VALUES(?,?,?,'ARRIVED',?,120,?,'Dịch vụ')",task,customer,partner,Timestamp.from(scheduled),Timestamp.from(clock.now));
  db.update("INSERT INTO early_start_requests(id,task_id,partner_id,requested_start_at,proposed_end_at,status,requested_at,expires_at) VALUES(?,?,?,?,?,'PENDING',?,?)",request,task,partner,Timestamp.from(requested),Timestamp.from(requested.plusSeconds(7200)),Timestamp.from(clock.now),Timestamp.from(expiry));
 }
 String status(){return db.queryForObject("SELECT status FROM early_start_requests WHERE id=?",String.class,request);}
 @Test void expiresAtExactDeadlineForBothAppsAndOnlyOnce() {
  assertNotNull(service.getStartEligibility(customer,task,false).activeRequest());
  clock.now=expiry;
  assertNull(service.getStartEligibility(customer,task,false).activeRequest());
  assertNull(service.getStartEligibility(partner,task,true).activeRequest());
  assertEquals("EXPIRED",status());
  assertEquals(1L,db.queryForObject("SELECT version FROM early_start_requests WHERE id=?",Long.class,request));
 }
 @Test void scheduledTimeExpiresRequestAndEnablesStartWithoutAutoStartingWork() {
  db.update("UPDATE early_start_requests SET expires_at=? WHERE id=?",Timestamp.from(scheduled.plusSeconds(3600)),request);
  clock.now=scheduled;
  var eligibility=service.getStartEligibility(partner,task,true);
  assertNull(eligibility.activeRequest());assertFalse(eligibility.canRequestEarlyStart());assertTrue(eligibility.canStart());
  assertEquals("ARRIVED",eligibility.taskStatus());assertNull(eligibility.actualStartedAt());
  assertEquals("EXPIRED",status());
  assertNull(db.queryForObject("SELECT approved_start_at FROM tasks WHERE id=?",Timestamp.class,task));
 }
 @Test void expiredDecisionCommitsExpiryEvenWhenReturningConflict() {
  clock.now=expiry;
  var error=assertThrows(DomainException.class,()->service.customerDecision(customer,task,request,"APPROVE",null));
  assertEquals("EARLY_START_REQUEST_EXPIRED",error.getCode());
  assertEquals("EXPIRED",status());
  assertThrows(DomainException.class,()->service.customerDecision(customer,task,request,"REJECT",null));
 }
 @Test void backgroundExpiryWorksWithoutOpeningEitherApp() {
  clock.now=expiry;
  service.expireStaleRequests();
  service.expireStaleRequests();
  assertEquals("EXPIRED",status());
  assertEquals(1L,db.queryForObject("SELECT version FROM early_start_requests WHERE id=?",Long.class,request));
  assertEquals("ARRIVED",db.queryForObject("SELECT status FROM tasks WHERE id=?",String.class,task));
 }
 @ParameterizedTest @ValueSource(strings={"APPROVE","REJECT"})
 void decisionsBeforeDeadlineStillWork(String action) {
  var result=service.customerDecision(customer,task,request,action,null);
  assertEquals(action.equals("APPROVE")?"APPROVED":"REJECTED",result.status());
  assertEquals(result.status(),status());
 }
 @Test void actualWorkStatusSupersedesPendingRequest() {
  db.update("UPDATE tasks SET status='IN_PROGRESS',actual_started_at=? WHERE id=?",Timestamp.from(clock.now),task);
  var result=service.getStartEligibility(customer,task,false);
  assertNull(result.activeRequest());assertEquals("IN_PROGRESS",result.taskStatus());assertEquals(clock.now,result.actualStartedAt());
  assertEquals("EXPIRED",status());
 }
 @Test void timeAloneDoesNotPretendPartnerHasArrived() {
  db.update("UPDATE tasks SET status='ACCEPTED',checked_in_at=NULL WHERE id=?",task);
  clock.now=scheduled.plusSeconds(1);
  var result=service.getStartEligibility(partner,task,true);
  assertFalse(result.canStart());assertTrue(result.canCheckIn());assertEquals("ACCEPTED",result.taskStatus());
  assertNull(result.activeRequest());
 }
 @Test void decisionPayloadAcceptsCanonicalAndPreviousClientField() {
  var json=new tools.jackson.databind.ObjectMapper();
  assertEquals("APPROVE",json.readValue("{\"action\":\"APPROVE\"}",EarlyStartController.CustomerDecisionRequest.class).action());
  assertEquals("REJECT",json.readValue("{\"decision\":\"REJECT\"}",EarlyStartController.CustomerDecisionRequest.class).action());
 }
}
