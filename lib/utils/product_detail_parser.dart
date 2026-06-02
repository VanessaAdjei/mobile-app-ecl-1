import '../config/api_config.dart';
import '../models/product_model.dart';
import '../utils/product_image_url.dart';

/// Parses product-details API JSON into a [Product].
Product parseProductDetailResponse(
  Map<String, dynamic> data,
  String urlName, {
  Iterable<Product> catalogFallback = const [],
}) {
  if (!data.containsKey('data')) {
    throw Exception('Invalid response format: missing data field');
  }

  final productData = data['data']['product'] ?? {};
  final inventoryData = data['data']['inventory'] ?? {};

  if (productData is! Map || productData.isEmpty ||
      inventoryData is! Map || inventoryData.isEmpty) {
    throw Exception('Product data is incomplete or missing');
  }

  final prodMap = Map<String, dynamic>.from(productData);
  final invMap = Map<String, dynamic>.from(inventoryData);

  final productId = prodMap['product_id'] ??
      prodMap['id'] ??
      invMap['product_id'] ??
      invMap['id'] ??
      invMap['inventory_id'] ??
      0;

  if (productId == 0) {
    throw Exception('Invalid product ID');
  }

  var otcpom = prodMap['otcpom'] ??
      invMap['otcpom'] ??
      prodMap['route'] ??
      invMap['route'] ??
      '';

  if (otcpom.isEmpty) {
    final inventoryUrlName = invMap['url_name']?.toString() ?? '';
    for (final cached in catalogFallback) {
      if (cached.urlName == inventoryUrlName && cached.id != 0) {
        otcpom = cached.otcpom ?? '';
        break;
      }
    }
  }

  final uom = prodMap['uom'] ??
      invMap['uom'] ??
      prodMap['unit_of_measure'] ??
      invMap['unit_of_measure'] ??
      '';

  final tags = <String>[];
  if (prodMap['tags'] is List) {
    tags.addAll(
      (prodMap['tags'] as List).map((tag) => tag.toString()),
    );
  }

  final galleryUrls = galleryUrlsFromProductAndInventory(prodMap, invMap);
  final extractedName = extractProductNameFromUrlSlug(
    invMap['url_name']?.toString() ?? '',
  );

  return Product.fromJson({
    'id': productId,
    'name': extractedName,
    'description': prodMap['description'] ?? '',
    'url_name': invMap['url_name'] ?? '',
    'status': invMap['status'] ?? '',
    'price': invMap['price']?.toString() ?? '0.00',
    'thumbnail': galleryUrls.isNotEmpty ? galleryUrls.first : '',
    'gallery_images': galleryUrls,
    'tags': tags,
    'quantity': invMap['stock']?.toString() ?? '',
    'category': (prodMap['categories'] is List &&
            (prodMap['categories'] as List).isNotEmpty)
        ? (prodMap['categories'] as List).first['description'] ?? ''
        : '',
    'otcpom': otcpom,
    'route': prodMap['route'] ?? '',
    'batch_no': invMap['batch_no'] ?? '',
    'uom': uom,
  });
}

String extractProductNameFromUrlSlug(String urlName) {
  if (urlName.isEmpty) return 'Unknown Product';

  var cleanName = urlName;
  cleanName = cleanName.replaceAll(RegExp(r'-[a-f0-9]{8,}$'), '');
  cleanName = cleanName.replaceAll(RegExp(r'-\d+$'), '');

  return cleanName
      .replaceAll('-', ' ')
      .split(' ')
      .map((word) => word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '')
      .join(' ');
}

/// Extracts product-details slug from a plain slug or full product URL/path.
String? slugFromProductLink(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;

  const marker = 'product-details/';
  final markerIndex = s.toLowerCase().indexOf(marker);
  if (markerIndex >= 0) {
    var slug = s.substring(markerIndex + marker.length);
    final query = slug.indexOf('?');
    if (query >= 0) slug = slug.substring(0, query);
    final hash = slug.indexOf('#');
    if (hash >= 0) slug = slug.substring(0, hash);
    slug = slug.replaceAll(RegExp(r'/+$'), '');
    if (slug.isNotEmpty && !RegExp(r'^\d+$').hasMatch(slug)) return slug;
  }

  if (s.startsWith('http://') || s.startsWith('https://')) return null;
  if (RegExp(r'^\d+$').hasMatch(s)) return null;
  return s;
}

