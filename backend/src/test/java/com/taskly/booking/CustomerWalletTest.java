package com.taskly.booking;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import java.math.BigDecimal;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.server.ResponseStatusException;
class CustomerWalletTest {
 private Jwt jwt(UUID owner) {return Jwt.withTokenValue("test").header("alg","none").subject(owner.toString()).build();}
 private WalletFinanceSettings settings() {
  var settings=mock(WalletFinanceSettings.class);
  when(settings.read()).thenReturn(new WalletFinanceSettings.Config(50000,50000000,100000,20000000,BigDecimal.ZERO,0,"Bank","123456789","Taskly","TASKLY NAP"));return settings;
 }
 @Test void depositCreatesPendingRequestWithoutCreditingBalance() {
  var db=mock(JdbcTemplate.class);var owner=UUID.randomUUID();var id=UUID.randomUUID();var checkout=mock(BookingCheckout.class);
  var controller=new CustomerWalletController(db,checkout,settings());
  var response=controller.deposit(jwt(owner),new CustomerWalletController.Deposit(id,100000));
  assertEquals("PENDING",((Map<?,?>)response.data()).get("status"));
  verify(db).update(contains("INSERT INTO partner_wallet_transactions"),eq(id),eq(owner),eq(100000L),eq("Chuyển khoản ngân hàng"),eq("Bank"),eq("Taskly"),eq("123456789"),eq("TASKLY NAP "+id));verifyNoInteractions(checkout);
 }
 @Test void retriesRejectChangedOwnerOrAmount() {
  var db=mock(JdbcTemplate.class);var owner=UUID.randomUUID();var id=UUID.randomUUID();
  when(db.queryForList(anyString(),eq(id))).thenReturn(List.of(Map.of("user_id",owner,"user_role","CUSTOMER","type","DEPOSIT","amount",100000L,"status","PENDING")));
  var controller=new CustomerWalletController(db,mock(BookingCheckout.class),settings());
  controller.deposit(jwt(owner),new CustomerWalletController.Deposit(id,100000));
  assertThrows(ResponseStatusException.class,()->controller.deposit(jwt(owner),new CustomerWalletController.Deposit(id,200000)));
  assertThrows(ResponseStatusException.class,()->controller.deposit(jwt(UUID.randomUUID()),new CustomerWalletController.Deposit(id,100000)));
  verify(db,never()).update(anyString(),any(Object[].class));
 }
 @Test void rejectsAmountOutsideConfiguredLimits() {
  var db=mock(JdbcTemplate.class);var controller=new CustomerWalletController(db,mock(BookingCheckout.class),settings());
  assertThrows(ResponseStatusException.class,()->controller.deposit(jwt(UUID.randomUUID()),new CustomerWalletController.Deposit(UUID.randomUUID(),49999)));
  assertThrows(ResponseStatusException.class,()->controller.deposit(jwt(UUID.randomUUID()),new CustomerWalletController.Deposit(UUID.randomUUID(),50000001)));
  verify(db,never()).update(anyString(),any(Object[].class));
 }
 @Test void approvalCreditsCustomerOnceWithoutChangingPartnerWallet() {
  var db=mock(JdbcTemplate.class);var owner=UUID.randomUUID();var id=UUID.randomUUID();var admin=UUID.randomUUID();
  var tx=new HashMap<String,Object>(Map.of("user_id",owner,"user_role","CUSTOMER","type","DEPOSIT","amount",100000L,"status","PENDING"));
  when(db.queryForList(anyString(),eq(id))).thenReturn(List.of(Map.of("user_id",owner)));when(db.queryForMap(anyString(),eq(id))).thenReturn(tx);
  var controller=new PartnerWalletController(db);var decision=new PartnerWalletController.Decision("APPROVED",null,null);
  assertEquals("COMPLETED",((Map<?,?>)controller.decision(jwt(admin),id,decision).data()).get("status"));
  tx.put("status","COMPLETED");controller.decision(jwt(admin),id,decision);
  verify(db,times(1)).update(contains("UPDATE partner_wallet_transactions SET status"),eq("COMPLETED"),isNull(),eq(admin),eq(id));
  verify(db,never()).update(contains("UPDATE partner_wallets"),any(Object[].class));
  assertThrows(ResponseStatusException.class,()->controller.decision(jwt(admin),id,new PartnerWalletController.Decision("REJECTED",null,null)));
 }
}
