package com.taskly.booking;

import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@RestController @RequestMapping("/api/v1")
public class WalletFinanceSettings {
 private final JdbcTemplate db;
 public WalletFinanceSettings(JdbcTemplate db) { this.db=db; }
 public record Config(@Min(1) @Max(50000000) long minDeposit,
   @Min(1) @Max(50000000) long maxDeposit, @Min(1) @Max(50000000) long minWithdraw,
   @Min(1) @Max(50000000) long maxWithdrawDaily,
   @NotNull @DecimalMin("0") @DecimalMax("99") BigDecimal withdrawFeePercent,
   long autoApproveUnder,
   @NotBlank @Size(max=150) String bankName,
   @NotNull @Pattern(regexp="[0-9]{6,34}") String bankAccount,
   @NotBlank @Size(max=150) String accountOwner,
   @NotBlank @Size(max=80) String qrPrefix) {}
 public Config read() {
  return db.queryForObject("SELECT * FROM wallet_finance_settings WHERE id=1",(rs,n)->new Config(rs.getLong("min_deposit"),rs.getLong("max_deposit"),rs.getLong("min_withdraw"),rs.getLong("max_withdraw_daily"),rs.getBigDecimal("withdraw_fee_percent"),0,rs.getString("bank_name"),rs.getString("bank_account"),rs.getString("account_owner"),rs.getString("qr_prefix")));
 }
 @GetMapping("/admin/wallet-config") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
 public ApiResponse<?> get() { return ApiResponse.success(read()); }
 @PutMapping("/admin/wallet-config") @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
 public ApiResponse<?> save(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Config config) {
  if(config.minDeposit()>config.maxDeposit() || config.minWithdraw()>config.maxWithdrawDaily()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Hạn mức tối thiểu vượt quá hạn mức tối đa");
  db.update("UPDATE wallet_finance_settings SET min_deposit=?,max_deposit=?,min_withdraw=?,max_withdraw_daily=?,withdraw_fee_percent=?,bank_name=?,bank_account=?,account_owner=?,qr_prefix=?,updated_by=?,updated_at=CURRENT_TIMESTAMP WHERE id=1",config.minDeposit(),config.maxDeposit(),config.minWithdraw(),config.maxWithdrawDaily(),config.withdrawFeePercent(),config.bankName().trim(),config.bankAccount(),config.accountOwner().trim(),config.qrPrefix().trim(),UUID.fromString(jwt.getSubject()));
  return ApiResponse.success(read());
 }
}
