package com.taskly.booking;

import com.taskly.common.exception.DomainException;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.scheduling.annotation.Scheduled;
import tools.jackson.databind.ObjectMapper;

@Service
public class BookingCheckout {
 private final JdbcTemplate db; private final Clock clock; private final ObjectMapper json; private final CustomerPricingController prices;
 public BookingCheckout(JdbcTemplate db,Clock clock,ObjectMapper json,CustomerPricingController prices){this.db=db;this.clock=clock;this.json=json;this.prices=prices;}
 private DomainException fail(String code,String message){return new DomainException(code,message,HttpStatus.UNPROCESSABLE_ENTITY);}
 @Transactional public Map<String,Object> checkout(UUID owner,UUID quoteId,String method) { return checkout(owner,quoteId,method,0); }
 public long availableBalance(UUID owner) {
  long credits=db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM customer_refund_credits WHERE customer_id=?",Long.class,owner);
  long reserved=db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM customer_refund_withdrawals WHERE customer_id=? AND status IN ('PENDING','PAID')",Long.class,owner);
  long spent=db.queryForObject("SELECT COALESCE(SUM(p.balance_amount),0) FROM task_booking_payments p JOIN tasks t ON t.id=p.task_id WHERE t.customer_id=?",Long.class,owner);
  long deposits=db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM partner_wallet_transactions WHERE user_id=? AND user_role='CUSTOMER' AND type='DEPOSIT' AND status='COMPLETED'",Long.class,owner);
  return credits+deposits-reserved-spent;
 }
 @Transactional public Map<String,Object> checkout(UUID owner,UUID quoteId,String method,long balanceAmount) {
  if(!Set.of("CASH","BANK").contains(method))throw fail("INVALID_PAYMENT","Chọn phương thức thanh toán hợp lệ.");
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,owner);
  var existing=db.queryForList("SELECT p.task_id AS id,p.method,p.balance_amount,t.status FROM task_booking_payments p JOIN tasks t ON t.id=p.task_id WHERE p.quote_id=? AND t.customer_id=?",quoteId,owner);
  if(!existing.isEmpty()){if(!method.equals(existing.getFirst().get("method")) || balanceAmount!=((Number)existing.getFirst().get("balance_amount")).longValue())throw fail("PAYMENT_CONFLICT","Đơn đã được tạo bằng phương thức thanh toán khác.");return existing.getFirst();}
  var quote=prices.validateQuote(owner,quoteId);
  if(balanceAmount<0 || balanceAmount>quote.total())throw fail("INVALID_BALANCE_AMOUNT","Số tiền sử dụng từ số dư không hợp lệ.");
  if(balanceAmount>0 && balanceAmount>availableBalance(owner))throw fail("INSUFFICIENT_BALANCE","Số dư không đủ. Vui lòng tải lại và thử lại.");
  String payload=db.queryForObject("SELECT draft_payload FROM customer_price_quotes WHERE id=? AND customer_id=?",String.class,quoteId,owner);
  var draft=json.readValue(payload,BookingDraftController.Draft.class);
  var now=clock.instant();
  if(draft.scheduledAt()==null || !draft.scheduledAt().isAfter(now))throw fail("INVALID_SCHEDULE","Chọn lại thời gian thực hiện trong tương lai.");
  if(db.queryForObject("SELECT COUNT(*) FROM tasks WHERE customer_id=? AND status IN ('POSTED','MATCHING','ACCEPTED','TASKER_ON_THE_WAY','ARRIVED','IN_PROGRESS','DISPUTED')",Integer.class,owner)>=3)throw fail("ORDER_LIMIT","Bạn chỉ được có tối đa 3 đơn đang xử lý.");
  var addresses=db.queryForList("SELECT * FROM addresses WHERE id=? AND user_id=? AND deleted_at IS NULL",UUID.fromString(draft.addressId()),owner);
  if(addresses.isEmpty())throw fail("INVALID_ADDRESS","Địa chỉ không còn tồn tại.");var a=addresses.getFirst();
  for(String field:List.of("address_line","city","recipient_name","recipient_phone","building_type","building_description"))if(a.get(field)==null || a.get(field).toString().isBlank())throw fail("INCOMPLETE_ADDRESS","Vui lòng bổ sung đầy đủ địa chỉ và liên hệ.");
  var s=db.queryForMap("SELECT s.*,c.slug AS category_slug,c.name AS category_name FROM services s JOIN service_categories c ON c.id=s.category_id WHERE s.id=?",draft.serviceId());
  String names=quote.items().stream().map(CustomerPricingController.QuoteLine::serviceName).reduce((x,y)->x+", "+y).orElse(s.get("name").toString());
  UUID id=UUID.randomUUID();var at=Timestamp.from(now);
  Instant deadline = (draft.scheduledAt() != null && draft.scheduledAt().isAfter(now.plusSeconds(7200)))
      ? draft.scheduledAt()
      : now.plusSeconds(7200);
  var matchDeadline = Timestamp.from(deadline);
  db.update("INSERT INTO tasks(id,customer_id,service_id,status,service_slug_snapshot,service_name_snapshot,category_slug_snapshot,category_name_snapshot,suggested_price_min_snapshot,suggested_price_max_snapshot,title,description,address_label_snapshot,address_line_snapshot,ward_snapshot,district_snapshot,city_snapshot,recipient_name_snapshot,recipient_phone_snapshot,address_notes_snapshot,latitude,longitude,scheduled_at,estimated_duration_minutes,budget_amount,currency,customer_notes,expires_at,created_at,updated_at,platform_fee_snapshot) VALUES(?,?,?,'POSTED',?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
   id,owner,draft.serviceId(),s.get("slug"),names.substring(0,Math.min(160,names.length())),s.get("category_slug"),s.get("category_name"),s.get("suggested_price_min"),s.get("suggested_price_max"),s.get("name"),Objects.toString(draft.description(),""),a.get("label"),a.get("address_line"),a.get("ward"),a.get("district"),a.get("city"),a.get("recipient_name"),a.get("recipient_phone"),a.get("notes"),a.get("latitude"),a.get("longitude"),Timestamp.from(draft.scheduledAt()),draft.duration()*60,quote.total(),quote.currency(),draft.notes(),matchDeadline,at,at,quote.platformFee());
  db.update("UPDATE tasks SET building_type_snapshot=?,building_description_snapshot=? WHERE id=?",a.get("building_type"),a.get("building_description"),id);
  db.update("INSERT INTO task_booking_payments(task_id,quote_id,method,status,amount,draft_payload,posted_at,match_deadline,cancel_after) VALUES(?,?,?,?,?,?,?,?,?)",id,quoteId,method,(method.equals("BANK") || balanceAmount==quote.total())?"PAID":"AWAITING_CASH",quote.total(),payload,at,matchDeadline,at);
  db.update("UPDATE task_booking_payments SET balance_amount=? WHERE task_id=?",balanceAmount,id);
  for(var item:quote.items())db.update("INSERT INTO task_booking_services(task_id,service_id) VALUES(?,?)",id,item.serviceId());
  event(id,null,"POSTED","CUSTOMER","Đã xác nhận giá; "+(method.equals("BANK")?"đã thanh toán ngân hàng giả lập":"thanh toán trực tiếp, chờ Partner xác nhận thu tiền"));
  Object bookingId=draft.details().get("quoteSessionId");
  for(var pending:db.queryForList("SELECT id,payload FROM customer_pending_bookings WHERE customer_id=?",owner)) {
   var pendingDraft=json.readValue(pending.get("payload").toString(),BookingDraftController.Draft.class);
   if(payload.equals(pending.get("payload")) || (bookingId!=null && bookingId.equals(pendingDraft.details().get("quoteSessionId"))))
    db.update("DELETE FROM customer_pending_bookings WHERE customer_id=? AND id=?",owner,pending.get("id"));
  }
  db.update("DELETE FROM customer_booking_drafts WHERE customer_id=? AND payload=?",owner,payload);
  db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),owner,id,"Đặt dịch vụ \""+names+"\" thành công! Hệ thống đang tìm Đối tác phù hợp cho bạn.",at);
  return Map.of("id",id,"status","POSTED");
 }
 private void event(UUID id,String before,String after,String actor,String reason){db.update("INSERT INTO task_status_history(id,task_id,from_status,to_status,actor_role,reason,occurred_at) VALUES(?,?,?,?,?,?,?)",UUID.randomUUID(),id,before,after,actor,reason,Timestamp.from(clock.instant()));}
 public Map<String,Object> payment(UUID user,UUID id){var rows=db.queryForList("SELECT p.* FROM task_booking_payments p JOIN tasks t ON t.id=p.task_id WHERE p.task_id=? AND (t.customer_id=? OR t.tasker_id=?)",id,user,user);return rows.isEmpty()?Map.of():rows.getFirst();}
 @Transactional public void cancel(UUID owner,UUID id){
  var rows=db.queryForList("SELECT t.*,p.cancel_after,p.tasker_viewed_at,p.tasker_viewed_by,p.status AS payment_status,p.amount,p.balance_amount FROM tasks t JOIN task_booking_payments p ON p.task_id=t.id WHERE t.id=? AND t.customer_id=? FOR UPDATE",id,owner);
  if(rows.isEmpty())throw fail("TASK_NOT_FOUND","Không tìm thấy đơn của bạn.");var t=rows.getFirst();
  if(Set.of("REFUNDED","CANCELLED","EXPIRED").contains(t.get("status")))return;
  if(t.get("tasker_id")!=null || !Set.of("POSTED","MATCHING").contains(t.get("status")))throw fail("CANNOT_CANCEL","Tasker đã nhận việc. Bạn không thể hủy đơn; vui lòng liên hệ chăm sóc khách hàng nếu cần hỗ trợ.");
  refund(t,"Bạn đã hủy đơn.");
 }
 @Transactional public void adminCancel(UUID id,String reason){
  db.queryForList("SELECT id FROM tasks WHERE id=? FOR UPDATE",id);
  var rows=db.queryForList("SELECT t.*,p.status AS payment_status,p.amount,p.balance_amount FROM tasks t LEFT JOIN task_booking_payments p ON p.task_id=t.id WHERE t.id=?",id);
  if(rows.isEmpty())throw fail("TASK_NOT_FOUND","Không tìm thấy đơn.");
  var task=rows.getFirst();
  if(Set.of("CANCELLED","REFUNDED","EXPIRED").contains(task.get("status")))return;
  refund(task,"Admin hủy đơn: "+reason,"ADMIN");
  db.update("UPDATE early_start_requests SET status='CANCELLED' WHERE task_id=? AND status='PENDING'",id);
 }
 private Instant instant(Object value){if(value instanceof java.time.OffsetDateTime x)return x.toInstant();return ((Timestamp)value).toInstant();}
 private void refund(Map<String,Object> t,String reason){refund(t,reason,"SYSTEM");}
 private void refund(Map<String,Object> t,String reason,String actor){
  UUID id=(UUID)t.get("id");boolean paid="PAID".equals(t.get("payment_status"));long refundAmount=paid?((Number)t.get("amount")).longValue():(t.get("balance_amount") instanceof Number n?n.longValue():0L);String status=refundAmount>0?"REFUNDED":"CANCELLED";var at=Timestamp.from(clock.instant());
  if(refundAmount>0){db.update("INSERT INTO customer_refund_credits(task_id,customer_id,amount,created_at) VALUES(?,?,?,?)",id,t.get("customer_id"),refundAmount,at);db.update("UPDATE task_booking_payments SET status='REFUNDED',refunded_at=? WHERE task_id=?",at,id);}
  db.update("UPDATE tasks SET status=?,updated_at=?,version=version+1 WHERE id=?",status,at,id);
  event(id,t.get("status").toString(),status,actor,reason);
  db.update("UPDATE live_sync_revision SET revision=revision+1 WHERE id=1");
  db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),t.get("customer_id"),id,reason+(paid?" Đã hoàn "+t.get("amount")+" đ vào số dư hoàn tiền của bạn.":" Chưa thu tiền nên không có khoản cần hoàn."),at);
  UUID taskerId=(UUID)t.get("tasker_id");if(taskerId!=null){var appIds=db.queryForList("SELECT id FROM partner_applications WHERE user_id=?",UUID.class,taskerId);if(!appIds.isEmpty())db.update("INSERT INTO partner_notification_outbox(id,application_id,task_id,channel,status,title,message,created_at,delivered_at) VALUES(?,?,?,'IN_APP','DELIVERED',?,?,?,?)",UUID.randomUUID(),appIds.getFirst(),id,"Đơn đã được hủy #"+id.toString().substring(0,8).toUpperCase(),"Công việc "+t.get("service_name_snapshot")+" đã được hủy. Hệ thống sẽ tiếp tục điều phối đơn mới cho bạn.",at,at);}
 }
 @Scheduled(fixedDelay=30000) @Transactional public void expireUnmatched(){
  var rows=db.queryForList("SELECT t.*,p.status AS payment_status,p.amount,p.balance_amount FROM tasks t JOIN task_booking_payments p ON p.task_id=t.id WHERE t.status IN ('POSTED','MATCHING') AND t.tasker_id IS NULL AND p.match_deadline<=? FOR UPDATE",Timestamp.from(clock.instant()));
  for(var t:rows)refund(t,"Không có Partner nhận đơn trong 1 tiếng. Đơn đã được hủy tự động.");
 }
 @Transactional public void cashReceived(UUID partner,UUID id){
  var rows=db.queryForList("SELECT t.status,p.method,p.status AS payment_status FROM tasks t JOIN task_booking_payments p ON p.task_id=t.id WHERE t.id=? AND t.tasker_id=? FOR UPDATE",id,partner);
  if(rows.isEmpty())throw fail("TASK_NOT_FOUND","Không tìm thấy công việc của bạn.");var t=rows.getFirst();
  if(!"CASH".equals(t.get("method")) || !Set.of("COMPLETED","PAID").contains(t.get("status")))throw fail("CASH_NOT_READY","Chỉ xác nhận đã thu tiền trực tiếp sau khi hoàn thành công việc.");
  if("PAID".equals(t.get("payment_status")))return;
  db.update("UPDATE task_booking_payments SET status='PAID' WHERE task_id=?",id);db.update("UPDATE tasks SET status='PAID',version=version+1,updated_at=? WHERE id=?",Timestamp.from(clock.instant()),id);event(id,"COMPLETED","PAID","TASKER","Partner xác nhận đã nhận thanh toán trực tiếp.");
  var taskRow=db.queryForMap("SELECT t.customer_id,t.service_name_snapshot,(p.amount-p.balance_amount) AS budget_amount FROM tasks t JOIN task_booking_payments p ON p.task_id=t.id WHERE t.id=?",id);
  db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),taskRow.get("customer_id"),id,"Đối tác đã xác nhận thu "+taskRow.get("budget_amount")+" đ tiền mặt cho đơn \""+taskRow.get("service_name_snapshot")+"\". Cảm ơn bạn!",Timestamp.from(clock.instant()));
 }
 public void seedCustomerNotifications(UUID customerId){
  var tasks=db.queryForList("SELECT t.id, t.service_name_snapshot, t.status, t.created_at, u.full_name AS tasker_name FROM tasks t LEFT JOIN user_profiles u ON u.user_id=t.tasker_id WHERE t.customer_id=? ORDER BY t.created_at ASC",customerId);
  if(tasks.isEmpty()){
   db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,NULL,?,?)",UUID.randomUUID(),customerId,"Chào mừng bạn đến với TaskLy! Khám phá dịch vụ dọn dẹp, sửa chữa và đặt lịch nhanh chóng ngay hôm nay.",Timestamp.from(clock.instant()));
   return;
  }
  for(var task:tasks){
   UUID taskId=(UUID)task.get("id");
   String service=String.valueOf(task.get("service_name_snapshot"));
   String status=String.valueOf(task.get("status"));
   String tasker=task.get("tasker_name")!=null?String.valueOf(task.get("tasker_name")):"Đối tác TaskLy";
   Timestamp at=(Timestamp)task.get("created_at");
   db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),customerId,taskId,"Đặt dịch vụ \""+service+"\" thành công! Hệ thống đang tìm Đối tác phù hợp cho bạn.",at);
   if(Set.of("ACCEPTED","TASKER_ON_THE_WAY","ARRIVED","IN_PROGRESS","COMPLETED","PAID").contains(status)){
    db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),customerId,taskId,"Đối tác "+tasker+" đã nhận đơn \""+service+"\" của bạn.",at);
   }
   if(Set.of("TASKER_ON_THE_WAY","ARRIVED","IN_PROGRESS","COMPLETED","PAID").contains(status)){
    db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),customerId,taskId,"Đối tác "+tasker+" đang trên đường đến địa chỉ thực hiện đơn \""+service+"\".",at);
   }
   if(Set.of("IN_PROGRESS","COMPLETED","PAID").contains(status)){
    db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),customerId,taskId,"Đối tác đã bắt đầu thực hiện công việc \""+service+"\".",at);
   }
   if(Set.of("COMPLETED","PAID").contains(status)){
    db.update("INSERT INTO customer_booking_notifications(id,customer_id,task_id,title,created_at) VALUES(?,?,?,?,?)",UUID.randomUUID(),customerId,taskId,"Công việc \""+service+"\" đã hoàn tất! Vui lòng kiểm tra và đánh giá dịch vụ.",at);
   }
  }
 }
}
