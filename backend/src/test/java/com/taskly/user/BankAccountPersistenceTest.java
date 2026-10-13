package com.taskly.user;

import com.taskly.recruitment.PartnerBankController;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.core.io.ClassPathResource;
import org.springframework.security.oauth2.jwt.Jwt;
import static org.junit.jupiter.api.Assertions.*;

class BankAccountPersistenceTest {
 @Test void partnerBankPersistsWithExactMobileFieldNamesAndIsPrivate() {
  var source=new SingleConnectionDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE", "sa","",true);
  try {
   var db=new JdbcTemplate(source);
   db.execute("CREATE TABLE users(id UUID PRIMARY KEY)");
   db.execute("CREATE TABLE user_profiles(user_id UUID PRIMARY KEY,full_name VARCHAR(160))");
   new ResourceDatabasePopulator(new ClassPathResource("db/migration/V65__partner_bank_account.sql")).execute(source);
   UUID owner=UUID.randomUUID(),other=UUID.randomUUID();
   db.update("INSERT INTO users VALUES(?),(?)",owner,other);
   db.update("INSERT INTO user_profiles VALUES(?,?)",owner,"Nguyen Van A");
   var jwt=jwt(owner);
   var controller=new PartnerBankController(db);
   new TransactionTemplate(new DataSourceTransactionManager(source)).executeWithoutResult(s -> controller.save(jwt,new PartnerBankController.Bank("Vietcombank","NGUYEN VAN A","00123456789")));
   var result=(java.util.Map<?,?>)new PartnerBankController(db).get(jwt).data();
   assertEquals("Vietcombank",result.get("bankName"));
   assertEquals("NGUYEN VAN A",result.get("accountName"));
   assertEquals("00123456789",result.get("accountNumber"));
   assertNull(controller.get(jwt(other)).data());
   assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM partner_bank_accounts",Integer.class));
  } finally { source.destroy(); }
 }
 @Test void customerBankWithLongDetailsPersistsAndSupportsDefaultAndDeletion() {
  var source=new SingleConnectionDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE", "sa","",true);
  try {
   var db=new JdbcTemplate(source);
   db.execute("CREATE TABLE users(id UUID PRIMARY KEY)");
   db.execute("CREATE TABLE tasks(id UUID PRIMARY KEY)");
   new ResourceDatabasePopulator(new ClassPathResource("db/migration/V10__account_preferences.sql"),new ClassPathResource("db/migration/V81__bank_account_detail_length.sql")).execute(source);
   UUID owner=UUID.randomUUID(),other=UUID.randomUUID();
   db.update("INSERT INTO users VALUES(?),(?)",owner,other);
   var controller=new AccountController(db);
   var transaction=new TransactionTemplate(new DataSourceTransactionManager(source));
   String detail="STK: 00123456789 • NGUYEN VAN A • CN: "+"A".repeat(150);
   transaction.executeWithoutResult(s -> controller.add(jwt(owner),new AccountController.MethodRequest("BANK","VCB",detail)));
   var stored=new AccountController(db).methods(jwt(owner)).data().getFirst();
   assertEquals(detail,stored.get("detail"));
   assertEquals(true,stored.get("isDefault"));
   assertTrue(controller.methods(jwt(other)).data().isEmpty());
   UUID id=(UUID)stored.get("id");
   assertThrows(com.taskly.common.exception.DomainException.class, () -> transaction.executeWithoutResult(s -> controller.delete(jwt(other),id)));
   transaction.executeWithoutResult(s -> controller.delete(jwt(owner),id));
   assertTrue(controller.methods(jwt(owner)).data().isEmpty());
  } finally { source.destroy(); }
 }
 private Jwt jwt(UUID owner) { return Jwt.withTokenValue("test").header("alg","none").subject(owner.toString()).build(); }
}
