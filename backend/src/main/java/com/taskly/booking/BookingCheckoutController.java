package com.taskly.booking;
import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1")
public class BookingCheckoutController {
 private final BookingCheckout checkout; private final JdbcTemplate db;
 public BookingCheckoutController(BookingCheckout checkout,JdbcTemplate db){this.checkout=checkout;this.db=db;}
 public record Confirm(@NotNull UUID quoteId,@NotNull @Pattern(regexp="CASH|BANK") String method,@Min(0) long balanceAmount){}
 @PostMapping("/users/me/booking-checkout") @PreAuthorize("hasRole('CUSTOMER')")
 public ApiResponse<Map<String,Object>> confirm(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Confirm body){return ApiResponse.success(checkout.checkout(UUID.fromString(jwt.getSubject()),body.quoteId(),body.method(),body.balanceAmount()));}
 @PostMapping("/task-activity/{id}/cancel") @PreAuthorize("hasRole('CUSTOMER')")
 public ApiResponse<Void> cancel(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){checkout.cancel(UUID.fromString(jwt.getSubject()),id);return ApiResponse.success(null);}
 @PostMapping("/partner/jobs/{id}/cash-received") @PreAuthorize("hasRole('TASKER')")
 public ApiResponse<Void> cash(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){checkout.cashReceived(UUID.fromString(jwt.getSubject()),id);return ApiResponse.success(null);}
  @GetMapping("/users/me/booking-notifications") @PreAuthorize("hasRole('CUSTOMER')")
  public ApiResponse<List<Map<String,Object>>> notifications(@AuthenticationPrincipal Jwt jwt){
   UUID customerId = UUID.fromString(jwt.getSubject());
   var list = db.queryForList("SELECT id,task_id AS taskId,title,created_at AS at,read_at AS readAt FROM customer_booking_notifications WHERE customer_id=? ORDER BY created_at DESC", customerId);
   if (list.isEmpty()) {
    checkout.seedCustomerNotifications(customerId);
    list = db.queryForList("SELECT id,task_id AS taskId,title,created_at AS at,read_at AS readAt FROM customer_booking_notifications WHERE customer_id=? ORDER BY created_at DESC", customerId);
   }
   return ApiResponse.success(list);
  }
  @PostMapping("/users/me/booking-notifications/{id}/read") @PreAuthorize("hasRole('CUSTOMER')")
  public ApiResponse<Void> read(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id){db.update("UPDATE customer_booking_notifications SET read_at=CURRENT_TIMESTAMP WHERE id=? AND customer_id=?",id,UUID.fromString(jwt.getSubject()));return ApiResponse.success(null);}
  @PostMapping("/users/me/booking-notifications/read-all") @PreAuthorize("hasRole('CUSTOMER')")
  public ApiResponse<Void> readAll(@AuthenticationPrincipal Jwt jwt){db.update("UPDATE customer_booking_notifications SET read_at=CURRENT_TIMESTAMP WHERE customer_id=? AND read_at IS NULL",UUID.fromString(jwt.getSubject()));return ApiResponse.success(null);}
 public record Withdrawal(@Min(1) long amount,@NotBlank @Size(max=100) String bankName,@NotBlank @Size(max=150) String accountName,@Pattern(regexp="[0-9]{6,34}") @NotNull String accountNumber){}
 private long available(UUID owner){
  return checkout.availableBalance(owner);
 }
 @GetMapping("/users/me/refund-balance") @PreAuthorize("hasRole('CUSTOMER')")
 public ApiResponse<?> balance(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(Map.of("amount",available(UUID.fromString(jwt.getSubject())),"currency","VND"));}
 @PostMapping("/users/me/refund-withdrawals") @PreAuthorize("hasRole('CUSTOMER')") @org.springframework.transaction.annotation.Transactional
 public ApiResponse<?> withdraw(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Withdrawal body){
  UUID owner=UUID.fromString(jwt.getSubject());db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,owner);
  if(body.amount()>available(owner))throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.UNPROCESSABLE_ENTITY,"Insufficient available balance");
  UUID id=UUID.randomUUID();db.update("INSERT INTO customer_refund_withdrawals(id,customer_id,amount,bank_name,account_name,account_number) VALUES(?,?,?,?,?,?)",id,owner,body.amount(),body.bankName().trim(),body.accountName().trim(),body.accountNumber());
  WalletNotifications.send(db,owner,"CUSTOMER","WITHDRAWAL",body.amount(),"PENDING",null);
  return ApiResponse.success(Map.of("id",id,"status","PENDING"));
 }
 @GetMapping("/users/me/refund-withdrawals") @PreAuthorize("hasRole('CUSTOMER')")
 public ApiResponse<?> withdrawals(@AuthenticationPrincipal Jwt jwt){return ApiResponse.success(db.queryForList("SELECT id,amount,status,bank_name,created_at FROM customer_refund_withdrawals WHERE customer_id=? ORDER BY created_at DESC",UUID.fromString(jwt.getSubject())));}
 @GetMapping("/admin/refund-withdrawals") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
 public ApiResponse<?> adminWithdrawals(){return ApiResponse.success(db.queryForList("SELECT * FROM customer_refund_withdrawals ORDER BY created_at DESC"));}
 @PostMapping("/admin/refund-withdrawals/{id}/status") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
 @org.springframework.transaction.annotation.Transactional
 public ApiResponse<?> updateAdminWithdrawalStatus(@PathVariable UUID id, @RequestBody Map<String,String> body){
  String status = body.getOrDefault("status", "PAID");
  var tx=db.queryForMap("SELECT * FROM customer_refund_withdrawals WHERE id=? FOR UPDATE",id);
  if(status.equals(tx.get("status")))return ApiResponse.success(Map.of("id",id,"status",status));
  if(!Set.of("PAID","REJECTED").contains(status) || !"PENDING".equals(tx.get("status")))throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.CONFLICT,"Trạng thái yêu cầu rút tiền không hợp lệ");
  db.update("UPDATE customer_refund_withdrawals SET status=? WHERE id=?", status, id);
  WalletNotifications.send(db,(UUID)tx.get("customer_id"),"CUSTOMER","WITHDRAWAL",((Number)tx.get("amount")).longValue(),status,body.get("note"));
  return ApiResponse.success(Map.of("id", id, "status", status));
 }
}
