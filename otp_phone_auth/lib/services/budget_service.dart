import '../config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_client.dart';
import '../utils/app_logger.dart';

class BudgetService {
  static final BudgetService _instance = BudgetService._internal();
  factory BudgetService() => _instance;
  BudgetService._internal();

  final _authService = AuthService();
  static String get baseUrl => AppConfig.baseUrl;

  /// Set budget for a site
  Future<Map<String, dynamic>?> setBudget(String siteId, double budgetAmount) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        AppLogger.d('No token found');
        return null;
      }

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/admin/sites/budget/set/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'site_id': siteId,
          'budget_amount': budgetAmount,
        }),
      );

      AppLogger.d('Set budget response: ${response.statusCode}');
      AppLogger.d('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        AppLogger.d('Error setting budget: ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.d('Error in setBudget: $e');
      return null;
    }
  }

  /// Get budget for a specific site
  Future<Map<String, dynamic>?> getSiteBudget(String siteId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        AppLogger.d('No token found');
        return null;
      }

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/admin/sites/$siteId/budget/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      AppLogger.d('Get budget response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['budget'];
      } else if (response.statusCode == 404) {
        AppLogger.d('No budget found for site');
        return null;
      } else {
        AppLogger.d('Error getting budget: ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.d('Error in getSiteBudget: $e');
      return null;
    }
  }

  /// Get budget utilization for a site
  Future<Map<String, dynamic>?> getBudgetUtilization(String siteId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        AppLogger.d('No token found');
        return null;
      }

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/admin/sites/$siteId/budget/utilization/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      AppLogger.d('Get utilization response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        AppLogger.d('Error getting utilization: ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.d('Error in getBudgetUtilization: $e');
      return null;
    }
  }

  /// Get budgets for all sites
  Future<List<Map<String, dynamic>>> getAllSitesBudgets() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        AppLogger.d('No token found');
        return [];
      }

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/admin/budgets/all/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      AppLogger.d('Get all budgets response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['budgets'] ?? []);
      } else {
        AppLogger.d('Error getting all budgets: ${response.body}');
        return [];
      }
    } catch (e) {
      AppLogger.d('Error in getAllSitesBudgets: $e');
      return [];
    }
  }

  /// Get real-time updates
  Future<List<Map<String, dynamic>>> getRealTimeUpdates({
    String? lastSync,
    String? siteId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        AppLogger.d('No token found');
        return [];
      }

      var url = '$baseUrl/admin/realtime-updates/';
      final queryParams = <String, String>{};
      
      if (lastSync != null) {
        queryParams['last_sync'] = lastSync;
      }
      if (siteId != null) {
        queryParams['site_id'] = siteId;
      }

      if (queryParams.isNotEmpty) {
        url += '?' + queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      }

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      AppLogger.d('Get updates response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['updates'] ?? []);
      } else {
        AppLogger.d('Error getting updates: ${response.body}');
        return [];
      }
    } catch (e) {
      AppLogger.d('Error in getRealTimeUpdates: $e');
      return [];
    }
  }

  /// Get audit trail for a site
  Future<Map<String, dynamic>?> getAuditTrail(
    String siteId, {
    String? tableName,
    String? changedBy,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        AppLogger.d('No token found');
        return null;
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (tableName != null) queryParams['table_name'] = tableName;
      if (changedBy != null) queryParams['changed_by'] = changedBy;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;

      final url = '$baseUrl/admin/sites/$siteId/audit-trail/?' +
          queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      AppLogger.d('Get audit trail response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        AppLogger.d('Error getting audit trail: ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.d('Error in getAuditTrail: $e');
      return null;
    }
  }
}
