# TaskLy Admin Web — Manual Acceptance Checklist

## Development environment

- [ ] `npm install` completes on Node.js 20.9+.
- [ ] `npm run dev` starts; `http://localhost:3000` loads.
- [ ] `npm run build` completes.
- [ ] `npm test` shows 7 passing domain tests.
- [ ] Resize to 1440px, 1024px and 390px; sidebar navigation still works.
- [ ] Original HTML reference opens at `/reference/admin-original.html`.

## Core module navigation (31/31)

Use sidebar to visit each module:

1. Dashboard
2. Live Operations
3. Analytics
4. Customers
5. Partners
6. KYC
7. Trust & Safety
8. Service Catalog
9. Category & Form
10. Pricing & Fees
11. Availability & Areas
12. Tasks
13. Matching Center
14. Recurring Bookings
15. Payments
16. Refund Requests
17. Payouts
18. Ledger
19. Disputes
20. Support Tickets
21. Review Moderation
22. Banner/CMS
23. Voucher
24. Rewards
25. Campaigns
26. Admin Team
27. Access Control
28. Audit Logs
29. Settings & Feature Flags
30. Integrations
31. Data Lab & QA

## End-to-end admin tasks

- [ ] Change role to `ANALYST`; verify editing is blocked.
- [ ] Change back to `SUPER_ADMIN`.
- [ ] KYC: approve pending Partner; confirm Partner KYC state updates.
- [ ] KYC: reject with explanatory note; confirm Partner state updates.
- [ ] Services: create, edit, deactivate; confirm table and audit.
- [ ] Tasks: create a matching task using service, Customer, date, time, location and price.
- [ ] Matching: attempt ineligible Partner, and test eligible assignment.
- [ ] Operations: advance Task through accepted → on the way → arrived → in progress → completed → paid.
- [ ] Payments: find corresponding payment and check RELEASED; ledger should have release entry.
- [ ] Cancellation: cancel eligible task; verify PENDING refund request for HELD payment.
- [ ] Refund: try refund amount larger than payment; should reject; valid refund updates payment/task/ledger.
- [ ] Switch to FINANCE; large refund over threshold should be rejected until SUPER_ADMIN.
- [ ] Payout: approve pending, then mark completed; verify ledger.
- [ ] Disputes: request refund from a case, resolve it.
- [ ] Tickets: assign, edit response, resolve and reopen.
- [ ] Reviews: hide/unhide and report/unreport.
- [ ] Recurring: pause and resume.
- [ ] Banner, Voucher: create/edit and toggle.
- [ ] Campaign: create and send demo.
- [ ] Rewards: adjust points, verify total and audit log.
- [ ] Settings: change refundThreshold, fee and flags; refresh browser, confirm persistence.
- [ ] Data Lab: export JSON/CSV, import Mobile V3 snapshot without duplicate IDs.
- [ ] Data Lab: reset data, verify starting counts restored.

## Mock-only notes

KYC never checks real documents; payment/refund/payout never transfers actual money; campaign never sends emails/push; role checks run only in the browser. These are intended simulations for design review.
