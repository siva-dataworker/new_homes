import '../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_client.dart';
import '../utils/app_logger.dart';

class LaborMismatchService {
  static final LaborMismatchService _instance = LaborMismatchService._internal();
  factory LaborMismatchService() => _instance;
  LaborMismatchService._internal();

  final _authService = AuthService();
  static String get baseUrl => AppConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Content-Type': 'application/json',
    };
  }

  /// Detect labor entry mismatches between Supervisor and Site Engineer
  Future<Map<String, dynamic>> detectLaborMismatches({
    String? siteId,
    int days = 7,
  }) async {
    AppLogger.d('🔍 [MISMATCH SERVICE] detectLaborMismatches called with siteId: $siteId, days: $days');
    try {
      String url = '$baseUrl/construction/labor-mismatches/';
      List<String> params = [];
      
      if (siteId != null && siteId.isNotEmpty) {
        params.add('site_id=$siteId');
      }
      params.add('days=$days');
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      AppLogger.d('🔍 [MISMATCH SERVICE] Calling API: $url');
      
      final response = await ApiClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      AppLogger.d('🔍 [MISMATCH SERVICE] Response status: ${response.statusCode}');
      AppLogger.d('🔍 [MISMATCH SERVICE] Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [MISMATCH SERVICE] Success! Total mismatches: ${data['total_mismatches']}');
        return {
          'success': true,
          'mismatches': List<Map<String, dynamic>>.from(data['mismatches'] ?? []),
          'summary': List<Map<String, dynamic>>.from(data['summary'] ?? []),
          'total_mismatches': data['total_mismatches'] ?? 0,
          'date_range': data['date_range'],
          'message': data['message'],
        };
      } else {
        AppLogger.d('⚠️ [MISMATCH SERVICE] API returned ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to detect labor mismatches',
          'mismatches': [],
          'summary': [],
          'total_mismatches': 0,
        };
      }
    } catch (e) {
      AppLogger.d('❌ [MISMATCH SERVICE] Error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
        'mismatches': [],
        'summary': [],
        'total_mismatches': 0,
      };
    }
  }

  /// Check if a specific site has mismatches
  Future<bool> siteHasMismatches(String siteId) async {
    try {
      final result = await detectLaborMismatches(siteId: siteId, days: 7);
      return result['total_mismatches'] > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get mismatch count for a specific site
  Future<int> getSiteMismatchCount(String siteId) async {
    try {
      final result = await detectLaborMismatches(siteId: siteId, days: 7);
      return result['total_mismatches'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
