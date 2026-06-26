import '../database/profile/profile_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class ProfileRepository {
  Future<CategoryFetchResult> fetchUserProfile({Duration timeout});
  Future<CategoryFetchResult> getProfile({Duration timeout});
  Future<CategoryFetchResult> updateProfile({
    required Map<String, dynamic> body,
    Duration timeout,
  });
  Future<CategoryFetchResult> changePassword({
    required Map<String, dynamic> body,
    Duration timeout,
  });
  Future<CategoryFetchResult> fetchOrders({Duration timeout});
}

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl([ProfileRemoteDataSource? remote])
      : _remote = remote ?? ProfileRemoteDataSourceImpl();

  final ProfileRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> fetchUserProfile({
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.fetchUserProfile(timeout: timeout);

  @override
  Future<CategoryFetchResult> getProfile({
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.getProfile(timeout: timeout);

  @override
  Future<CategoryFetchResult> updateProfile({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.updateProfile(body: body, timeout: timeout);

  @override
  Future<CategoryFetchResult> changePassword({
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.changePassword(body: body, timeout: timeout);

  @override
  Future<CategoryFetchResult> fetchOrders({
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _remote.fetchOrders(timeout: timeout);
}
