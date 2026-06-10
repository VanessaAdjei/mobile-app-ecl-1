import '../database/prescription/prescription_remote_data_source.dart';
import '../database/prescription/prescription_submission_date_local_storage.dart';
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

  Future<Map<String, String>> readLocalSubmissionDates();
  Future<void> saveLocalSubmissionDate(String prescriptionId, DateTime at);
}

class PrescriptionRepositoryImpl implements PrescriptionRepository {
  PrescriptionRepositoryImpl([
    PrescriptionRemoteDataSource? remote,
    PrescriptionSubmissionDateLocalStorage? localDates,
  ])  : _remote = remote ?? PrescriptionRemoteDataSourceImpl(),
        _localDates =
            localDates ?? PrescriptionSubmissionDateLocalStorageImpl();

  final PrescriptionRemoteDataSource _remote;
  final PrescriptionSubmissionDateLocalStorage _localDates;

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

  @override
  Future<Map<String, String>> readLocalSubmissionDates() =>
      _localDates.readAll();

  @override
  Future<void> saveLocalSubmissionDate(String prescriptionId, DateTime at) =>
      _localDates.save(prescriptionId, at);
}
