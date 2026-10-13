# Customer-first implementation plan

Completed in this change: repository/reference audit, 94-route mapping, preserved native auth, live catalogue, versioned requirements for all eight service families, Customer draft CRUD with ownership and role guards, Admin-managed server quotes, responsive Home repairs, automated checks and Customer debug APK.

Remaining sequence:

1. Configure and activate actual service catalogue entries using the existing Admin APIs. Slugs supported by each form are advertised by booking-schemas; no demo pricing is seeded.
2. DONE: Admin rules, quote snapshots/expiry and input-change invalidation. Configure real rules; advanced multi-field pricing remains optional.
3. Add sandbox provider adapter, signed callback verification, idempotent booking creation/payment and matching state.
4. Add live Customer activities/detail/lifecycle, completion/reviews and repeat booking; connect Partner assignment only as required by the shared lifecycle.
5. Add chat/notifications and authorized media, then support/change/cancel/no-show/rematch/refund flows.
6. Add remaining Customer utility/security screens and optional features behind backend flags.
7. Perform live API E2E, device/safe-area/offline checks and release signing. Partner UI expansion follows Customer work.

Optional demo routes must stay unavailable in release. Full beta remains blocked by missing P0 APIs, not by an analyzer or APK compilation failure.
