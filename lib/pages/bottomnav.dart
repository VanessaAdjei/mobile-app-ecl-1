// pages/bottomnav.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'cartprovider.dart';
import 'homepage.dart' as home;
import 'categories.dart';
import 'cart.dart';
import 'profile.dart';

class CustomBottomNav extends StatefulWidget {
  final int initialIndex;

  const CustomBottomNav({
    Key? key,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  bool _userLoggedIn = false;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    setState(() {
      _userLoggedIn = loggedIn;
    });

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    await cartProvider.refreshLoginStatus();
  }

  void _onItemTapped(int index) async {
    print('🔍 BOTTOM NAV TAPPED ===');
    print('Index: $index');
    print('Current Index: $_selectedIndex');
    print('Can Pop: ${Navigator.canPop(context)}');
    print('Route Count: ${Navigator.of(context).widget.observers.length}');

    // Only return early if we're actually on the same page AND it's not the home button
    // For home button (index 0), we always want to navigate regardless of current index
    // For cart button (index 1), we also want to allow navigation to go back to cart from other pages
    if (index == _selectedIndex && index != 0 && index != 1) {
      print('🔍 SAME INDEX (NOT HOME OR CART) - RETURNING ===');
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        print('🔍 HOME BUTTON PRESSED ===');
        // For home button, clear the entire navigation stack
        try {
          // First, try to pop all routes until we can't pop anymore
          while (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          // Then push the home page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const home.HomePage(),
            ),
          );
          print('🔍 HOME NAVIGATION COMPLETED ===');
        } catch (e) {
          print('🔍 HOME NAVIGATION ERROR: $e ===');
          // Final fallback: try simple push replacement
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const home.HomePage(),
            ),
          );
        }
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Cart(),
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CategoryPage(),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Profile(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive dimensions
    final navHeight = screenHeight * 0.09; // 9% of screen height
    final iconSize = screenWidth * 0.05; // 5% of screen width
    final fontSize = screenWidth * 0.025; // 2.5% of screen width

    // Ensure minimum and maximum values
    final finalNavHeight = navHeight.clamp(60.0, 85.0);
    final finalIconSize = iconSize.clamp(18.0, 24.0);
    final finalFontSize = fontSize.clamp(8.0, 12.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: SizedBox(
        height: finalNavHeight,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          elevation: 0,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedFontSize: finalFontSize,
          unselectedFontSize: finalFontSize,
          iconSize: finalIconSize,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart),
                  if (cart.totalItems > 0)
                    Positioned(
                      right: -6,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${cart.totalItems}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view),
              label: 'Categories',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
