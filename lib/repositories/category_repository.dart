import '../database/category/category_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class CategoryRepository {
  Future<CategoryFetchResult> fetchTopCategories({Duration timeout});
  Future<CategoryFetchResult> fetchAllProducts({Duration timeout});
  Future<CategoryFetchResult> fetchCategorySubcategories(
    int categoryId, {
    Duration timeout,
  });
  Future<CategoryFetchResult> fetchSubcategoryProducts(
    int subcategoryId, {
    Duration timeout,
  });
  Future<CategoryFetchResult> searchProducts(
    String query, {
    Duration timeout,
  });
  Future<CategoryFetchResult> fetchProductById(
    int productId, {
    Duration timeout,
  });
}

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl([CategoryRemoteDataSource? remote])
      : _remote = remote ?? CategoryRemoteDataSourceImpl();

  final CategoryRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> fetchTopCategories({
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.fetchTopCategories(timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchAllProducts({
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.fetchAllProducts(timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchCategorySubcategories(
    int categoryId, {
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.fetchCategorySubcategories(categoryId, timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchSubcategoryProducts(
    int subcategoryId, {
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.fetchSubcategoryProducts(subcategoryId, timeout: timeout);

  @override
  Future<CategoryFetchResult> searchProducts(
    String query, {
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.searchProducts(query, timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchProductById(
    int productId, {
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.fetchProductById(productId, timeout: timeout);
}
