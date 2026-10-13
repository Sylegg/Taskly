package com.taskly.recruitment;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import com.taskly.common.api.ApiResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/partner/bank-account") @PreAuthorize("hasRole('TASKER')")
public class PartnerBankController {
 private final JdbcTemplate db; public PartnerBankController(JdbcTemplate db){this.db=db;}
 public record Bank(@NotBlank @Size(max=100) String bankName,@NotBlank @Size(max=150) String accountName,@NotNull @Pattern(regexp="[0-9]{6,34}") String accountNumber){}
 @GetMapping public ApiResponse<?> get(@AuthenticationPrincipal Jwt jwt){var list=db.queryForList("SELECT bank_name AS \"bankName\",account_name AS \"accountName\",account_number AS \"accountNumber\" FROM partner_bank_accounts WHERE user_id=?",UUID.fromString(jwt.getSubject()));return ApiResponse.success(list.isEmpty()?null:list.getFirst());}
 @PutMapping @org.springframework.transaction.annotation.Transactional public ApiResponse<?> save(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody Bank bank){UUID id=UUID.fromString(jwt.getSubject());db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,id);String accountName=db.queryForObject("SELECT full_name FROM user_profiles WHERE user_id=?",String.class,id);if(accountName==null||accountName.isBlank())throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.BAD_REQUEST,"Hồ sơ Partner chưa có họ tên");accountName=accountName.trim().toUpperCase(Locale.ROOT);if(db.update("UPDATE partner_bank_accounts SET bank_name=?,account_name=?,account_number=?,updated_at=CURRENT_TIMESTAMP WHERE user_id=?",bank.bankName().trim(),accountName,bank.accountNumber(),id)==0)db.update("INSERT INTO partner_bank_accounts(user_id,bank_name,account_name,account_number) VALUES(?,?,?,?)",id,bank.bankName().trim(),accountName,bank.accountNumber());return get(jwt);}
}
