package com.taskly.task;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class PartnerTaskSettlementTest {
    @Test void cashDeductsOnlyFeeAndBankCreditsNet() {
        for (String method : List.of("CASH", "BANK")) {
            var db = mock(JdbcTemplate.class);
            var task = UUID.randomUUID(); var partner = UUID.randomUUID();
            when(db.queryForList(anyString(), eq(task), eq(partner))).thenReturn(List.of(Map.of("budget_amount",100000L,"fee",10000L,"method",method,"payment_status", "PAID")));
            when(db.queryForObject("SELECT balance FROM partner_wallets WHERE user_id=? FOR UPDATE",Long.class,partner)).thenReturn(300000L);
            when(db.queryForObject("SELECT COUNT(*) FROM partner_task_settlements WHERE task_id=?",Integer.class,task)).thenReturn(0);
            when(db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM partner_wallet_transactions WHERE user_id=? AND type='WITHDRAWAL' AND status IN ('PENDING','APPROVED')",Long.class,partner)).thenReturn(0L);
            PartnerTaskSettlement.settle(db,task,partner);
            verify(db).update("UPDATE partner_wallets SET balance=balance+? WHERE user_id=?",method.equals("CASH") ? -10000L : 90000L,partner);
            clearInvocations(db);
            when(db.queryForObject("SELECT COUNT(*) FROM partner_task_settlements WHERE task_id=?",Integer.class,task)).thenReturn(1);
            PartnerTaskSettlement.settle(db,task,partner);
            verify(db,never()).update(eq("UPDATE partner_wallets SET balance=balance+? WHERE user_id=?"),any(),any());
        }
    }
}
