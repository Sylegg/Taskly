package com.taskly.task;

import static org.junit.jupiter.api.Assertions.*;
import com.taskly.common.exception.DomainException;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

class TaskCompletionTest {
 JdbcTemplate db;
 TaskCompletionService service;
 UUID customer=UUID.randomUUID(),partner=UUID.randomUUID(),task=UUID.randomUUID();
 @BeforeEach void setup(){
  db=new JdbcTemplate(new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DB_CLOSE_DELAY=-1","sa",""));
  db.execute("CREATE TABLE tasks(id UUID PRIMARY KEY,customer_id UUID,tasker_id UUID,status VARCHAR(32),customer_confirmed_at TIMESTAMP WITH TIME ZONE,updated_at TIMESTAMP WITH TIME ZONE,version BIGINT DEFAULT 0)");
  db.execute("CREATE TABLE task_messages(id UUID PRIMARY KEY,task_id UUID,sender_id UUID,content VARCHAR(500),image_data VARCHAR(500),sender_portal VARCHAR(32),created_at TIMESTAMP WITH TIME ZONE)");
  db.execute("CREATE TABLE task_status_history(id UUID,task_id UUID,from_status VARCHAR(32),to_status VARCHAR(32),actor_role VARCHAR(32),reason VARCHAR(500),occurred_at TIMESTAMP WITH TIME ZONE)");
  db.execute("CREATE TABLE live_sync_revision(id INTEGER,revision BIGINT)");db.update("INSERT INTO live_sync_revision VALUES(1,1)");
  db.update("INSERT INTO tasks(id,customer_id,tasker_id,status) VALUES(?,?,?,'COMPLETED')",task,customer,partner);
  service=new TaskCompletionService(db,Clock.fixed(Instant.parse("2026-10-20T09:00:00Z"),ZoneOffset.UTC));
 }
 void photo(UUID sender,String content){db.update("INSERT INTO task_messages(id,task_id,sender_id,content,image_data,sender_portal) VALUES(?,?,?,?,?,'PARTNER')",UUID.randomUUID(),task,sender,content,"data:image/png;base64,photo");}
 void photos(){photo(partner,TaskCompletionService.PHOTO_CONTENT);photo(partner,TaskCompletionService.PHOTO_CONTENT);}
 @Test void sendingPhotosAloneDoesNotConfirm(){photos();assertNull(db.queryForMap("SELECT * FROM tasks WHERE id=?",task).get("CUSTOMER_CONFIRMED_AT"));}
 @Test void customerConfirmsOnlyOnceAndKeepsPaymentStatus(){
  photos();assertEquals(true,service.confirm(customer,task).get("confirmed"));service.confirm(customer,task);
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM task_status_history",Integer.class));
  assertEquals(1L,db.queryForObject("SELECT version FROM tasks WHERE id=?",Long.class,task));
  assertEquals("COMPLETED",db.queryForObject("SELECT status FROM tasks WHERE id=?",String.class,task));
  assertNotNull(db.queryForObject("SELECT customer_confirmed_at FROM tasks WHERE id=?",java.sql.Timestamp.class,task));
 }
 @Test void cashPaymentDoesNotReplaceCustomerConfirmation(){db.update("UPDATE tasks SET status='PAID'");photos();service.confirm(customer,task);assertEquals("PAID",db.queryForObject("SELECT status FROM tasks",String.class));}
 @Test void partnerOrAnotherCustomerCannotConfirm(){photos();assertEquals("TASK_NOT_FOUND",assertThrows(DomainException.class,()->service.confirm(partner,task)).getCode());assertThrows(DomainException.class,()->service.confirm(UUID.randomUUID(),task));}
 @Test void cannotConfirmBeforeCompletion(){photos();db.update("UPDATE tasks SET status='IN_PROGRESS'");assertEquals("COMPLETION_NOT_READY",assertThrows(DomainException.class,()->service.confirm(customer,task)).getCode());}
 @Test void needsRealCompletionPhotosFromAssignedPartner(){photo(customer,TaskCompletionService.PHOTO_CONTENT);photo(partner,"Ảnh đính kèm");assertEquals("COMPLETION_PHOTOS_REQUIRED",assertThrows(DomainException.class,()->service.confirm(customer,task)).getCode());}
}
