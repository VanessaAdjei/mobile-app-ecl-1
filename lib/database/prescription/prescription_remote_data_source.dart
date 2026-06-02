import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/category_fetch_result.dart';
import '../../services/http_client_service.dart';

abstract class PrescriptionRemoteDataSource {
  Future<CategoryFetchResult> fetchPrescriptions({
    required String authToken,
    Duration timeout = const Duration(seconds: 8),
  });

  Future<CategoryFetchResult> uploadPrescription({
    required String authToken,
    required String filePath,
    String? medFilePath,
    Map<String, String> fields = const {},
    Duration timeout = const Duration(seconds: 30),
  });
}

class PrescriptionRemoteDataSourceImpl implements PrescriptionRemoteDataSource {
  @override
  Future<CategoryFetchResult> fetchPrescriptions({
    required String authToken,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final response = await HttpClientService.post(
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.viewPrescription)),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }

  @override
  Future<CategoryFetchResult> uploadPrescription({
    required String authToken,
    required String filePath,
    String? medFilePath,
    Map<String, String> fields = const {},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.getEndpointUrl(ApiConfig.createPrescription)),
      );
      request.headers['Authorization'] = 'Bearer $authToken';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      if (medFilePath != null && medFilePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('med_file', medFilePath),
        );
      }

      final streamed = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      return CategoryFetchResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } catch (e) {
      return CategoryFetchResult(statusCode: 0, error: e);
    }
  }
}

/// Parses prescription list from view-prescription API body.
List<Map<String, dynamic>> prescriptionsFromResponse(
  Map<String, dynamic> body,
) {
  final data = body['data'];
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

bool prescriptionUploadSucceeded(
  Map<String, dynamic>? body,
  int statusCode,
) {
  if (statusCode != 200 && statusCode != 201) return false;
  if (body == null) return true;
  final status = body['status']?.toString().toLowerCase();
  if (status == 'success') return true;
  if (body['success'] == true) return true;
  return statusCode == 200 || statusCode == 201;
}
