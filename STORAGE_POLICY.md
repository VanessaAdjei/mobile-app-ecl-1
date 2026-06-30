# On-device storage policy

What the ECL mobile app saves on the phone, where it lives, and what gets cleared on **logout** vs **uninstall**.

Implementation: `lib/database/local_storage/storage_keys.dart` and `local_storage_cleanup.dart`.  
Logout calls `LocalStorageCleanup.clearOnLogout()` from `AuthService.logout()` after secure storage is wiped.

---

## Storage tiers

| Tier | Technology | Purpose |
|------|------------|---------|
| **Secure** | `FlutterSecureStorage` (+ `secure_*` SharedPreferences fallback) | Auth token only |
| **Session** | SharedPreferences | Account-linked data; cleared on logout |
| **Device** | SharedPreferences | Legal, theme, onboarding, notification prefs; kept on logout |
| **Cache** | SharedPreferences + in-memory | Catalog, banners, stores; public data; kept on logout |
| **Server** | API | Cart totals, stock, prices, payments — **source of truth** |

Never store on device: passwords, full card numbers, CVV, or raw auth tokens in logs.

---

## Secure storage (logout: **clear all**)

| Key | Content |
|-----|---------|
| `auth_token` | Bearer token |

Fallback keys `secure_<name>` in SharedPreferences are also removed on logout.

---

## Session data (logout: **clear**)

| Key | Content |
|-----|---------|
| `user_data` | Cached user JSON from login |
| `user_id` | Account id |
| `hashed_link` | Server checkout link for logged-in cart |
| `loggedInUser`, `isLoggedIn`, `userName`, `userEmail`, `userPhoneNumber` | Legacy session fields |
| `users` | Legacy multi-user blob |
| `pending_guest_cart_id` | Stashed guest id for cart merge after login |
| `profile_image`, `profile_image_path` | Local avatar path |
| `user_profile` | Cached profile snapshot (`app_state_service`) |
| `local_cart` | Last cart snapshot |
| `user_orders` | Cached order list for background checks |
| `order_notifications` | In-app notification list |
| `unread_notification_count` | Badge count |
| `pending_payment_check_active` | Active payment poll id |
| `wishlist_items` | Local wishlist cache |
| `wallet_cache`, `transactions_cache` | Wallet UI cache |
| `prescription_submission_dates_v1` | Rx upload date hints |
| `guest_checkout_draft_v1` | Guest delivery/payment draft |
| `guest_info_collected` | Guest checkout progress flag |
| `user_data_cache`, `cart_cache`, `notifications_cache` (+ `*_time`) | Session optimization caches |
| `favorites`, `recent_searches`, `notifications`, `cart_item_count` | App state extras |

### Dynamic session keys (prefix match on logout)

| Prefix | Example | Content |
|--------|---------|---------|
| `order_total_` | `order_total_123` | Cached order amount |
| `order_stage_ts_` | `order_stage_ts_#4521` | Tracking timeline timestamps |
| `order_highest_tl_idx_` | … | Timeline monotonic index |
| `order_status_hint_` | … | Last known status hint |
| `guest_recent_order_v1_` | `guest_recent_order_v1_<guest_id>` | Guest order snapshot |

---

## Device / legal (logout: **keep**)

| Key | Content |
|-----|---------|
| `themeChoice`, `darkMode` | Light / dark theme |
| `terms_accepted`, `terms_accepted_date` | Legal acceptance |
| `hasLaunchedBefore`, `just_finished_onboarding`, `has_shown_welcome_message` | Onboarding |
| `request_permissions_after_onboarding` | Permission prompt gate |
| `has_seen_smart_tips`, `has_seen_profile_tour`, `has_seen_brand_launch_splash` | Coach marks |
| `has_seen_item_detail_rx_hint` | Rx hint on product detail |
| `push_notifications_opt_in`, `notification_prompt_attempted` | Push prefs |
| `app_install_date`, `app_was_running` | Install / crash recovery |
| `guest_id` | Anonymous session id (continues after logout) |

---

## Catalog caches (logout: **keep**; optional manual clear)

| Key / area | TTL (typical) | Content |
|------------|---------------|---------|
| `cached_all_products`, `cached_popular_products`, `last_cache_time` | Hours | Product catalog |
| `product_detail_v1_*`, `product_detail_ts_v1_*` | ~24h | Product detail pages |
| `banner_cache`, `banner_cache_time` | Hours | Home banners |
| `store_selection_*_v1`, `cached_store_data` | 4–12h | Store locator |
| `homepage_*_cache`, `categories_cache`, `products_cache` | Hours | Home / categories |
| `prefetch_cache` | Short | Cold-start prefetch |
| `perf_cache_*` | Varies | Performance layer |

Use `LocalStorageCleanup.clearReplaceableCaches()` to wipe catalog caches without signing the user out.

---

## Browse UX (logout: **keep**)

| Key | Content |
|-----|---------|
| `recently_viewed_products_v1` | Product browse history on this device |

---

## Uninstall

Removing the app deletes **all** of the above (secure storage, SharedPreferences, temp files). No separate uninstall hook is required on iOS/Android.

---

## Rules of thumb

1. **Prices, stock, cart totals** — always refresh from server before checkout/payment.
2. **Logout** — clear session + secure; keep theme, terms, onboarding, `guest_id`, catalog caches.
3. **New prefs keys** — add to `StorageKeys` and document whether they belong in `logoutExactKeys`, `keepOnLogoutKeys`, or a prefix list.
4. **Prescription images** — keep only until upload succeeds; do not retain in prefs long-term.

---

## Related files

| File | Role |
|------|------|
| `lib/services/auth_service.dart` | Secure token + `logout()` |
| `lib/database/theme/theme_local_storage.dart` | Theme (kept) |
| `lib/services/order_notification_service.dart` | Order notifications (cleared on logout) |
| `lib/services/background_store_data_service.dart` | Store locator cache (kept) |
| `lib/cache/product_cache.dart` | Product catalog cache (kept) |
