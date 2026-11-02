# Issues addressed and remaining

Fixed: inherited demo catalogue/pricing and partners in authenticated Customer; unsupported mutations capable of reaching simulation; controller retry-load after an operation failure hiding its original error; FavoritePartnerCard carousel overflow; Home error text obscuring the actual failure; lazy-list layout test finder; explicit service choice versus restored draft; date picker initial value outside its allowed range.

Remaining P0: real payment/post/matching/task lifecycle APIs. Admin quote configuration and snapshot APIs are implemented. Remaining P1: live chat/notifications/support/change/refund and device E2E. Draft persistence is one draft per user and last write wins. Explicit Save is required for cross-screen/app-restart restoration; no continuous autosave is claimed.

Existing release signing uses a debug key and must be configured before release. The accompanying APK is debug. No live payment, production migration run, deployment or physical-device test was performed.
