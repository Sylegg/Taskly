# Customer V3 audit — 2026-10-09

The two supplied reference files were found in the workspace parent and copied to `design-reference/`. The additional TEST_AND_INTEGRATION_GUIDE referenced by the master prompt was not supplied. This directory has no Git metadata; creating the requested feature branch and collecting a Git baseline were unavailable. No existing database was reset.

| Area | Before | Current status |
|---|---|---|
| Login/Register | Existing native AuthPage and Session | PROTECTED; not edited |
| App/theme | Existing Flutter, Material 3, ChangeNotifier, enum routes, http | Reused |
| Customer Home | Mint hero, robot, service grid; inherited demo catalogue | PARTIAL: real catalogue and honest unavailable states; responsive card fix |
| Catalogue | Public Spring controller existed; mobile used static mock prices | EXISTS: connected to public/services; reference price is not hourly or a quote |
| Addresses/profile/preferences | Existing authenticated CRUD | EXISTS: reused |
| Dynamic service requirements | Missing | EXISTS: eight versioned server schemas; Flutter fields and validation |
| Booking | Existing seven-step demo flow | PARTIAL: separate five-step authenticated draft flow; save/restore/delete |
| Quotes | Missing | EXISTS: Admin-configured rules, server snapshots and expiry/version validation |
| Payment/post/matching | Demo implementations; task table but no controller | MISSING: guarded unavailable, no fabricated success |
| Chat/notifications/support tickets | Demo UI/data | PARTIAL UI; live endpoints missing |
| Reviews | Account API and task-gated review write exist | PARTIAL: missing live task lifecycle |
| Security/device sessions/account deletion | Logout-all/session refresh exist | PARTIAL; dedicated V3 screens/endpoints missing |
| AI/rewards/vouchers/recurring/maps/media | Prototype or local guidance only | MISSING optional integrations |
| Partner | Existing mock-driven UI and KYC backend | OUT_OF_SCOPE: Customer requested first |

Production customer repositories clear seeded tasks, partners and catalogue. Unsupported task, quote, AI, chat and complaint writes fail rather than invoking inherited simulation. The in-memory snapshot implementation remains shared with the legacy demo harness; a complete repository split is still pending.

This change implements the Customer catalogue, durable booking draft and Admin-managed quote slices. It does not complete the full Customer specification or certify Closed Beta readiness.
