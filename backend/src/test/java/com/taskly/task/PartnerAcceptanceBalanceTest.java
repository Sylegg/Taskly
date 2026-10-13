package com.taskly.task;

import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import com.taskly.common.exception.DomainException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PartnerAcceptanceBalanceTest {
    @Test void onlyAvailableBalanceStrictlyAboveThresholdCanAccept() {
        var user = UUID.randomUUID();
        var db = mock(JdbcTemplate.class);
        String wallet = "SELECT balance FROM partner_wallets WHERE user_id=? FOR UPDATE";
        String withdrawal = "SELECT COALESCE(SUM(amount),0) FROM partner_wallet_transactions WHERE user_id=? AND type='WITHDRAWAL' AND status IN ('PENDING','APPROVED')";
        when(db.queryForObject(withdrawal, Long.class, user)).thenReturn(0L);
        for (long balance : new long[]{0, 199999, 200000}) {
            when(db.queryForList(wallet, Long.class, user)).thenReturn(List.of(balance));
            assertThrows(DomainException.class, () -> PartnerAcceptanceBalance.require(db, user));
        }
        when(db.queryForList(wallet, Long.class, user)).thenReturn(List.of(200001L));
        assertDoesNotThrow(() -> PartnerAcceptanceBalance.require(db, user));
        when(db.queryForObject(withdrawal, Long.class, user)).thenReturn(1L);
        assertThrows(DomainException.class, () -> PartnerAcceptanceBalance.require(db, user));
        when(db.queryForList(wallet, Long.class, user)).thenReturn(List.of());
        assertThrows(DomainException.class, () -> PartnerAcceptanceBalance.require(db, user));
    }
}
