package com.taskly.task;

/** Persist the fee when accepting a job so later pricing changes do not change earnings. */
public final class PartnerEarnings {
    private PartnerEarnings() {}
    public static final String FEE_SQL = "COALESCE(t.platform_fee_snapshot, LEAST(t.budget_amount, COALESCE(CASE WHEN r.platform_fee_percent IS NOT NULL THEN ROUND(t.budget_amount*r.platform_fee_percent/100) ELSE r.platform_fee_amount END,0)))";
}