List<String> galleryUrlsFromProductAndInventory(
  Map<String, dynamic> productData,
  Map<String, dynamic> inventoryData,
) {
  final fromList = extractResolvedProductGalleryUrls(
    productData['images'],
    inventoryData,
  );
  if (fromList.isNotEmpty) return fromList;

  final out = <String>[];
  void push(dynamic raw) {
    final coerced = coerceProductImageSource(raw);
    if (coerced.isEmpty) return;
    final url = ApiConfig.getProductImageUrl(coerced);
    if (url.isNotEmpty && !out.contains(url)) out.add(url);
  }

  push(productData['thumbnail']);
  push(productData['image']);
  push(productData['product_img']);
  push(inventoryData['image']);
  push(inventoryData['thumbnail']);
  push(inventoryData['product_img']);
  return orderProductGalleryUrlsForDisplay(out);
}

List<String> extractResolvedProductGalleryUrls(
  dynamic imagesField,
  Map<String, dynamic> inventoryData,
) {
  final out = <String>[];
  void push(dynamic raw) {
    final coerced = coerceProductImageSource(raw);
    if (coerced.isEmpty) return;
    final url = ApiConfig.getProductImageUrl(coerced);
    if (url.isNotEmpty && !out.contains(url)) out.add(url);
  }

  if (imagesField is List) {
    final mapItems = <Map<String, dynamic>>[];
    final otherItems = <dynamic>[];
    for (final item in imagesField) {
      if (item is Map) {
        mapItems.add(Map<String, dynamic>.from(item));
      } else {
        otherItems.add(item);
      }
    }

    bool isPrimary(Map<String, dynamic> m) {
      return m['is_primary'] == true ||
          m['primary'] == true ||
          m['is_default'] == true ||
          m['default'] == true;
    }

    int mapImageId(Map<String, dynamic> m) {
      final v = m['id'] ?? m['image_id'] ?? m['media_id'];
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    mapItems.sort((a, b) {
      final pa = isPrimary(a);
      final pb = isPrimary(b);
      if (pa != pb) return pa ? -1 : 1;
      final ida = mapImageId(a);
      final idb = mapImageId(b);
      if (ida != idb) return idb.compareTo(ida);
      final urlA = (a['url'] ?? a['src'] ?? '').toString();
      final urlB = (b['url'] ?? b['src'] ?? '').toString();
      final ea = uploadEpochFromImageUrl(urlA);
      final eb = uploadEpochFromImageUrl(urlB);
      if (ea != null && eb != null && ea != eb) return eb.compareTo(ea);
      return 0;
    });
    for (final m in mapItems) {
      push(m);
    }
    for (final item in otherItems) {
      push(item);
    }
  }

  if (out.isEmpty) {
    push(inventoryData['image']);
    push(inventoryData['thumbnail']);
    push(inventoryData['product_img']);
  }
  return orderProductGalleryUrlsForDisplay(out);
}

int? uploadEpochFromImageUrl(String url) {
  final m = RegExp(r'_(\d{10,13})_').firstMatch(url);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

bool looksLikePlaceholderImageUrl(String url) {
  final u = url.toLowerCase();
  return u.contains('placeholder') ||
      u.contains('no-image') ||
      u.contains('no_image') ||
      u.contains('default_product') ||
      u.contains('image-not-available') ||
      u.contains('/0.png') ||
      u.contains('/0.jpg');
}

List<String> orderProductGalleryUrlsForDisplay(List<String> urls) {
  if (urls.length < 2) return urls;
  final copy = List<String>.from(urls);
  copy.sort((a, b) {
    final pa = looksLikePlaceholderImageUrl(a);
    final pb = looksLikePlaceholderImageUrl(b);
    if (pa != pb) return pa ? 1 : -1;
    final ea = uploadEpochFromImageUrl(a);
    final eb = uploadEpochFromImageUrl(b);
    if (ea != null && eb != null && ea != eb) return eb.compareTo(ea);
    if (ea != null && eb == null) return -1;
    if (ea == null && eb != null) return 1;
    return 0;
  });
  return copy;
}
