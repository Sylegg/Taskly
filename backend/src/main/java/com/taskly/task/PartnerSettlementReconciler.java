package com.taskly.task;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.slf4j.LoggerFactory;

@Service
public class PartnerSettlementReconciler {
 private final JdbcTemplate db;
 private final TransactionTemplate transactions;
 public PartnerSettlementReconciler(JdbcTemplate db, PlatformTransactionManager manager) {
  this.db=db; this.transactions=new TransactionTemplate(manager);
 }
 @Scheduled(fixedDelay=30000, initialDelay=15000)
 public void reconcile() {
  var tasks=db.queryForList("SELECT t.id,t.tasker_id FROM tasks t JOIN task_booking_payments p ON p.task_id=t.id LEFT JOIN partner_task_settlements s ON s.task_id=t.id WHERE t.status IN ('COMPLETED','PAID') AND t.tasker_id IS NOT NULL AND s.task_id IS NULL AND (p.method='CASH' OR (p.method='BANK' AND p.status='PAID')) LIMIT 100");
  for(var task:tasks) {
   try {
    transactions.executeWithoutResult(tx -> {
     UUID partner=(UUID)task.get("tasker_id"); UUID id=(UUID)task.get("id");
     PartnerWorkPolicy.lock(db,partner);
     var status=db.queryForList("SELECT status FROM tasks WHERE id=? AND status IN ('COMPLETED','PAID') FOR UPDATE",id);
     if(!status.isEmpty())PartnerTaskSettlement.settle(db,id,partner);
    });
   } catch(Exception failure) { LoggerFactory.getLogger(getClass()).warn("Settlement pending for task {}: {}", task.get("id"), failure.getMessage()); }
  }
 }
}
