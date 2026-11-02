package com.taskly.booking;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
class WalletNotificationsTest {
 @Test void customerAndPartnerNotificationsRemainSeparate() {
  var owner=UUID.randomUUID();
  for(String status:new String[]{"PENDING","APPROVED","COMPLETED","PAID","REJECTED","FAILED"}) {
   var db=mock(JdbcTemplate.class);
   WalletNotifications.send(db,owner,"CUSTOMER","WITHDRAWAL",100000,status,"Thông tin ngân hàng");
   verify(db).update(contains("customer_booking_notifications"),any(),eq(owner),contains("100.000đ"));
   verify(db,never()).update(contains("partner_notification_outbox"),any(),any(),any(),any());
   clearInvocations(db);
   WalletNotifications.send(db,owner,"PARTNER","DEPOSIT",100000,status,null);
   verify(db).update(contains("partner_notification_outbox"),any(),contains("Nạp tiền"),contains("100.000đ"),eq(owner));
  }
 }
}
