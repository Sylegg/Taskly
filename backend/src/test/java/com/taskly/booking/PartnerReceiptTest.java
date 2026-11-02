package com.taskly.booking;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.time.*;
import java.util.*;
import com.taskly.common.exception.DomainException;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

class PartnerReceiptTest {
 JdbcTemplate db;BookingCheckout checkout;
 UUID task=UUID.randomUUID(),customer=UUID.randomUUID(),partner=UUID.randomUUID();
 @BeforeEach void setup(){
  db=new JdbcTemplate(new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DB_CLOSE_DELAY=-1","sa",""));
  db.execute("CREATE TABLE tasks(id UUID PRIMARY KEY,customer_id UUID,tasker_id UUID,status VARCHAR(32),partner_payment_confirmed_at TIMESTAMP WITH TIME ZONE,customer_confirmed_at TIMESTAMP WITH TIME ZONE,updated_at TIMESTAMP WITH TIME ZONE,version BIGINT DEFAULT 0,service_name_snapshot VARCHAR(100))");
  db.execute("CREATE TABLE task_booking_payments(task_id UUID PRIMARY KEY,method VARCHAR(32),status VARCHAR(32),amount BIGINT,balance_amount BIGINT)");
  db.execute("CREATE TABLE task_status_history(id UUID,task_id UUID,from_status VARCHAR(32),to_status VARCHAR(32),actor_role VARCHAR(32),reason VARCHAR(500),occurred_at TIMESTAMP WITH TIME ZONE)");
  db.execute("CREATE TABLE customer_booking_notifications(id UUID,customer_id UUID,task_id UUID,title VARCHAR(500),created_at TIMESTAMP WITH TIME ZONE)");
  db.execute("CREATE TABLE live_sync_revision(id INTEGER,revision BIGINT)");db.update("INSERT INTO live_sync_revision VALUES(1,1)");
  db.update("INSERT INTO tasks(id,customer_id,tasker_id,status,service_name_snapshot) VALUES(?,?,?,'COMPLETED','Dọn nhà')",task,customer,partner);
  db.update("INSERT INTO task_booking_payments VALUES(?,'CASH','AWAITING_CASH',100000,40000)",task);
  checkout=new BookingCheckout(db,Clock.fixed(Instant.parse("2026-10-20T09:00:00Z"),ZoneOffset.UTC),mock(tools.jackson.databind.ObjectMapper.class),mock(CustomerPricingController.class));
 }
 @Test void cashReceiptPersistsOnlyAfterPartnerActionAndIsIdempotent(){
  assertNull(db.queryForObject("SELECT partner_payment_confirmed_at FROM tasks",java.sql.Timestamp.class));
  checkout.paymentReceived(partner,task);checkout.paymentReceived(partner,task);checkout.cashReceived(partner,task);
  assertEquals("PAID",db.queryForObject("SELECT status FROM tasks",String.class));
  assertEquals("PAID",db.queryForObject("SELECT status FROM task_booking_payments",String.class));
  assertNotNull(db.queryForObject("SELECT partner_payment_confirmed_at FROM tasks",java.sql.Timestamp.class));
  assertNull(db.queryForObject("SELECT customer_confirmed_at FROM tasks",java.sql.Timestamp.class));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM task_status_history",Integer.class));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM customer_booking_notifications",Integer.class));
  assertTrue(db.queryForObject("SELECT title FROM customer_booking_notifications",String.class).contains("60000"));
 }
 @ParameterizedTest @CsvSource({"BANK,0","CASH,100000"})
 void prepaidOrderStillRequiresExplicitReceiptWithoutAnotherDebit(String method,long balance){
  db.update("UPDATE task_booking_payments SET method=?,status='PAID',balance_amount=?",method,balance);
  assertNull(db.queryForObject("SELECT partner_payment_confirmed_at FROM tasks",java.sql.Timestamp.class));
  checkout.paymentReceived(partner,task);checkout.paymentReceived(partner,task);
  assertNotNull(db.queryForObject("SELECT partner_payment_confirmed_at FROM tasks",java.sql.Timestamp.class));
  assertEquals("COMPLETED",db.queryForObject("SELECT status FROM tasks",String.class));
  assertEquals(balance,db.queryForObject("SELECT balance_amount FROM task_booking_payments",Long.class));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM task_status_history",Integer.class));
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM customer_booking_notifications",Integer.class));
 }
 @Test void cannotConfirmForAnotherPartnerOrAsCustomer(){
  assertThrows(DomainException.class,()->checkout.paymentReceived(customer,task));
  assertThrows(DomainException.class,()->checkout.paymentReceived(UUID.randomUUID(),task));
 }
 @Test void cannotConfirmBeforeJobIsCompleted(){db.update("UPDATE tasks SET status='IN_PROGRESS'");assertThrows(DomainException.class,()->checkout.paymentReceived(partner,task));}
 @Test void unpaidBankPaymentCannotBeMarkedReceived(){db.update("UPDATE task_booking_payments SET method='BANK',status='PENDING'");assertEquals("PAYMENT_NOT_READY",assertThrows(DomainException.class,()->checkout.paymentReceived(partner,task)).getCode());assertNull(db.queryForObject("SELECT partner_payment_confirmed_at FROM tasks",java.sql.Timestamp.class));}
}
