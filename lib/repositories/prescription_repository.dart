import '../database/prescription/prescription_remote_data_source.dart';
import '../models/category_fetch_result.dart';

abstract class PrescriptionRepository {
  Future<CategoryFetchResult> fetchPrescriptions({
    required String authToken,
    Duration timeout,
  });

  Future<CategoryFetchResult> uploadPrescription({
    required String authToken,
    required String filePath,
    String? medFilePath,
    Map<String, String> fields,
    Duration timeout,
  });
}

class PrescriptionRepositoryImpl implements PrescriptionRepository {
  PrescriptionRepositoryImpl([PrescriptionRemoteDataSource? remote])
      : _remote = remote ?? PrescriptionRemoteDataSourceImpl();

  final PrescriptionRemoteDataSource _remote;

  @override
  Future<CategoryFetchResult> fetchPrescriptions({
    required String authToken,
    Duration timeout = const Duration(seconds: 8),
  }) =>
      _remote.fetchPrescriptions(authToken: authToken, timeout: timeout);

  @override
  Future<CategoryFetchResult> uploadPrescription({
    required String authToken,
    required String filePath,
    String? medFilePath,
    Map<String, String> fields = const {},
    Duration timeout = const Duration(seconds: 30),
  }) =>
      _remote.uploadPrescription(
        authToken: authToken,
        filePath: filePath,
        medFilePath: medFilePath,
        fields: fields,
        timeout: timeout,
      );
}
