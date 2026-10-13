package com.taskly.booking;

import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import java.math.RoundingMode;
import java.math.BigDecimal;
import java.time.*;
import java.sql.Timestamp;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@RestController
@RequestMapping("/api/v1")
public class PartnerWalletController {
 private final JdbcTemplate db;
 public PartnerWalletController(JdbcTemplate db) { this.db = db; }
 public record Request(@Min(1) @Max(50000000) long amount,
   @NotNull UUID requestId, String bankName, String accountName, String accountNumber) {}
 public record Decision(@NotNull @Pattern(regexp="APPROVED|PAID|REJECTED") String status,
   @Size(max=150) String referenceCode, @Size(max=500) String note) {}
 private void ensureWallet(UUID owner) {
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,owner);
  db.update("INSERT INTO partner_wallets(user_id) SELECT ? WHERE NOT EXISTS (SELECT 1 FROM partner_wallets WHERE user_id=?)", owner,owner);
 }
 private long available(UUID owner) {
  return db.queryForObject("SELECT balance - COALESCE((SELECT SUM(amount) FROM partner_wallet_transactions WHERE user_id=? AND type='WITHDRAWAL' AND status IN ('PENDING','APPROVED')),0) FROM partner_wallets WHERE user_id=?", Long.class, owner, owner);
 }
 @GetMapping("/partner/wallet") @PreAuthorize("hasRole('TASKER')") @Transactional
 public ApiResponse<?> wallet(@AuthenticationPrincipal Jwt jwt) {
  UUID owner=UUID.fromString(jwt.getSubject()); ensureWallet(owner);
  long serviceIncome = db.queryForObject("SELECT COALESCE(SUM(t.budget_amount-" + com.taskly.task.PartnerEarnings.FEE_SQL + "),0) FROM tasks t LEFT JOIN service_pricing_rules r ON r.service_id=t.service_id WHERE t.tasker_id=? AND t.status IN ('COMPLETED','PAID')", Long.class, owner);
  return ApiResponse.success(Map.of("balance",available(owner),"serviceIncome",serviceIncome,"config",new WalletFinanceSettings(db).read(),"transactions",db.queryForList("SELECT * FROM partner_wallet_transactions WHERE user_id=? AND user_role='PARTNER' ORDER BY created_at DESC",owner)));
 }
 @PostMapping("/partner/wallet/{type}") @PreAuthorize("hasRole('TASKER')") @Transactional
 public ApiResponse<?> request(@AuthenticationPrincipal Jwt jwt,@PathVariable String type,@Valid @RequestBody Request body) {
  UUID owner=UUID.fromString(jwt.getSubject());
  if (!Set.of("deposit","withdraw").contains(type)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  ensureWallet(owner); db.queryForObject("SELECT balance FROM partner_wallets WHERE user_id=? FOR UPDATE",Long.class,owner);
  var existing=db.queryForList("SELECT * FROM partner_wallet_transactions WHERE id=?",body.requestId());
  if (!existing.isEmpty()) {
   var tx=existing.getFirst();
   if (!owner.equals(tx.get("user_id")) || ((Number)tx.get("amount")).longValue()!=body.amount() || !tx.get("type").equals(type.equals("deposit")?"DEPOSIT":"WITHDRAWAL")) throw new ResponseStatusException(HttpStatus.CONFLICT,"Yêu cầu không khớp");
   return ApiResponse.success(tx);
  }
  boolean withdrawal=type.equals("withdraw");
  String bankName = body.bankName(), accountName = body.accountName(), accountNumber = body.accountNumber();
  if (withdrawal) {
   try {
    var banks = db.queryForList("SELECT bank_name,account_name,account_number FROM partner_bank_accounts WHERE user_id=?", owner);
    if (!banks.isEmpty()) {
     bankName = String.valueOf(banks.getFirst().get("bank_name"));
     accountName = String.valueOf(banks.getFirst().get("account_name"));
     accountNumber = String.valueOf(banks.getFirst().get("account_number"));
    }
   } catch (Exception ignored) {}
   if (bankName == null || bankName.isBlank()) {
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Vui lòng thêm tài khoản ngân hàng trước khi rút tiền");
   }
  }
  var config=new WalletFinanceSettings(db).read();
  if(body.amount() < (withdrawal?config.minWithdraw():config.minDeposit()) || (!withdrawal && body.amount()>config.maxDeposit())) throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"Số tiền không nằm trong hạn mức cấu hình");
  long fee=withdrawal?BigDecimal.valueOf(body.amount()).multiply(config.withdrawFeePercent()).divide(BigDecimal.valueOf(100),0,RoundingMode.CEILING).longValue():0;
  if (withdrawal) {
   if (bankName==null || bankName.isBlank() || bankName.length()>100 || accountName==null || accountName.isBlank() || accountName.length()>150 || accountNumber==null || !accountNumber.matches("[0-9]{6,34}")) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Thông tin ngân hàng không hợp lệ");
   if(body.amount()>available(owner)) throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"Số dư khả dụng không đủ");
   var start=LocalDate.now(ZoneId.of("Asia/Bangkok")).atStartOfDay(ZoneId.of("Asia/Bangkok"));
   long today=db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM partner_wallet_transactions WHERE user_id=? AND type='WITHDRAWAL' AND status IN ('PENDING','APPROVED','PAID') AND created_at>=? AND created_at<?",Long.class,owner,Timestamp.from(start.toInstant()),Timestamp.from(start.plusDays(1).toInstant()));
   if(today+body.amount()>config.maxWithdrawDaily()) throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"Vượt hạn mức rút tiền trong ngày");
  }
  db.update("INSERT INTO partner_wallet_transactions(id,user_id,type,amount,status,bank_name,account_name,account_number) VALUES(?,?,?,?,?,?,?,?)",body.requestId(),owner,withdrawal?"WITHDRAWAL":"DEPOSIT",body.amount(),withdrawal?"PENDING":"COMPLETED",bankName,accountName,accountNumber);
  db.update("UPDATE partner_wallet_transactions SET fee=?,method=? WHERE id=?",fee,withdrawal?"Chuyển khoản ngân hàng":"Nạp ví",body.requestId());
  if(!withdrawal) {
   db.update("UPDATE partner_wallets SET balance=balance+? WHERE user_id=?",body.amount(),owner);
   db.update("UPDATE partner_wallet_transactions SET completed_at=CURRENT_TIMESTAMP WHERE id=?",body.requestId());
  }
  if (!"internal".equals(jwt.getTokenValue())) WalletNotifications.send(db,owner,"PARTNER",withdrawal?"WITHDRAWAL":"DEPOSIT",body.amount(),withdrawal?"PENDING":"COMPLETED",null);
  return ApiResponse.success(Map.of("id",body.requestId(),"status",withdrawal?"PENDING":"COMPLETED"));
 }
 @GetMapping("/admin/partner-wallet-transactions") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
 public ApiResponse<?> transactions(@RequestParam(required=false) String role) { if(role!=null && !Set.of("PARTNER","CUSTOMER").contains(role)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Role không hợp lệ"); return ApiResponse.success(db.queryForList("SELECT t.*,p.full_name AS user_name,u.phone AS user_phone FROM partner_wallet_transactions t JOIN users u ON u.id=t.user_id LEFT JOIN user_profiles p ON p.user_id=t.user_id WHERE (? IS NULL OR t.user_role=?) ORDER BY t.created_at DESC",role,role)); }
 public record Manual(@NotNull UUID userId,@NotNull UUID requestId,
   @NotNull @Pattern(regexp="DEPOSIT|WITHDRAWAL") String type,
   @NotNull @Pattern(regexp="PARTNER|CUSTOMER") String userRole,
   @Min(1) @Max(50000000) long amount,
   @NotBlank @Size(max=150) String method,
   String bankName,String accountName,String accountNumber,@Size(max=500) String note) {}
 @PostMapping("/admin/partner-wallet-transactions") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')") @Transactional
 public ApiResponse<?> manual(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Manual body) {
  if(db.queryForObject("SELECT COUNT(*) FROM users WHERE id=?",Integer.class,body.userId())==0) throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Người dùng không tồn tại");
  if("CUSTOMER".equals(body.userRole()) && "DEPOSIT".equals(body.type())) {
   db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,body.userId());
   var rows=db.queryForList("SELECT * FROM partner_wallet_transactions WHERE id=?",body.requestId());
   if(!rows.isEmpty()) {
    var tx=rows.getFirst();
    if(!body.userId().equals(tx.get("user_id")) || !"CUSTOMER".equals(tx.get("user_role")) || !"DEPOSIT".equals(tx.get("type")) || body.amount()!=((Number)tx.get("amount")).longValue())
     throw new ResponseStatusException(HttpStatus.CONFLICT,"Yêu cầu không khớp");
    return ApiResponse.success(tx);
   }
   db.update("INSERT INTO partner_wallet_transactions(id,user_id,type,amount,status,user_role,method,note,updated_by,completed_at) VALUES(?,?,'DEPOSIT',?,'COMPLETED','CUSTOMER',?,?,?,CURRENT_TIMESTAMP)",body.requestId(),body.userId(),body.amount(),body.method(),body.note(),UUID.fromString(jwt.getSubject()));
   WalletNotifications.send(db,body.userId(),"CUSTOMER","DEPOSIT",body.amount(),"COMPLETED",body.note());
   return ApiResponse.success(Map.of("id",body.requestId(),"status","COMPLETED"));
  }
  var ownerJwt=Jwt.withTokenValue("internal").header("alg","none").subject(body.userId().toString()).build();
  boolean existing=db.queryForObject("SELECT COUNT(*) FROM partner_wallet_transactions WHERE id=?",Integer.class,body.requestId())>0;
  var result=request(ownerJwt,body.type().equals("DEPOSIT")?"deposit":"withdraw",new Request(body.amount(),body.requestId(),body.bankName(),body.accountName(),body.accountNumber()));
  if(!existing) db.update("UPDATE partner_wallet_transactions SET user_role=?,method=?,note=?,updated_by=? WHERE id=? AND user_id=?",body.userRole(),body.method(),body.note(),UUID.fromString(jwt.getSubject()),body.requestId(),body.userId());
  if(!existing) WalletNotifications.send(db,body.userId(),body.userRole(),body.type(),body.amount(),body.type().equals("WITHDRAWAL")?"PENDING":"COMPLETED",body.note());
  return result;
 }
 @PostMapping("/admin/partner-wallet-transactions/{id}/status") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')") @Transactional
 public ApiResponse<?> decision(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,@Valid @RequestBody Decision body) {
  var rows=db.queryForList("SELECT user_id FROM partner_wallet_transactions WHERE id=?",id);
  if(rows.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
  UUID owner=(UUID)rows.getFirst().get("user_id");
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,owner);
  var customerTx=db.queryForMap("SELECT * FROM partner_wallet_transactions WHERE id=? FOR UPDATE",id);
  if("CUSTOMER".equals(customerTx.get("user_role")) && "DEPOSIT".equals(customerTx.get("type"))) {
   String target="APPROVED".equals(body.status())?"COMPLETED":body.status();
   if(target.equals(customerTx.get("status")))return ApiResponse.success(customerTx);
   if(!"PENDING".equals(customerTx.get("status")) || !Set.of("COMPLETED","REJECTED").contains(target))
    throw new ResponseStatusException(HttpStatus.CONFLICT,"Trạng thái nạp tiền đã thay đổi");
   db.update("UPDATE partner_wallet_transactions SET status=?,note=?,updated_by=?,completed_at=CURRENT_TIMESTAMP WHERE id=?",target,body.note(),UUID.fromString(jwt.getSubject()),id);
   WalletNotifications.send(db,owner,"CUSTOMER","DEPOSIT",((Number)customerTx.get("amount")).longValue(),target,body.note());
   return ApiResponse.success(Map.of("id",id,"status",target));
  }
  db.queryForObject("SELECT balance FROM partner_wallets WHERE user_id=? FOR UPDATE",Long.class,owner);
  var tx=db.queryForMap("SELECT * FROM partner_wallet_transactions WHERE id=? FOR UPDATE",id);
  String current=(String)tx.get("status");
  if(current.equals(body.status())) return ApiResponse.success(tx);
  boolean allowed=tx.get("type").equals("WITHDRAWAL") && ((current.equals("PENDING") && Set.of("APPROVED","REJECTED").contains(body.status())) || (current.equals("APPROVED") && Set.of("PAID","REJECTED").contains(body.status())));
  if(!allowed) throw new ResponseStatusException(HttpStatus.CONFLICT,"Trạng thái giao dịch đã thay đổi");
  if(body.status().equals("PAID")) {
   if(body.referenceCode()==null || body.referenceCode().isBlank()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Nhập mã chuyển khoản");
   db.update("UPDATE partner_wallets SET balance=balance-? WHERE user_id=?",tx.get("amount"),owner);
  }
  db.update("UPDATE partner_wallet_transactions SET status=?,reference_code=?,note=?,updated_by=?,completed_at=CASE WHEN ? IN ('PAID','REJECTED') THEN CURRENT_TIMESTAMP ELSE NULL END WHERE id=?",body.status(),body.referenceCode(),body.note(),UUID.fromString(jwt.getSubject()),body.status(),id);
  WalletNotifications.send(db,owner,String.valueOf(tx.get("user_role")),String.valueOf(tx.get("type")),((Number)tx.get("amount")).longValue(),body.status(),body.note());
  return ApiResponse.success(Map.of("id",id,"status",body.status()));
 }
}
