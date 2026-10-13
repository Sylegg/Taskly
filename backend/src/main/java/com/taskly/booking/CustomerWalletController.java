package com.taskly.booking;

import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@RestController @RequestMapping("/api/v1/users/me/wallet")
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerWalletController {
 private final JdbcTemplate db;
 private final BookingCheckout checkout;
 private final WalletFinanceSettings settings;
 public CustomerWalletController(JdbcTemplate db, BookingCheckout checkout, WalletFinanceSettings settings) {
  this.db=db;this.checkout=checkout;this.settings=settings;
 }
 public record Deposit(@NotNull UUID requestId,@Min(1) @Max(50000000) long amount) {}
 @GetMapping public ApiResponse<?> wallet(@AuthenticationPrincipal Jwt jwt) {
  UUID owner=UUID.fromString(jwt.getSubject());
  return ApiResponse.success(Map.of("balance",checkout.availableBalance(owner),"config",settings.read(),"requestId",UUID.randomUUID(),
   "transactions",db.queryForList("SELECT * FROM partner_wallet_transactions WHERE user_id=? AND user_role='CUSTOMER' AND type='DEPOSIT' ORDER BY created_at DESC",owner)));
 }
 @PostMapping("/deposit") @Transactional
 public ApiResponse<?> deposit(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Deposit body) {
  UUID owner=UUID.fromString(jwt.getSubject());
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,owner);
  var existing=db.queryForList("SELECT * FROM partner_wallet_transactions WHERE id=?",body.requestId());
  if(!existing.isEmpty()) {
   var tx=existing.getFirst();
   if(!owner.equals(tx.get("user_id")) || !"CUSTOMER".equals(tx.get("user_role")) || !"DEPOSIT".equals(tx.get("type")) || body.amount()!=((Number)tx.get("amount")).longValue())
    throw new ResponseStatusException(HttpStatus.CONFLICT,"Yêu cầu nạp tiền không khớp");
   return ApiResponse.success(tx);
  }
  var config=settings.read();
  if(body.amount()<config.minDeposit() || body.amount()>config.maxDeposit())
   throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"Số tiền nạp không nằm trong hạn mức cho phép");
  String reference=config.qrPrefix()+" "+body.requestId();
  db.update("INSERT INTO partner_wallet_transactions(id,user_id,type,amount,status,user_role,method,bank_name,account_name,account_number,reference_code) VALUES(?,?,'DEPOSIT',?,'PENDING','CUSTOMER',?,?,?,?,?)",
   body.requestId(),owner,body.amount(),"Chuyển khoản ngân hàng",config.bankName(),config.accountOwner(),config.bankAccount(),reference);
  WalletNotifications.send(db,owner,"CUSTOMER","DEPOSIT",body.amount(),"PENDING",null);
  return ApiResponse.success(Map.of("id",body.requestId(),"status","PENDING","reference_code",reference));
 }
}
