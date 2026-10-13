package com.taskly.task;

import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;
import com.taskly.common.exception.DomainException;

public final class PartnerAcceptanceBalance {
    private PartnerAcceptanceBalance() {}
    public static void require(JdbcTemplate db, UUID partner) {
        var balances = db.queryForList("SELECT balance FROM partner_wallets WHERE user_id=? FOR UPDATE", Long.class, partner);
        long balance = balances.isEmpty() ? 0 : balances.getFirst();
        Long reserved = db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM partner_wallet_transactions WHERE user_id=? AND type='WITHDRAWAL' AND status IN ('PENDING','APPROVED')", Long.class, partner);
        if (balance - (reserved == null ? 0 : reserved) <= 200000) {
            throw new DomainException("PARTNER_WALLET_BALANCE_TOO_LOW", "Số dư khả dụng ví Partner phải trên 200.000đ mới được nhận đơn. Vui lòng nạp thêm tiền vào ví.", HttpStatus.CONFLICT);
        }
    }
}
