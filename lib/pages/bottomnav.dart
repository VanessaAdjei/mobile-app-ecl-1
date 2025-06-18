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

    // Also refresh the cart provider's login status
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    await cartProvider.refreshLoginStatus();
  }

  void _onItemTapped(int index) async {
    print('\n=== Bottom Nav Tapped ===');
    print('Selected Index: $index');
    print('Current Index: $_selectedIndex');
    print('Can Pop: ${Navigator.canPop(context)}');
    print('Current Route: ${ModalRoute.of(context)?.settings.name}');

    // Always allow home navigation
    if (index == 0) {
      print('Navigating to Home');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const home.HomePage(),
        ),
        (route) {
          print('Route predicate: ${route.settings.name}');
          return false;
        },
      );
      return;
    }

    // For other navigation items, check if we're already on that page
    if (index == _selectedIndex) {
      print('Same index selected, returning');
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1:
        print('Navigating to Cart');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Cart(),
          ),
        );
        break;
      case 2:
        print('Navigating to Categories');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CategoryPage(),
          ),
        );
        break;
      case 3:
        print('Navigating to Profile');
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
        height: 78,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          elevation: 0,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          iconSize: 20,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart),
                  if (_userLoggedIn && cart.totalItems > 0)
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
              icon: Icon(Icons.category),
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
