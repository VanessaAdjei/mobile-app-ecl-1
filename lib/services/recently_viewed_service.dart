import '../models/product_model.dart';
import '../repositories/recently_viewed_repository.dart';

/// Local recently viewed products (no backend).
class RecentlyViewedService {
  RecentlyViewedService({RecentlyViewedRepository? repository})
      : _repository = repository ?? RecentlyViewedRepository();

  final RecentlyViewedRepository _repository;

  Future<void> recordView(Product product) => _repository.record(product);

  Future<List<Product>> getRecent({String? excludeUrlName}) =>
      _repository.list(excludeUrlName: excludeUrlName);

  /// Saves the current product, then returns other recent items for the PDP strip.
  Future<List<Product>> recordAndLoadOthers(Product current) async {
    await recordView(current);
    return getRecent(excludeUrlName: current.urlName);
  }
}
