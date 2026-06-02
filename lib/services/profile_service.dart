import '../models/category_fetch_result.dart';
import '../repositories/profile_repository.dart';

class ProfileService {
  ProfileService({ProfileRepository? repository})
      : _repository = repository ?? ProfileRepositoryImpl();

  final ProfileRepository _repository;

  Future<Map<String, dynamic>> fetchUserProfile() async {
    final result = await _repository.fetchUserProfile();
    _rethrowTransportError(result);
    if (!result.isHttpOk || result.body == null) {
      throw Exception('Failed to load profile');
    }
    return Map<String, dynamic>.from(result.body!);
  }

  Future<List<dynamic>> fetchOrderHistory() async {
    final result = await _repository.fetchOrders();
    _rethrowTransportError(result);
    if (!result.isHttpOk || result.body == null) {
      throw Exception('Failed to load orders');
    }
    return List<dynamic>.from(result.body!['orders'] ?? []);
  }

  void _rethrowTransportError(CategoryFetchResult result) {
    final error = result.error;
    if (error != null) throw error;
  }
}
