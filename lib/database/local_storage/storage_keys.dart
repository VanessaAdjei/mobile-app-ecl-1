/// Canonical SharedPreferences / secure-storage keys used on device.
///
/// See [STORAGE_POLICY.md] for what to keep vs clear on logout.
class StorageKeys {
  StorageKeys._();

  // --- Secure (FlutterSecureStorage + secure_* fallback) ---
  static const authToken = 'auth_token';
  static const userData = 'user_data';
  static const userId = 'user_id';
  static const hashedLink = 'hashed_link';

  // --- Auth session (legacy + prefs) ---
  static const users = 'users';
  static const loggedInUser = 'loggedInUser';
  static const isLoggedIn = 'isLoggedIn';
  static const userName = 'userName';
  static const userEmail = 'userEmail';
  static const userPhoneNumber = 'userPhoneNumber';
  static const pendingGuestCartId = 'pending_guest_cart_id';

  // --- Guest ---
  static const guestId = 'guest_id';
  static const guestCheckoutDraft = 'guest_checkout_draft_v1';
  static const guestInfoCollected = 'guest_info_collected';
  static String guestRecentOrder(String guestId) =>
      'guest_recent_order_v1_$guestId';

  // --- Profile ---
  static const profileImage = 'profile_image';
  static const profileImagePath = 'profile_image_path';
  static const userProfile = 'user_profile';

  // --- Cart ---
  static const localCart = 'local_cart';

  // --- Orders & tracking ---
  static const userOrders = 'user_orders';
  static const orderNotifications = 'order_notifications';
  static const unreadNotificationCount = 'unread_notification_count';
  static const pendingPaymentCheckActive = 'pending_payment_check_active';

  static String orderTotal(String orderId) => 'order_total_$orderId';
  static String orderStageTimestamps(String orderKey) =>
      'order_stage_ts_$orderKey';
  static String orderHighestTimelineIndex(String orderKey) =>
      'order_highest_tl_idx_$orderKey';
  static String orderStatusHint(String orderKey) => 'order_status_hint_$orderKey';

  // --- Wishlist & wallet ---
  static const wishlistItems = 'wishlist_items';
  static const walletCache = 'wallet_cache';
  static const transactionsCache = 'transactions_cache';

  // --- Prescriptions ---
  static const prescriptionSubmissionDates = 'prescription_submission_dates_v1';

  // --- Device / legal (keep on logout) ---
  static const themeChoice = 'themeChoice';
  static const legacyDarkMode = 'darkMode';
  static const termsAccepted = 'terms_accepted';
  static const termsAcceptedDate = 'terms_accepted_date';
  static const hasLaunchedBefore = 'hasLaunchedBefore';
  static const justFinishedOnboarding = 'just_finished_onboarding';
  static const hasShownWelcomeMessage = 'has_shown_welcome_message';
  static const requestPermissionsAfterOnboarding =
      'request_permissions_after_onboarding';
  static const hasSeenSmartTips = 'has_seen_smart_tips';
  static const hasSeenProfileTour = 'has_seen_profile_tour';
  static const hasSeenBrandLaunchSplash = 'has_seen_brand_launch_splash';
  static const hasSeenItemDetailRxHint = 'has_seen_item_detail_rx_hint';
  static const pushNotificationsOptIn = 'push_notifications_opt_in';
  static const notificationPromptAttempted = 'notification_prompt_attempted';
  static const appInstallDate = 'app_install_date';
  static const appWasRunning = 'app_was_running';

  // --- Browse UX (device-level; keep on logout) ---
  static const recentlyViewedProducts = 'recently_viewed_products_v1';

  // --- Catalog caches (public; keep on logout) ---
  static const cachedAllProducts = 'cached_all_products';
  static const cachedPopularProducts = 'cached_popular_products';
  static const lastCacheTime = 'last_cache_time';
  static const bannerCache = 'banner_cache';
  static const bannerCacheTime = 'banner_cache_time';
  static const storeSelectionRegions = 'store_selection_regions_v1';
  static const storeSelectionStores = 'store_selection_stores_v1';
  static const storeSelectionTimestamp = 'store_selection_timestamp_v1';
  static const cachedStoreData = 'cached_store_data';
  static const storeDataTimestamp = 'store_data_timestamp';
  static const homepageProductsCache = 'homepage_products_cache';
  static const categoriesCache = 'categories_cache';
  static const productsCache = 'products_cache';
  static const prefetchCache = 'prefetch_cache';

  // --- Dynamic key prefixes (pattern-based cleanup) ---
  static const productDetailPrefix = 'product_detail_v1_';
  static const productDetailTsPrefix = 'product_detail_ts_v1_';
  static const perfCachePrefix = 'perf_cache_';
  static const secureFallbackPrefix = 'secure_';

  /// Keys removed on [LocalStorageCleanup.clearOnLogout].
  static const logoutExactKeys = [
    userData,
    userId,
    hashedLink,
    users,
    loggedInUser,
    isLoggedIn,
    userName,
    userEmail,
    userPhoneNumber,
    pendingGuestCartId,
    profileImage,
    profileImagePath,
    userProfile,
    localCart,
    userOrders,
    orderNotifications,
    unreadNotificationCount,
    pendingPaymentCheckActive,
    wishlistItems,
    walletCache,
    transactionsCache,
    prescriptionSubmissionDates,
    guestCheckoutDraft,
    guestInfoCollected,
    // Optimization caches tied to signed-in session
    'user_data_cache',
    'user_data_cache_time',
    'cart_cache',
    'cart_cache_time',
    'notifications_cache',
    'notifications_cache_time',
    'favorites',
    'recent_searches',
    'notifications',
    'cart_item_count',
  ];

  static const logoutKeyPrefixes = [
    'order_stage_ts_',
    'order_total_',
    'order_highest_tl_idx_',
    'order_status_hint_',
    'guest_recent_order_v1_',
  ];

  /// Keys intentionally kept after logout (device / legal / catalog).
  static const keepOnLogoutKeys = [
    themeChoice,
    legacyDarkMode,
    termsAccepted,
    termsAcceptedDate,
    hasLaunchedBefore,
    justFinishedOnboarding,
    hasShownWelcomeMessage,
    requestPermissionsAfterOnboarding,
    hasSeenSmartTips,
    hasSeenProfileTour,
    hasSeenBrandLaunchSplash,
    hasSeenItemDetailRxHint,
    pushNotificationsOptIn,
    notificationPromptAttempted,
    appInstallDate,
    appWasRunning,
    guestId,
    recentlyViewedProducts,
    cachedAllProducts,
    cachedPopularProducts,
    lastCacheTime,
    bannerCache,
    bannerCacheTime,
    storeSelectionRegions,
    storeSelectionStores,
    storeSelectionTimestamp,
    cachedStoreData,
    storeDataTimestamp,
    homepageProductsCache,
    categoriesCache,
    productsCache,
    prefetchCache,
  ];
}
