package com.taskly.task;

import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.http.HttpStatus;
import com.taskly.common.exception.DomainException;

/** Called inside the task completion transaction; one wallet settlement per task. */
public final class PartnerTaskSettlement {
    private PartnerTaskSettlement() {}
    public static void settle(JdbcTemplate db, UUID task, UUID partner) {
        var rows = db.queryForList("SELECT t.budget_amount," + PartnerEarnings.FEE_SQL + " AS fee,p.method,p.status AS payment_status,p.balance_amount FROM tasks t JOIN task_booking_payments p ON p.task_id=t.id LEFT JOIN service_pricing_rules r ON r.service_id=t.service_id WHERE t.id=? AND t.tasker_id=?", task, partner);
        if (rows.isEmpty()) return;
        var payment = rows.getFirst();
        String method = String.valueOf(payment.get("method"));
        if (!method.equals("CASH") && !(method.equals("BANK") && "PAID".equals(payment.get("payment_status"))))
            throw new DomainException("PAYMENT_NOT_READY", "Đơn chưa được thanh toán qua tài khoản.", HttpStatus.CONFLICT);
        db.update("INSERT INTO partner_wallets(user_id) VALUES(?) ON CONFLICT(user_id) DO NOTHING", partner);
        long balance = db.queryForObject("SELECT balance FROM partner_wallets WHERE user_id=? FOR UPDATE", Long.class, partner);
        if (db.queryForObject("SELECT COUNT(*) FROM partner_task_settlements WHERE task_id=?", Integer.class, task) > 0) return;
        long fee = ((Number)payment.get("fee")).longValue();
        long walletPaid = payment.get("balance_amount") instanceof Number paid ? paid.longValue() : 0;
        long delta = method.equals("CASH") ? walletPaid - fee : ((Number)payment.get("budget_amount")).longValue() - fee;
        long reserved = db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM partner_wallet_transactions WHERE user_id=? AND type='WITHDRAWAL' AND status IN ('PENDING','APPROVED')", Long.class, partner);
        if (delta < 0 && balance - reserved + delta < 0)
            throw new DomainException("INSUFFICIENT_PLATFORM_FEE", "Ví chưa đủ tiền trừ phí đơn tiền mặt. Vui lòng nạp thêm tiền.", HttpStatus.CONFLICT);
        db.update("INSERT INTO partner_task_settlements(task_id,partner_id,method,wallet_delta) VALUES(?,?,?,?)", task, partner, method, delta);
        db.update("UPDATE partner_wallets SET balance=balance+? WHERE user_id=?", delta, partner);
        if (delta != 0) db.update("INSERT INTO partner_wallet_transactions(id,user_id,type,amount,status,method,note,reference_code,completed_at) VALUES(?,?,?,?,'COMPLETED',?,?,?,CURRENT_TIMESTAMP)",
            UUID.randomUUID(), partner, delta < 0 ? "WITHDRAWAL" : "DEPOSIT", Math.abs(delta),
            method.equals("CASH") ? "Phí đơn tiền mặt" : "Thu nhập dịch vụ", "Quyết toán đơn #" + task, task.toString());
    }
}
