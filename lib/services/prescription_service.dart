import 'dart:async';

import '../database/prescription/prescription_remote_data_source.dart';
import '../models/category_fetch_result.dart';
import '../repositories/prescription_repository.dart';

class PrescriptionService {
  PrescriptionService({PrescriptionRepository? repository})
      : _repository = repository ?? PrescriptionRepositoryImpl();

  final PrescriptionRepository _repository;

  Future<List<Map<String, dynamic>>> fetchPrescriptions({
    required String authToken,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final responseFuture = _repository.fetchPrescriptions(
      authToken: authToken,
      timeout: timeout,
    );
    final result = await responseFuture;

    _rethrowTransportError(result);

    if (result.statusCode == 401) {
      throw Exception('Unable to load prescriptions. Please try again.');
    }
    if (!result.isHttpOk || result.body == null) {
      throw Exception(
        'Unable to connect to the server (${result.statusCode})',
      );
    }

    final prescriptions = prescriptionsFromResponse(result.body!);
    if (prescriptions.isEmpty && result.body!['data'] == null) {
      throw Exception('No prescription data found');
    }
    return prescriptions;
  }

  Future<CategoryFetchResult> uploadPrescription({
    required String authToken,
    required String filePath,
    String? medFilePath,
    Map<String, String> fields = const {},
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _repository.uploadPrescription(
      authToken: authToken,
      filePath: filePath,
      medFilePath: medFilePath,
      fields: fields,
      timeout: timeout,
    );
  }

  bool uploadSucceeded(CategoryFetchResult result) =>
      prescriptionUploadSucceeded(result.body, result.statusCode);

  void _rethrowTransportError(CategoryFetchResult result) {
    final error = result.error;
    if (error != null) throw error;
  }
}
