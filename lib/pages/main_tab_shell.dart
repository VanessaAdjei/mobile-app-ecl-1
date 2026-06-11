import 'package:flutter/material.dart';

import '../config/app_routes.dart';
import 'bottomnav.dart';
import 'cart.dart';
import 'categories.dart';
import 'homepage.dart';
import 'profile.dart';

/// Root shell that keeps visited tabs alive in an [IndexedStack].
/// [HomePage] is built at launch; Cart, Categories, and Profile mount on first visit.
class MainTabShell extends StatefulWidget {
  const MainTabShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  /// Active shell instance — avoids a shared [GlobalKey] on multiple routes.
  static MainTabShellState? attachedState;

  /// Switches the visible tab when [MainTabShell] is already under [context].
  static bool switchToTab(BuildContext context, int index) {
    final shell = attachedState ??
        context.findAncestorStateOfType<MainTabShellState>();
    if (shell == null) return false;
    shell.selectTab(index);
    return true;
  }

  /// Opens a main tab without recreating [HomePage] when the shell is active.
  static void goToTab(BuildContext context, int index) {
    if (index == 2) return;

    final switched = switchToTab(context, index);
    if (switched) {
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
      return;
    }

    final route = switch (index) {
      0 => AppRoutes.home,
      1 => AppRoutes.cart,
      3 => AppRoutes.categoryPage,
      4 => AppRoutes.profile,
      _ => AppRoutes.home,
    };
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil(route, (route) => false);
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

  final List<Widget?> _tabs = List<Widget?>.filled(_tabCount, null);

  @override
  void initState() {
    super.initState();
    MainTabShell.attachedState = this;
    _selectedIndex = widget.initialIndex.clamp(0, _tabCount - 1);
    _ensureTabBuilt(0);
    if (_selectedIndex != 0) {
      _ensureTabBuilt(_selectedIndex);
    }
  }

  void _ensureTabBuilt(int index) {
    if (index < 0 || index >= _tabCount || index == 2) return;
    if (_tabs[index] != null) return;
    _tabs[index] = _buildTab(index);
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return HomePage(
          key: _homeKey,
          showBottomNav: false,
          tourMenuKey: shellTourMenuKey,
          tourShopKey: shellTourShopKey,
        );
      case 1:
        return const Cart();
      case 2:
        return const SizedBox.shrink();
      case 3:
        return const CategoryPage(showBottomNav: false);
      case 4:
        return const Profile(showBottomNav: false);
      default:
        return const SizedBox.shrink();
    }
  }

  void selectTab(int index) {
    if (index < 0 || index >= _tabCount) return;
    if (index == 2) return;
    if (_selectedIndex == index) return;
    _ensureTabBuilt(index);
    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    if (MainTabShell.attachedState == this) {
      MainTabShell.attachedState = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          _tabCount,
          (index) => _tabs[index] ?? const SizedBox.shrink(),
        ),
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
