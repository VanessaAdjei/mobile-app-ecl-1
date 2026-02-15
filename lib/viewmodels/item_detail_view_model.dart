import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../services/item_detail_optimization_service.dart';
import '../services/item_detail_service_interface.dart';

/// ViewModel for product detail screen. Holds state and business logic.
/// Testable without Flutter - no BuildContext, no UI.
/// Accepts [ItemDetailServiceInterface] for dependency injection.
class ItemDetailViewModel extends ChangeNotifier {
  ItemDetailViewModel({
    required this.urlName,
    required this.cartProvider,
    ItemDetailServiceInterface? itemDetailService,
  }) : _itemDetailService =
            itemDetailService ?? ItemDetailOptimizationService();

  final String urlName;
  final CartProvider cartProvider;
  final ItemDetailServiceInterface _itemDetailService;

  Product? _product;
  List<Product> _relatedProducts = [];
  List<String> _images = [];
  bool _isLoading = true;
  String? _error;
  int _quantity = 1;
  bool _isDescriptionExpanded = false;
  bool _isAddingToCart = false;

  Product? get product => _product;
  List<Product> get relatedProducts => _relatedProducts;
  List<String> get images => _images;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get quantity => _quantity;
  bool get isDescriptionExpanded => _isDescriptionExpanded;
  bool get isAddingToCart => _isAddingToCart;

  /// Load product, related products, and images.
  Future<void> load({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _itemDetailService.initialize();

      final results = await Future.wait([
        _itemDetailService.getProductDetails(urlName, forceRefresh: forceRefresh),
        _itemDetailService.getRelatedProducts(urlName, forceRefresh: forceRefresh),
        _itemDetailService.getProductImages(urlName, forceRefresh: forceRefresh),
      ]);

      _product = results[0] as Product;
      _relatedProducts = results[1] as List<Product>;
      _images = results[2] as List<String>;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh data (force reload).
  Future<void> refresh() => load(forceRefresh: true);

  /// Add product to cart. Throws on error.
  Future<void> addToCart() async {
    if (_product == null || _isAddingToCart) return;

    _isAddingToCart = true;
    notifyListeners();

    try {
      final cartItem = CartItem(
        id: '',
        productId: _product!.id.toString(),
        name: _product!.name,
        price: double.tryParse(_product!.price) ?? 0.0,
        quantity: _quantity,
        image: _product!.thumbnail,
        batchNo: _product!.batch_no,
        urlName: _product!.urlName,
        totalPrice: (double.tryParse(_product!.price) ?? 0.0) * _quantity,
      );

      await cartProvider.addToCart(cartItem);
    } finally {
      _isAddingToCart = false;
      notifyListeners();
    }
  }

  /// Format add-to-cart error for user display.
  static String formatAddToCartError(String errorMessage) {
    if (errorMessage.contains('out of stock') ||
        errorMessage.contains('unavailable') ||
        errorMessage.contains('only has') ||
        errorMessage.contains('units available') ||
        errorMessage.contains('Unable to verify stock')) {
      return errorMessage
          .replaceAll('Exception: ', '')
          .replaceAll('Error: ', '')
          .trim();
    }
    return 'Error adding item to cart. Please try again.';
  }

  void incrementQuantity() {
    if (_quantity < 99) {
      _quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity() {
    if (_quantity > 1) {
      _quantity--;
      notifyListeners();
    }
  }

  void toggleDescriptionExpanded() {
    _isDescriptionExpanded = !_isDescriptionExpanded;
    notifyListeners();
  }

  /// Check if product is already in cart (by normalized name + batch).
  bool get isProductInCart {
    if (_product == null) return false;
    final productNameNorm = CartProvider.normalizeProductName(_product!.name);
    return cartProvider.cartItems.any((item) =>
        CartProvider.normalizeProductName(item.name) == productNameNorm &&
        item.batchNo == _product!.batch_no);
  }
}
