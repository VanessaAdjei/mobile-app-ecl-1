import '../database/recently_viewed/recently_viewed_local_storage.dart';
import '../models/product_model.dart';

class RecentlyViewedRepository {
  RecentlyViewedRepository({RecentlyViewedLocalStorage? local})
      : _local = local ?? RecentlyViewedLocalStorageImpl();

  final RecentlyViewedLocalStorage _local;

  static const int maxItems = 6;

  Future<void> record(Product product) async {
    final slug = product.urlName.trim();
    if (slug.isEmpty) return;

    final slugKey = slug.toLowerCase();
    final entries = await _local.readAll();
    final encoded = product.toJson();
    entries.removeWhere(
      (e) =>
          (e['url_name']?.toString().trim().toLowerCase() ?? '') == slugKey,
    );
    entries.insert(0, encoded);
    if (entries.length > maxItems) {
      entries.removeRange(maxItems, entries.length);
    }
    await _local.writeAll(entries);
  }

  Future<List<Product>> list({String? excludeUrlName}) async {
    final exclude = excludeUrlName?.trim().toLowerCase() ?? '';
    final entries = await _local.readAll();
    final products = <Product>[];

    for (final entry in entries) {
      try {
        final product = Product.fromJson(entry);
        if (product.urlName.trim().isEmpty) continue;
        if (exclude.isNotEmpty &&
            product.urlName.trim().toLowerCase() == exclude) {
          continue;
        }
        products.add(product);
      } catch (_) {
        continue;
      }
    }
    return products;
  }
}
