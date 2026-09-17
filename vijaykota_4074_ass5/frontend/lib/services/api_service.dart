import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_config.dart';

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final String? errorCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errorCode,
  });
}

class ApiService {
  static String? _authToken;
  static String? _mockRole;

  static void setAuthToken(String? token) {
    _authToken = token;
  }

  static void setMockRole(String? role) {
    _mockRole = role;
  }

  static Future<Map<String, String>> _getHeaders() async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    } else {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (_mockRole != null) {
      headers['x-mock-role'] = _mockRole!;
    }

    return headers;
  }

  static Future<ApiResponse<dynamic>> get(String endpoint) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error or backend unreachable: $e',
        errorCode: 'NETWORK_ERROR',
      );
    }
  }

  static Future<ApiResponse<dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final headers = await _getHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error or backend unreachable: $e',
        errorCode: 'NETWORK_ERROR',
      );
    }
  }

  static Future<ApiResponse<dynamic>> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final headers = await _getHeaders();
      final response = await http.put(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error or backend unreachable: $e',
        errorCode: 'NETWORK_ERROR',
      );
    }
  }

  static Future<ApiResponse<dynamic>> delete(String endpoint) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final headers = await _getHeaders();
      final response = await http.delete(url, headers: headers);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error or backend unreachable: $e',
        errorCode: 'NETWORK_ERROR',
      );
    }
  }

  /// Uploads a spreadsheet or media file using multipart/form-data
  static Future<ApiResponse<dynamic>> uploadFile(
    String endpoint, {
    required Uint8List fileBytes,
    required String fileName,
    String fieldName = 'file',
    Map<String, String>? extraFields,
  }) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final request = http.MultipartRequest('POST', url);

      // Add auth headers
      final headers = await _getHeaders();
      headers.forEach((k, v) {
        if (k.toLowerCase() != 'content-type') {
          request.headers[k] = v;
        }
      });

      // Add fields
      if (extraFields != null) {
        request.fields.addAll(extraFields);
      }

      // Add file bytes
      final multipartFile = http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'File upload error: $e',
        errorCode: 'UPLOAD_ERROR',
      );
    }
  }

  static ApiResponse<dynamic> _handleResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final bool success = decoded['success'] == true;
      final String message = decoded['message'] ?? (success ? 'Success' : 'An error occurred');
      final dynamic data = decoded['data'];
      final String? errorCode = decoded['errorCode'];

      return ApiResponse(
        success: success,
        message: message,
        data: data,
        errorCode: errorCode,
      );
    } catch (_) {
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      return ApiResponse(
        success: isSuccess,
        message: isSuccess ? 'Request completed' : 'Server responded with status code: ${response.statusCode}',
        errorCode: 'HTTP_${response.statusCode}',
      );
    }
  }
}
