# Order tracking rollout boundary

## Phase 1 (shipped scope)

**In scope**

- Post-payment destination: **`PostCheckoutOrderPage`** only (via `PaymentWebView`).
- Unified UI: map + bottom sheet, status hero, ETA tiles, timeline, courier placeholder, OTP when out for delivery.
- Architecture: Provider → Service → Repository → Database.
- Notifications: order placed / confirmed / delivered via `OrderNotificationService` + push refresh callback.
- Purchases / history: **unchanged** — still use `OrderTrackingPage` from notifications list.

**Out of scope (Phase 1)**

- Replacing `OrderTrackingPage` for notification taps.
- Server-driven live rider coordinates (placeholder / geocoded delivery point only).
- Consolidating `BackgroundOrderChecker` with on-page polling.

## Phase 2 (follow-up)

- Point notifications and purchase history to shared post-checkout or a thin wrapper around the same provider.
- Backend courier + live location fields (see `ORDER_TRACKING_BACKEND_CONTRACT.md`).
- `LiveTrackingPlaceholderCard` / map rider marker when coords exist.
- Optional SSE/WebSocket in `OrderTrackingRepository`.

## Legacy

- `order_confirmation_page.dart` — reference only; not used in checkout path.
- `order_tracking_page.dart` — notification / history track screen until migrated.
