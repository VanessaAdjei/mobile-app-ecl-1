# Post-checkout order flow (audit)

## Entry points

| Source | Navigation | Data passed |
|--------|------------|-------------|
| `payment_page.dart` | `Navigator.push` → `PaymentWebView` | `paymentParams`, `purchasedItems`, delivery fields, `deliveryFee`, `discount` |
| `paymentwebview.dart` | On success URL → `PostCheckoutOrderPage.route(...)` | Same as webview widget; `initialTransactionId` = `paymentParams['order_id']` |
| Push / notifications | **Not** post-checkout (Phase 1) | `notifications.dart` → legacy `OrderTrackingPage` with `orderDetails` map |

## Payment success path

1. User completes payment in `PaymentWebView`.
2. `_navigateToConfirmation(success)` pops webview and pushes **`PostCheckoutOrderPage`** (no separate confirmation + “Track order” step).
3. `PostCheckoutOrderPage` creates `OrderTrackingProvider` with `OrderTrackingService.createInitialOrder(...)`.
4. Provider `initialize()` → `checkPaymentStatus()` → on success → `refreshOrder()` + `handleOrderConfirmed()` + 2s tracking poll.

## Layer flow (architecture)

```
PostCheckoutOrderPage (Route)
  → OrderTrackingProvider (Controller)
    → OrderTrackingService (Service)
      → OrderTrackingRepository (Repository)
        → OrderTrackingRemoteDataSource / LocalDataSource (Database)
      → OrderTrackingModel / OrderStatusStep (Model)
```

## Background handoff

If the user leaves while payment is still pending, `PendingPaymentPollingService` continues polling and can surface notifications; on-page polling is owned by `OrderTrackingProvider` while the screen is open.

## Key `paymentParams` fields

- `order_id` — transaction / checkout id used as initial order key
- `amount`, `order_urgent`, payment metadata from checkout

## Related files

- `lib/pages/post_checkout_order_page.dart`
- `lib/providers/order_tracking_provider.dart`
- `lib/services/order_tracking_service.dart`
- `lib/repositories/order_tracking_repository.dart`
- `lib/database/order_tracking/`
