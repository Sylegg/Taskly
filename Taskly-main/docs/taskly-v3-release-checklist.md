# Customer V3 readiness

Status: PARTIAL, not Closed Beta Ready. Partner expansion is out of scope for this Customer-first change.

- [x] Original Login/Register code retained.
- [x] 94 reference routes mapped with honest status.
- [x] Catalogue API and eight versioned requirement schemas.
- [x] Server draft save/restore/delete with ownership and Customer role.
- [x] Flutter analyzer, widget/regression tests and Customer APK build verified; see test matrix.
- [x] Admin-configured real server quotes with expiry and version checks.
- [ ] Idempotent booking/payment sandbox.
- [ ] Live matching/lifecycle/chat/support/change/refund APIs.
- [ ] All Customer V3 routes, feature flags and 8 complete booking E2Es.
- [ ] Live server/device tests, two-account workflow and offline recovery.
- [ ] Release signing, operational configuration and production policy review.

Run backend using existing environment configuration and Flyway (V8 adds draft storage; V9 adds Admin rules and quote snapshots). Populate/activate services via existing Admin catalogue APIs and configure pricing using taskly-v3-admin-pricing.md. Empty catalogues intentionally stay empty instead of using demo values.

Android emulator: `flutter run --flavor customer --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1`. A physical device needs a reachable backend address. Release requires HTTPS. Do not copy secrets from the IDE's unrelated .env into source.

APK: `build/app/outputs/flutter-apk/app-customer-debug.apk`. Backend tests: `backend/gradlew.bat test --no-daemon`. Detailed test evidence: `taskly-v3-test-matrix.md`.
