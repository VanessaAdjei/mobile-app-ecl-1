import 'package:flutter/material.dart';

import '../config/app_routes.dart';
import 'bottomnav.dart';
import 'cart.dart';
import 'categories.dart';
import 'homepage.dart';
import 'profile.dart';

/// Root shell that keeps Home, Cart, Categories, and Profile alive in an
/// [IndexedStack] so switching tabs does not recreate [HomePage].
class MainTabShell extends StatefulWidget {
  const MainTabShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  static final GlobalKey<MainTabShellState> navigatorKey =
      GlobalKey<MainTabShellState>();

  /// Switches the visible tab when [MainTabShell] is already under [context].
  static bool switchToTab(BuildContext context, int index) {
    final shell = navigatorKey.currentState ??
        context.findAncestorStateOfType<MainTabShellState>();
    if (shell == null) return false;
    shell.selectTab(index);
    return true;
  }

  /// Opens a main tab without recreating [HomePage] when the shell is active.
  static void goToTab(BuildContext context, int index) {
    if (switchToTab(context, index)) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    final route = switch (index) {
      0 => AppRoutes.home,
      1 => AppRoutes.cart,
      3 => AppRoutes.categoryPage,
      4 => AppRoutes.profile,
      _ => AppRoutes.home,
    };
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  @override
  State<MainTabShell> createState() => MainTabShellState();
}

class MainTabShellState extends State<MainTabShell> {
  static const int _tabCount = 5;

  late int _selectedIndex;
  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();

  /// Shared with [HomePage] tour + shell [CustomBottomNav] (Shop tab, + menu).
  final GlobalKey shellTourMenuKey = GlobalKey();
  final GlobalKey shellTourShopKey = GlobalKey();

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _tabCount - 1);
    _tabs = [
      HomePage(
        key: _homeKey,
        showBottomNav: false,
        tourMenuKey: shellTourMenuKey,
        tourShopKey: shellTourShopKey,
      ),
      const Cart(),
      const SizedBox.shrink(),
      const CategoryPage(showBottomNav: false),
      const Profile(showBottomNav: false),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void selectTab(int index) {
    if (index < 0 || index >= _tabCount) return;
    if (index == 2) return;
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onTabSelected: selectTab,
        tourMenuKey: shellTourMenuKey,
        tourShopKey: shellTourShopKey,
      ),
    );
  }
}
