package com.taskly.booking;

import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;
import static org.junit.jupiter.api.Assertions.*;

class PartnerWalletControllerTest {
 JdbcTemplate db;
 PartnerWalletController controller;
 TransactionTemplate transaction;
 UUID owner = UUID.randomUUID(), admin = UUID.randomUUID();
 Jwt partner, administrator;
 @BeforeEach void setup() {
  var source = new SingleConnectionDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE", "sa", "", true);
  db = new JdbcTemplate(source);
  db.execute("CREATE TABLE users(id UUID PRIMARY KEY)");
  db.update("INSERT INTO users VALUES(?),(?)",owner,admin);
  new ResourceDatabasePopulator(new ClassPathResource("db/migration/V78__partner_wallet.sql")).execute(source);
  new ResourceDatabasePopulator(new ClassPathResource("db/migration/V79__finance_wallet_settings.sql")).execute(source);
  controller = new PartnerWalletController(db);
  transaction = new TransactionTemplate(new DataSourceTransactionManager(source));
  partner = Jwt.withTokenValue("partner").header("alg","none").subject(owner.toString()).build();
  administrator = Jwt.withTokenValue("admin").header("alg","none").subject(admin.toString()).build();
 }
 void deposit(long amount, UUID id) {
  transaction.executeWithoutResult(s -> controller.request(partner,"deposit",new PartnerWalletController.Request(amount,id,null,null,null)));
 }
 UUID withdraw(long amount) {
  UUID id=UUID.randomUUID();
  transaction.executeWithoutResult(s -> controller.request(partner,"withdraw",new PartnerWalletController.Request(amount,id,"VCB","Nguyen Van A","123456789")));
  return id;
 }
 void status(UUID id, String status, String reference) {
  transaction.executeWithoutResult(s -> controller.decision(administrator,id,new PartnerWalletController.Decision(status,reference,null)));
 }
 long available() {
  return db.queryForObject("SELECT balance-COALESCE((SELECT SUM(amount) FROM partner_wallet_transactions WHERE user_id=? AND type='WITHDRAWAL' AND status IN ('PENDING','APPROVED')),0) FROM partner_wallets WHERE user_id=?",Long.class,owner,owner);
 }
 @Test void depositIsPersistentAndRetryDoesNotCreditTwice() {
  UUID id=UUID.randomUUID(); deposit(500000,id); deposit(500000,id);
  assertEquals(500000,available());
  assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM partner_wallet_transactions",Integer.class));
  assertNotNull(db.queryForObject("SELECT completed_at FROM partner_wallet_transactions WHERE id=?",Object.class,id));
  assertThrows(ResponseStatusException.class, () -> deposit(600000,id));
 }
 @Test void withdrawalRequiresApprovalAndPaymentAndReservesBalance() {
  deposit(500000,UUID.randomUUID()); UUID id=withdraw(200000);
  assertEquals(300000,available());
  assertThrows(ResponseStatusException.class, () -> status(id,"PAID","FT123"));
  status(id,"APPROVED",null); assertEquals(300000,available());
  assertThrows(ResponseStatusException.class, () -> status(id,"PAID",""));
  status(id,"PAID","FT123"); status(id,"PAID","FT123");
  assertEquals(300000,available());
  assertEquals("PAID",db.queryForObject("SELECT status FROM partner_wallet_transactions WHERE id=?",String.class,id));
  assertThrows(ResponseStatusException.class, () -> status(id,"REJECTED",null));
 }
 @Test void rejectionReleasesReservedMoney() {
  deposit(500000,UUID.randomUUID()); UUID id=withdraw(400000);
  status(id,"APPROVED",null); status(id,"REJECTED",null);
  assertEquals(500000,available());
  assertEquals(500000,db.queryForObject("SELECT balance FROM partner_wallets WHERE user_id=?",Long.class,owner));
 }
 @Test void cannotWithdrawReservedMoneyOrInvalidBank() {
  deposit(500000,UUID.randomUUID()); withdraw(400000);
  assertThrows(ResponseStatusException.class, () -> withdraw(200000));
  assertThrows(ResponseStatusException.class, () -> transaction.executeWithoutResult(s -> controller.request(partner,"withdraw",new PartnerWalletController.Request(1000,UUID.randomUUID(),"VCB","A","abc"))));
  assertEquals(100000,available());
 }
 @Test void anotherUserCannotRetrySomeoneElsesTransaction() {
  UUID id=UUID.randomUUID(); deposit(500000,id);
  assertThrows(ResponseStatusException.class, () -> transaction.executeWithoutResult(s -> controller.request(administrator,"deposit",new PartnerWalletController.Request(500000,id,null,null,null))));
 }
 @Test void configurationPersistsAndLimitsAndFeeApplyToNewRequests() {
  var settings=new WalletFinanceSettings(db);
  settings.save(administrator,new WalletFinanceSettings.Config(50000,1000000,100000,300000,new java.math.BigDecimal("2"),0,"VCB","123456789","TASKLY","NAP"));
  assertEquals(300000,settings.read().maxWithdrawDaily());
  assertThrows(ResponseStatusException.class, () -> deposit(10000,UUID.randomUUID()));
  deposit(500000,UUID.randomUUID()); UUID id=withdraw(200000);
  assertEquals(4000,db.queryForObject("SELECT fee FROM partner_wallet_transactions WHERE id=?",Long.class,id));
  assertThrows(ResponseStatusException.class, () -> withdraw(200000));
  status(id,"REJECTED",null); withdraw(200000);
 }
 @Test void manualDepositAndWithdrawalArePersistedAndNotPaidUntilApproved() {
  transaction.executeWithoutResult(s -> controller.manual(administrator,new PartnerWalletController.Manual(owner,UUID.randomUUID(),"DEPOSIT","PARTNER",500000,"Tiền mặt",null,null,null,"Nạp tại quầy")));
  UUID id=UUID.randomUUID();
  transaction.executeWithoutResult(s -> controller.manual(administrator,new PartnerWalletController.Manual(owner,id,"WITHDRAWAL","PARTNER",200000,"Chuyển khoản","VCB","A","123456789","Rút tại quầy")));
  assertEquals(300000,available());
  assertEquals("PENDING",db.queryForObject("SELECT status FROM partner_wallet_transactions WHERE id=?",String.class,id));
 }
}
