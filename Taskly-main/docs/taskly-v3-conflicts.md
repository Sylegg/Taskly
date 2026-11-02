# Reference conflicts

| Existing | HTML | Proposed | Decision |
|---|---|---|---|
| Separate Customer/Partner Android flavors | Both modes in one app | Rework role switching | Preserve existing flavors; user asked Customer first; auth unchanged |
| Public catalogue minimum/maximum reference amounts | Fixed demo starting/hour prices | Treat minimum as hourly rate | Display reference amount with no hourly unit; no mobile quote formula |
| Mock repository supplies default catalogue and partners | Demo data shown as active state | Reuse in authenticated Customer | Replace catalogue with API result, clear partner/task seeds and guard unsupported writes |
| No quote/payment/task controller | Demo checkout reports success | Add financial policy from demo | Admin configures real quote rules per user decision; payments/task creation remain unavailable |
| Existing enum route names differ | 94 named route IDs | Replace router | Keep enum/navigation; map aliases and mark missing routes honestly |
| No Git metadata in provided directory | Prompt requires branch/baseline | Create feature branch | Unavailable; no repository history was fabricated |

Admin price configuration is authorized by the user. Settlement, cancellation/refund and legal policies remain NEEDS_APPROVAL before production financial implementation. This change makes no such policy decisions.
