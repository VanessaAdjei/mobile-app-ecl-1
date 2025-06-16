class CartItems {

  static final List<Map<String, dynamic>> _cart = [];

  static void addToCart(String name, double price, String image, int quantity) {
    int index = _cart.indexWhere((item) => item['name'] == name);

    if (index != -1) {

      _cart[index]['quantity'] += quantity;
    } else {
      _cart.add({
        'name': name,
        'price': price,
        'image': image,
        'quantity': quantity,
      });
    }
  }

  static void removeFromCart(String name) {
    _cart.removeWhere((item) => item['name'] == name);
  }


  static void updateQuantity(String name, int newQuantity) {
    int index = _cart.indexWhere((item) => item['name'] == name);

    if (index != -1) {
      if (newQuantity > 0) {
        _cart[index]['quantity'] = newQuantity;
      } else {

        removeFromCart(name);
      }
    }
  }


  static void clearCart() {
    _cart.clear();
  }


  static List<Map<String, dynamic>> getCartItems() {
    return _cart;
  }

  static double getTotalPrice() {
    return _cart.fold(0, (total, item) {
      return total + (item['price'] * item['quantity']);
    });
  }
}