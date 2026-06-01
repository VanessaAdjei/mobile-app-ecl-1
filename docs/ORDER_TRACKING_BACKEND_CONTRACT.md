# Order tracking — backend contract (Phase 2)

Phase 1 ships with existing APIs. This document lists fields/endpoints needed for full Bolt-style live delivery.

## Currently used (Phase 1)

| Endpoint / usage | Purpose |
|------------------|---------|
| `ApiConfig.checkPayment` / payment status | Confirm payment → move to tracking |
| Orders list / order snapshot (via `OrderTrackingRemoteDataSource`) | Refresh status, items, totals |
| Local prefs (`OrderTrackingLocalDataSource`) | Order-placed notification, amount backup |

## Normalized status (client)

`OrderTrackingService.normalizeStage()` maps raw strings to:

`pendingPayment` → `orderPlaced` → `paid` → `pendingConfirmation` → `orderConfirmed` → `outForDelivery` → `delivered` | `failed`

Backend should prefer stable status codes; display labels can vary if mappable.

## Recommended snapshot fields

| Field | Type | UI use |
|-------|------|--------|
| `delivery_id` / `transaction_id` / `order_number` | string | Identity, matching |
| `status` / `order_status` | string | Timeline + hero |
| `order_items` / line items | array | Summary |
| `total_amount`, `delivery_fee`, `discount` | number | Pricing |
| `delivery_address`, `contact_number` | string | ETA tiles, map |
| `estimated_delivery_time` / ETA | string | Hero + tiles |
| `delivery_otp` / `otp` | string | Rider handoff |
| `courier_name`, `courier_phone`, `courier_vehicle` | string | `OrderCourierCard` |
| `courier_lat`, `courier_lng`, `courier_updated_at` | number / ISO | Live map (Phase 2) |
| `store_lat`, `store_lng` | number | Map markers |
| Stage timestamps (`placed_at`, `confirmed_at`, …) | ISO | Timeline subtitles (optional) |

## Realtime (optional)

- WebSocket / SSE channel per active `delivery_id`, or
- Lightweight `GET /orders/{id}/status` polled every 2–5s (current client default)

## Client models

- `OrderTrackingModel` — main UI state
- `CourierTrackingModel` — optional rider payload (`lib/models/courier_tracking_model.dart`)
