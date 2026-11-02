package com.taskly.booking;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import com.taskly.common.exception.DomainException;
class BookingCancellationTest {
 @Test void insufficientBalanceCannotCreateOrder() {
  var db=mock(JdbcTemplate.class);var prices=mock(CustomerPricingController.class);var owner=UUID.randomUUID();var quote=UUID.randomUUID();
  when(prices.validateQuote(owner,quote)).thenReturn(new CustomerPricingController.Quote(quote,100000L,0L,100000L,"VND",1L,Instant.now().plusSeconds(900),List.of()));
  when(db.queryForObject(anyString(),eq(Long.class),eq(owner))).thenReturn(0L);
  var checkout=new BookingCheckout(db,Clock.systemUTC(),mock(tools.jackson.databind.ObjectMapper.class),prices);
  assertThrows(DomainException.class,()->checkout.checkout(owner,quote,"CASH",40000L));
  assertThrows(DomainException.class,()->checkout.checkout(owner,quote,"BANK",100001L));
  assertThrows(DomainException.class,()->checkout.checkout(owner,quote,"BANK",-1L));
  verify(db,never()).update(anyString(),any(Object[].class));
 }
 @Test void availableBalanceSubtractsWithdrawalsAndBookingDebits() {
  var db=mock(JdbcTemplate.class);var owner=UUID.randomUUID();
  when(db.queryForObject(contains("customer_refund_credits"),eq(Long.class),eq(owner))).thenReturn(150000L);
  when(db.queryForObject(contains("customer_refund_withdrawals"),eq(Long.class),eq(owner))).thenReturn(20000L);
  when(db.queryForObject(contains("SUM(p.balance_amount)"),eq(Long.class),eq(owner))).thenReturn(50000L);
  when(db.queryForObject(contains("status='COMPLETED'"),eq(Long.class),eq(owner))).thenReturn(100000L);
  var checkout=new BookingCheckout(db,Clock.systemUTC(),mock(tools.jackson.databind.ObjectMapper.class),mock(CustomerPricingController.class));
  assertEquals(180000L,checkout.availableBalance(owner));
 }
 @Test void cancellationReturnsOnlyBalancePaidOnPartialCashOrder() {
  var db=mock(JdbcTemplate.class);var owner=UUID.randomUUID();var id=UUID.randomUUID();
  var row=new HashMap<String,Object>();row.put("id",id);row.put("customer_id",owner);row.put("status","POSTED");row.put("payment_status","AWAITING_CASH");row.put("amount",100000L);row.put("balance_amount",40000L);
  when(db.queryForList(anyString(),eq(id),eq(owner))).thenReturn(List.of(row));
  var checkout=new BookingCheckout(db,Clock.systemUTC(),mock(tools.jackson.databind.ObjectMapper.class),mock(CustomerPricingController.class));
  checkout.cancel(owner,id);
  verify(db).update(contains("INSERT INTO customer_refund_credits"),eq(id),eq(owner),eq(40000L),any(java.sql.Timestamp.class));
  row.put("status","REFUNDED");checkout.cancel(owner,id);
  verify(db,times(1)).update(contains("INSERT INTO customer_refund_credits"),eq(id),eq(owner),eq(40000L),any(java.sql.Timestamp.class));
 }
 @Test void retryWithSameBalanceDoesNotDebitAgain() {
  var db=mock(JdbcTemplate.class);var owner=UUID.randomUUID();var quote=UUID.randomUUID();var id=UUID.randomUUID();
  when(db.queryForList(anyString(),eq(quote),eq(owner))).thenReturn(List.of(Map.of("id",id,"method","CASH","balance_amount",40000L,"status","POSTED")));
  var checkout=new BookingCheckout(db,Clock.systemUTC(),mock(tools.jackson.databind.ObjectMapper.class),mock(CustomerPricingController.class));
  assertEquals(id,checkout.checkout(owner,quote,"CASH",40000L).get("id"));
  assertThrows(DomainException.class,()->checkout.checkout(owner,quote,"CASH",50000L));
  verify(db,never()).update(anyString(),any(Object[].class));
 }
 @Test void viewedOrderCanBeCancelledButAssignedOrderCannot() {
  var db=mock(JdbcTemplate.class);var now=Instant.now();var owner=UUID.randomUUID();var id=UUID.randomUUID();
  var row=new HashMap<String,Object>();row.put("id",id);row.put("customer_id",owner);row.put("status","POSTED");row.put("payment_status","AWAITING_CASH");row.put("cancel_after",java.sql.Timestamp.from(now.plusSeconds(900)));
  when(db.queryForList(anyString(),eq(id),eq(owner))).thenReturn(List.of(row));
  var checkout=new BookingCheckout(db,Clock.fixed(now,ZoneOffset.UTC),mock(tools.jackson.databind.ObjectMapper.class),mock(CustomerPricingController.class));
  row.put("tasker_viewed_at",java.sql.Timestamp.from(now));
  row.put("tasker_viewed_by",UUID.randomUUID());
  row.put("tasker_id",UUID.randomUUID());
  assertThrows(DomainException.class,()->checkout.cancel(owner,id));
  verify(db,never()).update(anyString(),any(Object[].class));
  row.remove("tasker_id");
  assertDoesNotThrow(()->checkout.cancel(owner,id));
  verify(db).update(eq("UPDATE tasks SET status=?,updated_at=?,version=version+1 WHERE id=?"),eq("CANCELLED"),any(java.sql.Timestamp.class),eq(id));
 }
 @Test void adminRefundsPaidAssignedOrderAndNotifiesPartner() {
  var db=mock(JdbcTemplate.class);var now=Instant.now();var id=UUID.randomUUID();var owner=UUID.randomUUID();var partner=UUID.randomUUID();var app=UUID.randomUUID();
  var row=new HashMap<String,Object>();row.put("id",id);row.put("customer_id",owner);row.put("tasker_id",partner);row.put("status","TASKER_ON_THE_WAY");row.put("payment_status","PAID");row.put("amount",100000L);
  when(db.queryForList(anyString(),eq(id))).thenReturn(List.of(row));
  when(db.queryForList(anyString(),eq(UUID.class),eq(partner))).thenReturn(List.of(app));
  var checkout=new BookingCheckout(db,Clock.fixed(now,ZoneOffset.UTC),mock(tools.jackson.databind.ObjectMapper.class),mock(CustomerPricingController.class));
  checkout.adminCancel(id,"Khách yêu cầu");
  verify(db).update(contains("INSERT INTO customer_refund_credits"),eq(id),eq(owner),eq(100000L),any(java.sql.Timestamp.class));
  verify(db).update(contains("UPDATE tasks SET status"),eq("REFUNDED"),any(java.sql.Timestamp.class),eq(id));
  verify(db).update(contains("INSERT INTO partner_notification_outbox"),any(UUID.class),eq(app),eq(id),anyString(),anyString(),any(java.sql.Timestamp.class),any(java.sql.Timestamp.class));
  row.put("status","REFUNDED");checkout.adminCancel(id,"Thử lại");
  verify(db,times(1)).update(contains("INSERT INTO customer_refund_credits"),eq(id),eq(owner),eq(100000L),any(java.sql.Timestamp.class));
 }

}
