package com.taskly.booking;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;
import java.time.Clock;
import java.util.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.server.ResponseStatusException;

class CustomerWithdrawalIntegrationTest {
 private JdbcTemplate db;
 private UUID owner;
 private PartnerWalletController admin;
 private BookingCheckoutController customer;
 private BookingCheckout checkout;
 private Jwt adminJwt;
 @BeforeEach void setup() {
  db=new JdbcTemplate(new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1","sa",""));
  db.execute("CREATE TABLE users(id UUID PRIMARY KEY)");
  db.execute("CREATE TABLE customer_refund_credits(customer_id UUID, amount BIGINT)");
  db.execute("CREATE TABLE tasks(id UUID PRIMARY KEY,customer_id UUID)");
  db.execute("CREATE TABLE task_booking_payments(task_id UUID,balance_amount BIGINT)");
  db.execute("CREATE TABLE partner_wallets(user_id UUID PRIMARY KEY,balance BIGINT)");
  db.execute("CREATE TABLE partner_wallet_transactions(id UUID PRIMARY KEY,user_id UUID,type VARCHAR(20),user_role VARCHAR(20),amount BIGINT,status VARCHAR(20))");
  db.execute("CREATE TABLE customer_refund_withdrawals(id UUID PRIMARY KEY,customer_id UUID,amount BIGINT,bank_name VARCHAR(100),account_name VARCHAR(150),account_number VARCHAR(34),status VARCHAR(20) DEFAULT 'PENDING',created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)");
  db.execute("CREATE TABLE customer_booking_notifications(id UUID,customer_id UUID,task_id UUID,title VARCHAR(1000),created_at TIMESTAMP)");
  owner=UUID.randomUUID();db.update("INSERT INTO users VALUES(?)",owner);
  db.update("INSERT INTO customer_refund_credits VALUES(?,200000)",owner);
  db.update("INSERT INTO partner_wallets VALUES(?,900000)",owner);
  admin=new PartnerWalletController(db);
  checkout=new BookingCheckout(db,Clock.systemUTC(),mock(tools.jackson.databind.ObjectMapper.class),mock(CustomerPricingController.class));
  customer=new BookingCheckoutController(checkout,db);
  adminJwt=Jwt.withTokenValue("test").header("alg","none").subject(UUID.randomUUID().toString()).build();
 }
 private PartnerWalletController.Manual withdrawal(UUID id,long amount) {
  return new PartnerWalletController.Manual(owner,id,"WITHDRAWAL","CUSTOMER",amount,"Ngân hàng","Bank","Customer","123456789",null);
 }
 @Test void adminRequestReservesCustomerBalanceAndNeverTouchesPartnerWallet() {
  UUID id=UUID.randomUUID();admin.manual(adminJwt,withdrawal(id,50000));
  assertEquals(150000L,checkout.availableBalance(owner));
  assertEquals(900000L,db.queryForObject("SELECT balance FROM partner_wallets WHERE user_id=?",Long.class,owner));
  assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM partner_wallet_transactions",Integer.class));
  admin.manual(adminJwt,withdrawal(id,50000));
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM customer_refund_withdrawals",Integer.class));
  assertThrows(ResponseStatusException.class,()->admin.manual(adminJwt,withdrawal(id,60000)));
  assertThrows(ResponseStatusException.class,()->admin.manual(adminJwt,new PartnerWalletController.Manual(owner,id,"DEPOSIT","CUSTOMER",50000,"Bank",null,null,null,null)));
  assertThrows(ResponseStatusException.class,()->admin.manual(adminJwt,withdrawal(UUID.randomUUID(),160000)));
  assertEquals(150000L,checkout.availableBalance(owner));
  customer.updateAdminWithdrawalStatus(id,Map.of("status","PAID"));
  customer.updateAdminWithdrawalStatus(id,Map.of("status","PAID"));
  assertEquals(150000L,checkout.availableBalance(owner));
  assertEquals(900000L,db.queryForObject("SELECT balance FROM partner_wallets WHERE user_id=?",Long.class,owner));
  assertThrows(ResponseStatusException.class,()->customer.updateAdminWithdrawalStatus(id,Map.of("status","REJECTED")));
 }
 @Test void rejectedRequestReleasesCustomerFundsAndMobileUsesSameLedger() {
  UUID id=UUID.randomUUID();admin.manual(adminJwt,withdrawal(id,100000));
  customer.updateAdminWithdrawalStatus(id,Map.of("status","REJECTED"));
  customer.updateAdminWithdrawalStatus(id,Map.of("status","REJECTED"));
  assertEquals(200000L,checkout.availableBalance(owner));
  Jwt customerJwt=Jwt.withTokenValue("test").header("alg","none").subject(owner.toString()).build();
  customer.withdraw(customerJwt,new BookingCheckoutController.Withdrawal(50000,"Bank","Customer","123456789"));
  assertEquals(150000L,checkout.availableBalance(owner));
  assertEquals(900000L,db.queryForObject("SELECT balance FROM partner_wallets WHERE user_id=?",Long.class,owner));
 }
 @Test void legacyCustomerWithdrawalCannotDebitPartnerWallet() {
  UUID id=UUID.randomUUID();db.update("INSERT INTO partner_wallet_transactions VALUES(?,?,'WITHDRAWAL','CUSTOMER',50000,'APPROVED')",id,owner);
  assertThrows(ResponseStatusException.class,()->admin.decision(adminJwt,id,new PartnerWalletController.Decision("PAID","REF123",null)));
  assertEquals(900000L,db.queryForObject("SELECT balance FROM partner_wallets WHERE user_id=?",Long.class,owner));
 }
}
