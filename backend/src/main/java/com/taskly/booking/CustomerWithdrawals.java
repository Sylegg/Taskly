package com.taskly.booking;

import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.server.ResponseStatusException;

/** Called inside the customer/admin controller's transaction. */
final class CustomerWithdrawals {
 private CustomerWithdrawals() {}
 static Map<String,Object> create(JdbcTemplate db, UUID owner, UUID requestId, long amount,
   String bankName, String accountName, String accountNumber, String note) {
  if(amount<1 || amount>50000000 || bankName==null || bankName.isBlank() || bankName.trim().length()>100 ||
     accountName==null || accountName.isBlank() || accountName.trim().length()>150 ||
     accountNumber==null || !accountNumber.matches("[0-9]{6,34}"))
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Số tiền hoặc thông tin ngân hàng không hợp lệ");
  bankName=bankName.trim(); accountName=accountName.trim();
  db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",UUID.class,owner);
  var existing=db.queryForList("SELECT * FROM customer_refund_withdrawals WHERE id=?",requestId);
  if(!existing.isEmpty()) {
   var tx=existing.getFirst();
   if(!owner.equals(tx.get("customer_id")) || amount!=((Number)tx.get("amount")).longValue() ||
      !bankName.equals(tx.get("bank_name")) || !accountName.equals(tx.get("account_name")) || !accountNumber.equals(tx.get("account_number")))
    throw new ResponseStatusException(HttpStatus.CONFLICT,"Yêu cầu rút tiền không khớp");
   return Map.of("id",requestId,"status",tx.get("status"));
  }
  if(!db.queryForList("SELECT id FROM partner_wallet_transactions WHERE id=?",requestId).isEmpty())
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Mã giao dịch đã được sử dụng");
  if(amount>CustomerBalance.available(db,owner))
   throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"Số dư Customer khả dụng không đủ");
  db.update("INSERT INTO customer_refund_withdrawals(id,customer_id,amount,bank_name,account_name,account_number) VALUES(?,?,?,?,?,?)",
   requestId,owner,amount,bankName,accountName,accountNumber);
  WalletNotifications.send(db,owner,"CUSTOMER","WITHDRAWAL",amount,"PENDING",note);
  return Map.of("id",requestId,"status","PENDING");
 }
}
