package com.taskly.booking;

import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;

final class CustomerBalance {
 private CustomerBalance() {}
 static long available(JdbcTemplate db, UUID owner) {
  long credits=db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM customer_refund_credits WHERE customer_id=?",Long.class,owner);
  long reserved=db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM customer_refund_withdrawals WHERE customer_id=? AND status IN ('PENDING','PAID')",Long.class,owner);
  long spent=db.queryForObject("SELECT COALESCE(SUM(p.balance_amount),0) FROM task_booking_payments p JOIN tasks t ON t.id=p.task_id WHERE t.customer_id=?",Long.class,owner);
  long deposits=db.queryForObject("SELECT COALESCE(SUM(amount),0) FROM partner_wallet_transactions WHERE user_id=? AND user_role='CUSTOMER' AND type='DEPOSIT' AND status='COMPLETED'",Long.class,owner);
  return credits+deposits-reserved-spent;
 }
}
