import 'package:flutter/material.dart';

import '../cache/product_catalog_memory.dart';
import '../config/app_routes.dart';
import '../models/product.dart' as catalog_product;
import '../models/product_model.dart';
import '../pages/itemdetail.dart';
import '../services/product_detail_service.dart';
import 'product_tap_guard.dart';

/// Opens [ItemPage] with detail API warm-up + cache (used from every product list).
class ProductDetailNavigation {
  ProductDetailNavigation._();

  /// [ItemPage] uses [Product] from [product_model]; wishlist/cart use [catalog_product.Product].
  static Product? coerceDetailProduct(dynamic product) {
    if (product == null) return null;
    if (product is Product) return product;
    if (product is catalog_product.Product) {
      final p = product;
      return Product(
        id: p.id,
        name: p.name,
        description: p.description,
        urlName: p.urlName,
        status: p.status,
        price: p.price,
        thumbnail: p.thumbnail,
        quantity: p.quantity,
        category: p.category,
        route: p.route,
        batch_no: p.batchNo,
        otcpom: p.otcpom,
        drug: p.drug,
        wellness: p.wellness,
        selfcare: p.selfcare,
        accessories: p.accessories,
      );
    }
    return null;
  }

  static Product? previewFor({
    required String urlName,
    dynamic product,
    dynamic raw,
  }) {
    final coerced = coerceDetailProduct(product);
    if (coerced != null) return coerced;
    if (urlName.isNotEmpty) {
      final fromCatalog = ProductCatalogMemory.findByUrlName(urlName);
      if (fromCatalog != null) return fromCatalog;
    }
    return _previewFromMap(raw, urlName);
  }

  static Product? _previewFromMap(dynamic raw, String urlName) {
    if (raw is Product) return raw;
    if (raw is! Map) return null;
    final m = _normalizePreviewMap(Map<String, dynamic>.from(raw), urlName);
    try {
      final p = Product.fromJson(m);
      if (p.urlName.isNotEmpty || p.name.isNotEmpty) return p;
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic> _normalizePreviewMap(
    Map<String, dynamic> m,
    String urlName,
  ) {
    final nested = m['product'];
    if (nested is Map) {
      final inner = Map<String, dynamic>.from(nested);
      for (final entry in m.entries) {
        if (entry.key == 'product') continue;
        inner.putIfAbsent(entry.key, () => entry.value);
      }
      m = inner;
    }
    if (urlName.isNotEmpty &&
        (m['url_name'] ?? m['urlname'] ?? '').toString().isEmpty) {
      m['url_name'] = urlName;
    }
    if ((m['thumbnail'] ?? '').toString().isEmpty) {
      final thumb = m['image'] ?? m['product_img'];
      if (thumb != null) m['thumbnail'] = thumb;
    }
    m['price'] ??= m['unit_price'] ?? m['selling_price'] ?? '0';
    m['stock'] ??= m['qty_in_stock'] ?? m['quantity'] ?? '';
    m['description'] ??= '';
    m['status'] ??= '';
    m['batch_no'] ??= '';
    m['category'] ??= '';
    m['route'] ??= '';
    return m;
  }

  static bool resolvePrescribed({Product? preview, bool? explicit}) {
    if (explicit != null) return explicit;
    return preview?.otcpom?.toLowerCase() == 'pom';
  }

  static Map<String, dynamic> routeArguments({
    required String urlName,
    dynamic product,
    dynamic raw,
    bool? isPrescribed,
    bool fromProductCard = false,
  }) {
    ProductDetailService.warmProductDetails(urlName);
    final preview = previewFor(urlName: urlName, product: product, raw: raw);
    return {
      'urlName': urlName,
      'isPrescribed': resolvePrescribed(preview: preview, explicit: isPrescribed),
      'fromProductCard': fromProductCard,
    };
  }

  static String _resolveUrlName(
    String urlName, {
    dynamic product,
    dynamic raw,
  }) {
    final trimmed = urlName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final preview = previewFor(urlName: '', product: product, raw: raw);
    return preview?.urlName.trim() ?? '';
  }

  static bool _prepareOpenFromCard({
    required String urlName,
    dynamic product,
    dynamic raw,
  }) {
    final resolved = _resolveUrlName(urlName, product: product, raw: raw);
    final preview = previewFor(urlName: resolved, product: product, raw: raw);
    final key = ProductTapGuard.openKey(
      urlName: resolved,
      productId: preview?.id.toString(),
    );
    if (!ProductTapGuard.canOpen(key)) return false;
    ProductTapGuard.recordOpen(key);
    ProductTapGuard.hapticOnOpen();
    return true;
  }

  static ItemPage itemPage({
    required String urlName,
    dynamic product,
    dynamic raw,
    bool? isPrescribed,
    bool fromProductCard = false,
  }) {
    if (urlName.trim().isEmpty) {
      return ItemPage(
        urlName: urlName,
        isPrescribed: isPrescribed ?? false,
        fromProductCard: fromProductCard,
      );
    }
    ProductDetailService.warmProductDetails(urlName);
    final preview = previewFor(urlName: urlName, product: product, raw: raw);
    return ItemPage(
      urlName: urlName,
      isPrescribed: resolvePrescribed(preview: preview, explicit: isPrescribed),
      fromProductCard: fromProductCard,
    );
  }

  static Future<T?> pushNamed<T>(
    BuildContext context, {
    required String urlName,
    dynamic product,
    dynamic raw,
    bool? isPrescribed,
    bool fromProductCard = false,
  }) {
    final resolved = _resolveUrlName(urlName, product: product, raw: raw);
    if (resolved.isEmpty) return Future.value();
    if (fromProductCard &&
        !_prepareOpenFromCard(
          urlName: resolved,
          product: product,
          raw: raw,
        )) {
      return Future.value();
    }
    return Navigator.pushNamed<T>(
      context,
      AppRoutes.itemDetail,
      arguments: routeArguments(
        urlName: resolved,
        product: product,
        raw: raw,
        isPrescribed: isPrescribed,
        fromProductCard: fromProductCard,
      ),
    );
  }

  static Future<T?> push<T>(
    BuildContext context, {
    required String urlName,
    dynamic product,
    dynamic raw,
    bool? isPrescribed,
    bool fromProductCard = false,
  }) {
    final resolved = _resolveUrlName(urlName, product: product, raw: raw);
    if (resolved.isEmpty) return Future.value();
    if (fromProductCard &&
        !_prepareOpenFromCard(
          urlName: resolved,
          product: product,
          raw: raw,
        )) {
      return Future.value();
    }
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => itemPage(
          urlName: resolved,
          product: product,
          raw: raw,
          isPrescribed: isPrescribed,
          fromProductCard: fromProductCard,
        ),
      ),
    );
  }
}
