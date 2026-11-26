ALTER TABLE tasks ADD COLUMN partner_payment_confirmed_at TIMESTAMP WITH TIME ZONE;

-- PAID cash jobs were already explicitly confirmed through cash-received.
UPDATE tasks SET partner_payment_confirmed_at=updated_at
WHERE status='PAID' AND EXISTS (
 SELECT 1 FROM task_booking_payments p
 WHERE p.task_id=tasks.id AND p.method='CASH' AND p.status='PAID'
);
