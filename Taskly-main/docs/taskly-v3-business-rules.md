# Implemented rules and unapproved assumptions

Drafts are editable partial data, not tasks or payments. One persisted draft belongs to each Customer account. Only that account can read/change/delete it; other accounts see their own draft or null. Persisting a draft does not assign a Partner, reserve availability, hold funds or send notifications.

Service must be active with an active category and VND currency. Schema key/version must match an advertised slug. Unknown fields, invalid choices, negative/out-of-range/fractional quantities and foreign/deleted addresses are rejected server-side. Required fields, future schedule and own address are checked before reaching the Flutter review step. Incomplete drafts are deliberately allowed to be saved.

The eight requirement schemas follow the reference; aliases bridge existing catalogue slugs. They are versioned code, not mutable Admin configuration. A generic unknown service cannot silently fall back to the cleaning form. Shopping budget is distinct from service charges. Same pickup and dropoff are rejected when both are provided.

Reference catalogue suggestedPriceMin is displayed as a starting reference amount, never multiplied as an hourly quote. Actual quotes use separate Admin-configured FIXED/HOURLY/FIELD rules, explicit fees and TTL. No fee percentages, protection charges, rewards, voucher discounts, escrow, automatic settlements or cancellation fees were adopted from HTML. Quotes now use Admin-configured server rules; see taskly-v3-admin-pricing.md. Payment sandbox, task creation and money transitions remain unavailable until their contracts exist.

Drafts can contain an old schedule; review requires a future schedule. Concurrent saves are serialized but use last-successful-write semantics; conflict/version UI and multiple drafts are not implemented. Sensitive payment credentials are never included in the draft.
