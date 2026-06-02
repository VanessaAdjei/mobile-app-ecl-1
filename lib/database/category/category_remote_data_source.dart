import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/http_client_service.dart';

abstract class CategoryRemoteDataSource {
  Future<CategoryFetchResult> fetchTopCategories({
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> fetchAllProducts({
    Duration timeout = const Duration(seconds: 15),
  });

  Future<CategoryFetchResult> fetchCategorySubcategories(
    int categoryId, {
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> fetchSubcategoryProducts(
    int subcategoryId, {
    Duration timeout = const Duration(seconds: 15),
  });

  Future<CategoryFetchResult> searchProducts(
    String query, {
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> fetchProductById(
    int productId, {
    Duration timeout = const Duration(seconds: 8),
  });
}

class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  CategoryRemoteDataSourceImpl();

  Future<CategoryFetchResult> _get(Uri uri, Duration timeout) async {
    try {
      final response =
          await HttpClientService.get(uri).timeout(timeout);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  @override
  Future<CategoryFetchResult> fetchTopCategories({
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.topCategories)),
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> fetchAllProducts({
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _get(
      Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.getAllProducts)),
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> fetchCategorySubcategories(
    int categoryId, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(
      Uri.parse(ApiConfig.getCategoryProductsUrl(categoryId.toString())),
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> fetchSubcategoryProducts(
    int subcategoryId, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _get(
      Uri.parse(
        ApiConfig.getSubcategoryProductsUrl(subcategoryId.toString()),
      ),
      timeout,
    );
  }

  @override
  Future<CategoryFetchResult> searchProducts(
    String query, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(Uri.parse(ApiConfig.getSearchUrl(query)), timeout);
  }

  @override
  Future<CategoryFetchResult> fetchProductById(
    int productId, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _get(
      Uri.parse(ApiConfig.getProductByIdUrl(productId.toString())),
      timeout,
    );
  }
}
