package com.taskly.booking;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;

final class WalletNotifications {
 private WalletNotifications() {}
 static void send(JdbcTemplate db, UUID owner, String role, String type, long amount, String status, String note) {
  String action=type.equals("DEPOSIT") ? "Nạp tiền" : "Rút tiền";
  String state=switch(status) {
   case "PENDING" -> "đang chờ duyệt";
   case "APPROVED" -> "đã được duyệt, đang chờ chuyển tiền";
   case "PAID", "COMPLETED" -> "thành công";
   case "REJECTED", "FAILED" -> "không thành công";
   default -> status;
  };
  String title=action+" "+state;
  String message=action+" "+String.format(java.util.Locale.forLanguageTag("vi-VN"),"%,d",amount)+"đ "+state+"."+(note==null||note.isBlank()?"":" "+note);
  if (role.equals("CUSTOMER")) {
   db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,NULL,?,CURRENT_TIMESTAMP)",UUID.randomUUID(),owner,message);
  } else {
   db.update("INSERT INTO partner_notification_outbox(id,application_id,channel,status,title,message,created_at,delivered_at) SELECT ?,id,'IN_APP','DELIVERED',?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP FROM partner_applications WHERE user_id=?",UUID.randomUUID(),title,message,owner);
  }
 }
}
