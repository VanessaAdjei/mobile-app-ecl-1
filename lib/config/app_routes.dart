import 'package:flutter/material.dart';
import '../pages/aboutus.dart';
import '../pages/cart.dart';
import '../pages/categories.dart';
import '../pages/homepage.dart';
import '../pages/itemdetail.dart';
import '../pages/notifications.dart';
import '../pages/pharmacists.dart';
import '../pages/prescription_history.dart';
import '../pages/profile.dart';
import '../pages/profilescreen.dart';
import '../pages/purchases.dart';
import '../pages/refill_page.dart';
import '../pages/return_policy_page.dart';
import '../pages/signinpage.dart';
import '../pages/storelocation.dart';
import '../pages/terms_and_conditions_page.dart';
import '../pages/wallet_page.dart';
import '../pages/wishlist_page.dart';
import '../pages/delivery_page.dart';
import '../pages/prescription_upload_standalone.dart';

/// Central route name constants. Use these for Navigator.pushNamed.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String cart = '/cart';
  static const String profile = '/profile';
  static const String wallet = '/wallet';
  static const String wishlist = '/wishlist';
  static const String itemDetail = '/item-detail';
  static const String categoryPage = '/categories';
  static const String storeSelection = '/store-selection';
  static const String notifications = '/notifications';
  static const String pharmacists = '/pharmacists';
  static const String refill = '/refill';
  static const String delivery = '/delivery';
  static const String signIn = '/sign-in';
  static const String profileScreen = '/profile-screen';
  static const String prescriptionHistory = '/prescription-history';
  static const String prescriptionUpload = '/prescription-upload';
  static const String purchases = '/purchases';
  static const String aboutUs = '/about-us';
  static const String termsAndConditions = '/terms-and-conditions';
  static const String returnPolicy = '/return-policy';
}

/// Generates routes with arguments. Use with MaterialApp.onGenerateRoute.
class AppRouteGenerator {
  static Route<dynamic>? generate(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case AppRoutes.cart:
        return MaterialPageRoute(builder: (_) => const Cart());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => Profile());
      case AppRoutes.wallet:
        return MaterialPageRoute(builder: (_) => WalletPage());
      case AppRoutes.wishlist:
        return MaterialPageRoute(builder: (_) => const WishlistPage());
      case AppRoutes.itemDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        final urlName = args?['urlName'] as String? ?? '';
        final isPrescribed = args?['isPrescribed'] as bool? ?? false;
        return MaterialPageRoute(
          builder: (_) => ItemPage(
            urlName: urlName,
            isPrescribed: isPrescribed,
          ),
        );
      case AppRoutes.categoryPage:
        final args = settings.arguments as Map<String, dynamic>?;
        final isBulkPurchase = args?['isBulkPurchase'] as bool? ?? false;
        return MaterialPageRoute(
          builder: (_) => CategoryPage(isBulkPurchase: isBulkPurchase),
        );
      case AppRoutes.storeSelection:
        return MaterialPageRoute(
          builder: (_) => const StoreSelectionPage(),
        );
      case AppRoutes.notifications:
        final args = settings.arguments as Map<String, dynamic>?;
        final scrollToTop = args?['scrollToTop'] as bool? ?? false;
        return MaterialPageRoute(
          builder: (_) => NotificationsScreen(scrollToTop: scrollToTop),
        );
      case AppRoutes.pharmacists:
        return MaterialPageRoute(
          builder: (_) => const PharmacistsPage(),
        );
      case AppRoutes.refill:
        return MaterialPageRoute(builder: (_) => const RefillPage());
      case AppRoutes.delivery:
        return MaterialPageRoute(builder: (_) => const DeliveryPage());
      case AppRoutes.signIn:
        final args = settings.arguments as Map<String, dynamic>?;
        final returnTo = args?['returnTo'] as String?;
        return MaterialPageRoute(
          builder: (_) => SignInScreen(returnTo: returnTo),
        );
      case AppRoutes.profileScreen:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case AppRoutes.prescriptionHistory:
        return MaterialPageRoute(
          builder: (_) => const PrescriptionHistoryScreen(),
        );
      case AppRoutes.prescriptionUpload:
        return MaterialPageRoute(
          builder: (_) => const PrescriptionUploadStandalone(),
        );
      case AppRoutes.purchases:
        return MaterialPageRoute(builder: (_) => const PurchaseScreen());
      case AppRoutes.aboutUs:
        return MaterialPageRoute(builder: (_) => AboutUsScreen());
      case AppRoutes.termsAndConditions:
        return MaterialPageRoute(
            builder: (_) => const TermsAndConditionsPage());
      case AppRoutes.returnPolicy:
        return MaterialPageRoute(builder: (_) => const ReturnPolicyPage());
      default:
        return null;
    }
  }
}
