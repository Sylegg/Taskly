# Admin-managed Customer pricing

The user's decision was “admin tự sửa”. Pricing is configured server-side by Admins with SERVICE_MANAGE permission. No prices are seeded by migration; a service without an enabled rule returns PRICING_UNAVAILABLE. This change adds Admin APIs, not an Admin mobile tab or a complete Admin Web editor.

Prefix `/api/v1`:

| Method/path | Permission | Behavior |
|---|---|---|
| GET admin/services/{serviceId}/pricing | SERVICE_MANAGE | Rule metadata or null |
| PUT admin/services/{serviceId}/pricing | SERVICE_MANAGE | Validate/upsert rule and increment version; records actor and update time |
| POST users/me/booking-quotes | CUSTOMER | Validates all required service fields, future schedule and own address; computes/persists immutable price snapshot |
| GET users/me/booking-quotes/{id} | CUSTOMER + owner | Rejects expired, repriced, disabled or unavailable service quotes |

Required write fields: `mode`, `baseAmount`, `unitAmount`, `platformFeeAmount`, `quoteTtlMinutes`, `enabled`; `quantityField` is required only for FIELD. Amounts are integer VND. FIXED requires unitAmount=0; HOURLY uses requested duration; FIELD uses a numeric field advertised in the service schema. Unknown fields are rejected. Admin supplies all amounts and the 1–60 minute quote TTL. No voucher or cancellation/refund rule is implied.

Formulas supported in this first version:

- FIXED: baseAmount + platformFeeAmount.
- HOURLY: baseAmount + duration × unitAmount + platformFeeAmount.
- FIELD: baseAmount + details[quantityField] × unitAmount + platformFeeAmount.

For example, Admin can choose units for máy lạnh, area for cleaning, count for pets, or boxes for moving. Shopping budget stays a separate customer requirement; Admin should use a fixed/hourly service rule if shopping budget must not drive the fee. Advanced multi-field/tiered pricing is not implemented.

Rules are serialized by the existing service row; quote reads lock the rule. Snapshot stores owner, original draft inputs, rule version, subtotal, fee, total, VND and expiresAt. Changing booking inputs in Flutter clears its displayed quote. Changing Admin rules or service availability invalidates existing quotes when revalidated server-side.

Flyway V9 adds service_pricing_rules and customer_price_quotes. All amounts default to nothing: Admin must create and enable each rule. Payment/reservation endpoints must revalidate snapshot, ownership, expiry and identical inputs before consuming a quote; they remain unimplemented pending a sandbox provider contract. Configuring a rule never charges money.
