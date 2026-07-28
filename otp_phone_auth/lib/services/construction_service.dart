import '../config/app_config.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'auth_service.dart';
import 'api_client.dart';
import '../utils/app_logger.dart';

class ConstructionService {
  static final ConstructionService _instance = ConstructionService._internal();
  factory ConstructionService() => _instance;
  ConstructionService._internal();

  final _authService = AuthService();
  static String get baseUrl => AppConfig.baseUrl;
  static String get mediaBaseUrl => AppConfig.mediaBaseUrl; // For media files

  // Helper method to convert relative image URLs to full URLs
  static String getFullImageUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) return '';

    // If already a full URL, return as is
    if (relativeUrl.startsWith('http')) return relativeUrl;

    // If relative URL starts with /media/, prepend the media base URL
    if (relativeUrl.startsWith('/media/')) {
      return '$mediaBaseUrl$relativeUrl';
    }

    // If it doesn't start with /, add it
    if (!relativeUrl.startsWith('/')) {
      return '$mediaBaseUrl/media/$relativeUrl';
    }

    return '$mediaBaseUrl$relativeUrl';
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // ============================================
  // PROFILE UPDATE
  // ============================================

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null && fullName.isNotEmpty) body['full_name'] = fullName;
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      final response = await ApiClient.put(
        Uri.parse('$baseUrl/user/profile/update/'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Profile updated',
        };
      }
      return {'success': false, 'error': data['error'] ?? 'Update failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================
  // COMMON APIS
  // ============================================

  Future<List<String>> getAreas() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/areas/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['areas']);
      }
      return [];
    } catch (e) {
      AppLogger.d('Error getting areas: $e');
      return [];
    }
  }

  Future<List<String>> getStreets(String area) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/streets/$area/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['streets']);
      }
      return [];
    } catch (e) {
      AppLogger.d('Error getting streets: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSites({
    String? area,
    String? street,
  }) async {
    try {
      var url = '$baseUrl/construction/sites/';
      final params = <String>[];
      if (area != null) params.add('area=$area');
      if (street != null) params.add('street=$street');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['sites']);
      }
      return [];
    } catch (e) {
      AppLogger.d('Error getting sites: $e');
      return [];
    }
  }

  // ============================================
  // MATERIALS APIS
  // ============================================

  Future<List<Map<String, dynamic>>> getMaterials() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/materials/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d(
          '✅ [MATERIALS] Fetched ${(data['materials'] as List).length} materials',
        );
        return List<Map<String, dynamic>>.from(data['materials']);
      }
      AppLogger.d('❌ [MATERIALS] Error: ${response.statusCode}');
      return [];
    } catch (e) {
      AppLogger.d('❌ [MATERIALS] Exception: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> addMaterial(String materialName) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/materials/add/'),
        headers: await _getHeaders(),
        body: json.encode({'material_name': materialName}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [MATERIALS] Added: $materialName');
        return {'success': true, 'data': data};
      }

      final error = json.decode(response.body);
      AppLogger.d('❌ [MATERIALS] Error adding: ${error['error']}');
      return {'success': false, 'error': error['error']};
    } catch (e) {
      AppLogger.d('❌ [MATERIALS] Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================
  // SUPERVISOR APIS
  // ============================================

  /// Check if entry is locked by another supervisor
  Future<Map<String, dynamic>> checkEntryLock({
    required String siteId,
    String? entryDate, // Optional, defaults to today on backend
  }) async {
    try {
      final params = {'site_id': siteId};
      if (entryDate != null) {
        params['entry_date'] = entryDate;
      }

      final uri = Uri.parse(
        '$baseUrl/construction/check-entry-lock/',
      ).replace(queryParameters: params);

      AppLogger.d(
        '🔍 [ENTRY_LOCK] Checking lock for site: $siteId, date: ${entryDate ?? 'today'}',
      );

      final response = await ApiClient.get(
        uri,
        headers: await _getHeaders(),
        timeout: const Duration(seconds: 10),
      );

      AppLogger.d('📊 [ENTRY_LOCK] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d(
          '✅ [ENTRY_LOCK] Lock check result: is_locked=${data['is_locked']}',
        );
        return {
          'success': true,
          'is_locked': data['is_locked'] ?? false,
          'locked_by': data['locked_by'],
          'locked_at': data['locked_at'],
          'can_enter': data['can_enter'] ?? true,
          'can_view': data['can_view'] ?? false,
          'entries': data['entries'] ?? [],
        };
      }

      AppLogger.d('❌ [ENTRY_LOCK] Failed with status: ${response.statusCode}');
      return {'success': false, 'error': 'Failed to check entry lock'};
    } catch (e) {
      AppLogger.d('❌ [ENTRY_LOCK] Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> submitLabourCount({
    required String siteId,
    required int labourCount,
    String? labourType,
    String? notes,
    double? extraCost,
    String? extraCostNotes,
    DateTime? customDateTime, // Add custom date/time parameter
  }) async {
    AppLogger.d('🔍 [SUBMIT] Submitting labour: $labourType = $labourCount');
    AppLogger.d('🔍 [SUBMIT] Site ID: $siteId');
    AppLogger.d('🔍 [SUBMIT] Custom DateTime: $customDateTime');
    try {
      final headers = await _getHeaders();
      final body = {
        'site_id': siteId,
        'labour_count': labourCount,
        'labour_type': labourType ?? 'General',
        'notes': notes ?? '',
      };

      // Add custom date/time if provided
      if (customDateTime != null) {
        body['custom_date'] = customDateTime.toIso8601String().split(
          'T',
        )[0]; // YYYY-MM-DD
        body['custom_time'] = customDateTime
            .toIso8601String()
            .split('T')[1]
            .split('.')[0]; // HH:MM:SS
        body['custom_datetime'] = customDateTime
            .toIso8601String(); // Full ISO string
      }

      // Add extra cost fields if provided
      if (extraCost != null && extraCost > 0) {
        body['extra_cost'] = extraCost;
        if (extraCostNotes != null && extraCostNotes.isNotEmpty) {
          body['extra_cost_notes'] = extraCostNotes;
        }
      }

      AppLogger.d('🔍 [SUBMIT] Request body: $body');

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/labour/'),
        headers: headers,
        body: json.encode(body),
      );

      AppLogger.d('📊 [SUBMIT] Response status: ${response.statusCode}');
      AppLogger.d('📊 [SUBMIT] Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        AppLogger.d('✅ [SUBMIT] Labour submitted: '
            'date=${data['entry_date']} type=${data['entry_type']} '
            'count=${data['labour_count']}');
        return {
          'success': true,
          'message': data['message'],
          'entry_id': data['entry_id'],
          'entry_date': data['entry_date'],
          'entry_type': data['entry_type'],
          'labour_type': data['labour_type'],
          'labour_count': data['labour_count'],
        };
      } else if (response.statusCode == 423) {
        // Entry locked by another supervisor
        AppLogger.d('🔒 [SUBMIT] Entry locked by: ${data['locked_by']}');
        return {
          'success': false,
          'locked': true,
          'error': data['error'],
          'locked_by': data['locked_by'],
          'locked_at': data['locked_at'],
          'entry_type': data['entry_type'],
        };
      } else if (response.statusCode == 409) {
        // Conflict - duplicate entry
        AppLogger.d('⚠️ [SUBMIT] Conflict: ${data['error']}');
        return {
          'success': false,
          'conflict': true,
          'error': data['error'],
          'can_edit': data['can_edit'] ?? false,
          'retry': data['retry'] ?? false,
        };
      } else {
        AppLogger.d('❌ [SUBMIT] Failed: ${data['error']}');
        return {'success': false, 'error': data['error'] ?? 'Failed to submit'};
      }
    } catch (e) {
      AppLogger.d('❌ [SUBMIT] Exception: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> submitMaterialBalance({
    required String siteId,
    required List<Map<String, dynamic>> materials,
    double? extraCost,
    String? extraCostNotes,
    DateTime? customDateTime, // Add custom date/time parameter
  }) async {
    try {
      final body = {'site_id': siteId, 'materials': materials};

      // Add custom date/time if provided
      if (customDateTime != null) {
        body['custom_date'] = customDateTime.toIso8601String().split(
          'T',
        )[0]; // YYYY-MM-DD
        body['custom_time'] = customDateTime
            .toIso8601String()
            .split('T')[1]
            .split('.')[0]; // HH:MM:SS
        body['custom_datetime'] = customDateTime
            .toIso8601String(); // Full ISO string
      }

      // Add extra cost fields if provided
      if (extraCost != null && extraCost > 0) {
        body['extra_cost'] = extraCost;
        if (extraCostNotes != null && extraCostNotes.isNotEmpty) {
          body['extra_cost_notes'] = extraCostNotes;
        }
      }

      AppLogger.d('🔍 [MATERIAL] Request body: $body');

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/submit-material-balance/'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      AppLogger.d('🔍 [MATERIAL] Response status code: ${response.statusCode}');
      AppLogger.d('🔍 [MATERIAL] Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed to submit'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> submitExtraCost({
    required String siteId,
    required double amount,
    required String description,
    DateTime? entryDate,
  }) async {
    try {
      final headers = await _getHeaders();
      final now = DateTime.now();
      final istNow = now.add(const Duration(hours: 5, minutes: 30));

      final body = {
        'site_id': siteId,
        'amount': amount,
        'description': description,
        'entry_date': (entryDate ?? istNow).toIso8601String().split('T')[0],
        'entry_time': istNow.toIso8601String(),
      };

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/extra-cost/'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.d('✅ [EXTRA_COST] Submitted successfully');
        return {'success': true, 'data': data};
      } else {
        AppLogger.d('❌ [EXTRA_COST] Failed: ${response.body}');
        return {'success': false, 'error': 'Failed to submit extra cost'};
      }
    } catch (e) {
      AppLogger.d('❌ [EXTRA_COST] Exception: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // TEST METHOD - Remove after debugging
  Future<Map<String, dynamic>> testMaterialBalance({
    required String siteId,
    required List<Map<String, dynamic>> materials,
  }) async {
    try {
      final body = {'site_id': siteId, 'materials': materials};
      AppLogger.d('🧪 [TEST] Testing POST to /api/construction/test-material/');
      AppLogger.d('🧪 [TEST] Request body: $body');

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/test-material/'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      AppLogger.d('🧪 [TEST] Response status: ${response.statusCode}');
      AppLogger.d('🧪 [TEST] Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Test failed'};
      }
    } catch (e) {
      AppLogger.d('🧪 [TEST] Exception: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadSiteImages({
    required String siteId,
    required List<String> imageUrls,
    String? description,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/supervisor/upload-images/'),
        headers: await _getHeaders(),
        body: json.encode({
          'site_id': siteId,
          'image_urls': imageUrls,
          'description': description ?? '',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed to upload'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>?> getTodayEntries(String siteId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/supervisor/today-entries/?site_id=$siteId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      AppLogger.d('Error getting today entries: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getEntriesByDate(
    String siteId,
    DateTime date,
  ) async {
    try {
      // Format date as YYYY-MM-DD
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final response = await ApiClient.get(
        Uri.parse(
          '$baseUrl/construction/entries-by-date/?site_id=$siteId&date=$dateStr',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'labour_entries': [], 'material_entries': []};
    } catch (e) {
      AppLogger.d('Error getting entries by date: $e');
      return {'labour_entries': [], 'material_entries': []};
    }
  }

  // ============================================
  // SITE ENGINEER APIS
  // ============================================

  Future<Map<String, dynamic>> uploadWorkStarted({
    required String siteId,
    required String imageUrl,
    String? description,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/engineer/work-started/'),
        headers: await _getHeaders(),
        body: json.encode({
          'site_id': siteId,
          'image_url': imageUrl,
          'description': description ?? '',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed to upload'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadWorkFinished({
    required String siteId,
    required List<String> imageUrls,
    String? description,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/engineer/work-finished/'),
        headers: await _getHeaders(),
        body: json.encode({
          'site_id': siteId,
          'image_urls': imageUrls,
          'description': description ?? '',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed to upload'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getMyComplaints() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/engineer/complaints/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['complaints']);
      }
      return [];
    } catch (e) {
      AppLogger.d('Error getting complaints: $e');
      return [];
    }
  }

  // ============================================
  // ACCOUNTANT APIS
  // ============================================

  Future<List<Map<String, dynamic>>> getLabourEntriesForVerification(
    String date,
  ) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/accountant/labour-entries/?date=$date'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['entries']);
      }
      return [];
    } catch (e) {
      AppLogger.d('Error getting labour entries: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> modifyLabourCount({
    required String entryId,
    required int labourCount,
    required String reason,
  }) async {
    try {
      final response = await ApiClient.put(
        Uri.parse('$baseUrl/accountant/modify-labour/$entryId/'),
        headers: await _getHeaders(),
        body: json.encode({'labour_count': labourCount, 'reason': reason}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed to modify'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadMaterialBill({
    required String siteId,
    required String materialType,
    required double quantity,
    required double totalAmount,
    String? unit,
    double? pricePerUnit,
    String? billNumber,
    String? billUrl,
    String? vendorName,
    String? billDate,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/accountant/upload-bill/'),
        headers: await _getHeaders(),
        body: json.encode({
          'site_id': siteId,
          'material_type': materialType,
          'quantity': quantity,
          'total_amount': totalAmount,
          'unit': unit,
          'price_per_unit': pricePerUnit,
          'bill_number': billNumber,
          'bill_url': billUrl,
          'vendor_name': vendorName,
          'bill_date': billDate,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed to upload'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadExtraWork({
    required String siteId,
    required String description,
    required double amount,
    String? billUrl,
    String? dueDate,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/accountant/extra-work/'),
        headers: await _getHeaders(),
        body: json.encode({
          'site_id': siteId,
          'description': description,
          'amount': amount,
          'bill_url': billUrl,
          'due_date': dueDate,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed to upload'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================
  // HISTORY APIS
  // ============================================

  Future<Map<String, dynamic>> getSupervisorHistory({String? siteId}) async {
    AppLogger.d('🔍 [HISTORY] Calling supervisor history API... (siteId: $siteId)');
    try {
      final headers = await _getHeaders();
      AppLogger.d('🔍 [HISTORY] Headers: ${headers.keys}');

      // Build URL with optional site filter
      String url = '$baseUrl/construction/supervisor/history/';
      if (siteId != null && siteId.isNotEmpty) {
        url += '?site_id=$siteId';
      }

      AppLogger.d('🔍 [HISTORY] URL: $url');

      final response = await ApiClient.get(Uri.parse(url), headers: headers);

      AppLogger.d('📊 [HISTORY] Response status: ${response.statusCode}');
      AppLogger.d('📊 [HISTORY] Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final labourCount = (data['labour_entries'] as List?)?.length ?? 0;
        final materialCount = (data['material_entries'] as List?)?.length ?? 0;
        AppLogger.d('✅ [HISTORY] Labour entries: $labourCount');
        AppLogger.d('✅ [HISTORY] Material entries: $materialCount');
        AppLogger.d('🏗️ [HISTORY] Site filter: ${data['site_filter'] ?? 'None'}');

        if (labourCount > 0) {
          AppLogger.d(
            '📝 [HISTORY] First labour entry: ${data['labour_entries'][0]}',
          );

          // Debug: Check for Jan 26 entries specifically
          final jan26Labour = (data['labour_entries'] as List)
              .where(
                (entry) =>
                    entry['entry_date']?.toString().contains('2026-01-26') ==
                    true,
              )
              .toList();
          AppLogger.d(
            '📅 [HISTORY] Jan 26 labour entries found: ${jan26Labour.length}',
          );

          if (jan26Labour.isNotEmpty) {
            AppLogger.d('📝 [HISTORY] Jan 26 labour sample: ${jan26Labour[0]}');
          }
        }

        if (materialCount > 0) {
          AppLogger.d(
            '📦 [HISTORY] First material entry: ${data['material_entries'][0]}',
          );

          // Debug: Check for Jan 26 entries specifically
          final jan26Material = (data['material_entries'] as List)
              .where(
                (entry) =>
                    entry['entry_date']?.toString().contains('2026-01-26') ==
                    true,
              )
              .toList();
          AppLogger.d(
            '📅 [HISTORY] Jan 26 material entries found: ${jan26Material.length}',
          );

          if (jan26Material.isNotEmpty) {
            AppLogger.d('📦 [HISTORY] Jan 26 material sample: ${jan26Material[0]}');
          }
        }

        return data;
      } else {
        AppLogger.d('❌ [HISTORY] Error response: ${response.body}');
      }
      return {'labour_entries': [], 'material_entries': []};
    } catch (e) {
      AppLogger.d('❌ [HISTORY] Exception: $e');
      return {'labour_entries': [], 'material_entries': []};
    }
  }

  Future<Map<String, dynamic>> getTodayEntriesForSupervisor({
    String? siteId,
  }) async {
    AppLogger.d('🔍 [TODAY] Calling aggregated today entries API...');
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/construction/aggregated-today-entries/';

      if (siteId != null) {
        url += '?site_id=$siteId';
      }

      AppLogger.d('🔍 [TODAY] URL: $url');

      final response = await ApiClient.get(Uri.parse(url), headers: headers);

      AppLogger.d('📊 [TODAY] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [TODAY] Data received: ${data.keys}');
        if (data['entries'] != null) {
          AppLogger.d('✅ [TODAY] Entries count: ${(data['entries'] as List).length}');
          if ((data['entries'] as List).isNotEmpty) {
            AppLogger.d('✅ [TODAY] First entry: ${data['entries'][0]}');
          }
        }
        return data;
      } else {
        AppLogger.d('❌ [TODAY] Error response: ${response.body}');
        throw Exception('Failed to load today\'s entries: ${response.body}');
      }
    } catch (e) {
      AppLogger.d('❌ [TODAY] Exception: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> getHistoryByDay({required String siteId}) async {
    AppLogger.d('🔍 [HISTORY_BY_DAY] Calling history-by-day API for site: $siteId');
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/construction/history-by-day/?site_id=$siteId';

      AppLogger.d('🔍 [HISTORY_BY_DAY] URL: $url');

      final response = await ApiClient.get(Uri.parse(url), headers: headers);

      AppLogger.d('📊 [HISTORY_BY_DAY] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [HISTORY_BY_DAY] Data received successfully');
        return {'success': true, 'data': data};
      } else {
        AppLogger.d('❌ [HISTORY_BY_DAY] Error response: ${response.body}');
        return {'success': false, 'error': 'Failed to load history'};
      }
    } catch (e) {
      AppLogger.d('❌ [HISTORY_BY_DAY] Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAccountantEntries() async {
    AppLogger.d('🔍 [ACCOUNTANT] Calling accountant entries API...');
    try {
      final headers = await _getHeaders();
      AppLogger.d(
        '🔍 [ACCOUNTANT] URL: $baseUrl/construction/accountant/all-entries/',
      );

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/accountant/all-entries/'),
        headers: headers,
      );

      AppLogger.d('📊 [ACCOUNTANT] Response status: ${response.statusCode}');
      AppLogger.d('📊 [ACCOUNTANT] Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final labourCount = (data['labour_entries'] as List?)?.length ?? 0;
        final materialCount = (data['material_entries'] as List?)?.length ?? 0;
        final extraCostsCount = (data['extra_costs'] as List?)?.length ?? 0;
        AppLogger.d('✅ [ACCOUNTANT] Labour entries: $labourCount');
        AppLogger.d('✅ [ACCOUNTANT] Material entries: $materialCount');
        AppLogger.d('✅ [ACCOUNTANT] Extra costs: $extraCostsCount');

        if (labourCount > 0) {
          AppLogger.d(
            '📝 [ACCOUNTANT] First labour entry: ${data['labour_entries'][0]}',
          );
        }

        return data;
      } else {
        AppLogger.d('❌ [ACCOUNTANT] Error response: ${response.body}');
      }
      return {'labour_entries': [], 'material_entries': [], 'extra_costs': []};
    } catch (e) {
      AppLogger.d('❌ [ACCOUNTANT] Exception: $e');
      return {'labour_entries': [], 'material_entries': []};
    }
  }

  Future<Map<String, dynamic>> getAccountantPhotos({
    String? siteId,
    String? updateType,
    String? dateFrom,
    String? dateTo,
  }) async {
    AppLogger.d('🔍 [ACCOUNTANT PHOTOS] Calling accountant photos API...');
    try {
      final headers = await _getHeaders();

      // Build URL with optional filters
      String url = '$baseUrl/construction/accountant/all-photos/';
      List<String> queryParams = [];

      if (siteId != null && siteId.isNotEmpty) {
        queryParams.add('site_id=$siteId');
      }
      if (updateType != null && updateType.isNotEmpty) {
        queryParams.add('update_type=$updateType');
      }
      if (dateFrom != null && dateFrom.isNotEmpty) {
        queryParams.add('date_from=$dateFrom');
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        queryParams.add('date_to=$dateTo');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      AppLogger.d('🔍 [ACCOUNTANT PHOTOS] URL: $url');

      final response = await ApiClient.get(Uri.parse(url), headers: headers);

      AppLogger.d('📊 [ACCOUNTANT PHOTOS] Response status: ${response.statusCode}');
      AppLogger.d(
        '📊 [ACCOUNTANT PHOTOS] Response body length: ${response.body.length}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final photosCount = (data['photos'] as List?)?.length ?? 0;
        AppLogger.d('✅ [ACCOUNTANT PHOTOS] Photos found: $photosCount');

        if (photosCount > 0) {
          AppLogger.d(
            '📸 [ACCOUNTANT PHOTOS] First photo: ${data['photos'][0]['full_site_name']} - ${data['photos'][0]['update_type']}',
          );
        }

        return data;
      } else {
        AppLogger.d('❌ [ACCOUNTANT PHOTOS] Error response: ${response.body}');
      }
      return {'photos': [], 'total_photos': 0};
    } catch (e) {
      AppLogger.d('❌ [ACCOUNTANT PHOTOS] Exception: $e');
      return {'photos': [], 'total_photos': 0};
    }
  }

  // Get supervisor photos for accountant/admin (from site_photos table)
  Future<Map<String, dynamic>> getSupervisorPhotosForAccountant({
    String? siteId,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/construction/supervisor-photos-for-accountant/';
      if (siteId != null) url += '?site_id=$siteId';

      final response = await ApiClient.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      AppLogger.d(
        '❌ [SUPERVISOR PHOTOS] Error: ${response.statusCode} ${response.body}',
      );
      return {'photos': [], 'count': 0};
    } catch (e) {
      AppLogger.d('❌ [SUPERVISOR PHOTOS] Exception: $e');
      return {'photos': [], 'count': 0};
    }
  }

  // ============================================
  // ARCHITECT APIS
  // ============================================

  Future<Map<String, dynamic>> uploadArchitectDocument({
    required String siteId,
    required String documentType,
    required String title,
    String? description,
    required String filePath,
  }) async {
    try {
      final headers = await _getHeaders();
      headers.remove('Content-Type'); // Let http handle multipart content type

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/construction/upload-architect-document/'),
      );

      request.headers.addAll(headers);
      request.fields['site_id'] = siteId;
      request.fields['document_type'] = documentType;
      request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'document_id': data['document_id'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to upload document',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> uploadArchitectComplaint({
    required String siteId,
    required String title,
    required String description,
    String priority = 'MEDIUM',
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/upload-architect-complaint/'),
        headers: await _getHeaders(),
        body: json.encode({
          'site_id': siteId,
          'title': title,
          'description': description,
          'priority': priority,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'complaint_id': data['complaint_id'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to submit complaint',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getArchitectDocuments({
    String? siteId,
    String? documentType,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      // Build URL with optional filters
      String url = '$baseUrl/construction/architect-documents/';
      List<String> queryParams = [];

      if (siteId != null && siteId.isNotEmpty) {
        queryParams.add('site_id=$siteId');
      }
      if (documentType != null && documentType.isNotEmpty) {
        queryParams.add('document_type=$documentType');
      }
      if (dateFrom != null && dateFrom.isNotEmpty) {
        queryParams.add('date_from=$dateFrom');
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        queryParams.add('date_to=$dateTo');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'documents': data['documents'],
          'total_documents': data['total_documents'],
        };
      } else {
        return {'success': false, 'error': 'Failed to load documents'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getArchitectComplaints({
    String? siteId,
    String? status,
    String? priority,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      // Build URL with optional filters
      String url = '$baseUrl/construction/architect-complaints/';
      List<String> queryParams = [];

      if (siteId != null && siteId.isNotEmpty) {
        queryParams.add('site_id=$siteId');
      }
      if (status != null && status.isNotEmpty) {
        queryParams.add('status=$status');
      }
      if (priority != null && priority.isNotEmpty) {
        queryParams.add('priority=$priority');
      }
      if (dateFrom != null && dateFrom.isNotEmpty) {
        queryParams.add('date_from=$dateFrom');
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        queryParams.add('date_to=$dateTo');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'complaints': data['complaints'],
          'total_complaints': data['total_complaints'],
        };
      } else {
        return {'success': false, 'error': 'Failed to load complaints'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getArchitectHistory({String? siteId}) async {
    AppLogger.d(
      '🔍 [ARCHITECT HISTORY] Calling architect history API... (siteId: $siteId)',
    );
    try {
      final headers = await _getHeaders();

      // Build URL with optional site filter
      String url = '$baseUrl/construction/architect-history/';
      if (siteId != null && siteId.isNotEmpty) {
        url += '?site_id=$siteId';
      }

      AppLogger.d('🔍 [ARCHITECT HISTORY] URL: $url');

      final response = await ApiClient.get(Uri.parse(url), headers: headers);

      AppLogger.d('📊 [ARCHITECT HISTORY] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documentsCount = (data['documents'] as List?)?.length ?? 0;
        final complaintsCount = (data['complaints'] as List?)?.length ?? 0;
        AppLogger.d('✅ [ARCHITECT HISTORY] Documents: $documentsCount');
        AppLogger.d('✅ [ARCHITECT HISTORY] Complaints: $complaintsCount');

        return data;
      } else {
        AppLogger.d('❌ [ARCHITECT HISTORY] Error response: ${response.body}');
      }
      return {'documents': [], 'complaints': []};
    } catch (e) {
      AppLogger.d('❌ [ARCHITECT HISTORY] Exception: $e');
      return {'documents': [], 'complaints': []};
    }
  }

  // ============================================
  // CHANGE REQUEST SYSTEM
  // ============================================

  Future<Map<String, dynamic>> requestChange({
    required String entryId,
    required String entryType,
    required String requestMessage,
    Map<String, dynamic>? proposedChanges,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'entry_id': entryId,
        'entry_type': entryType,
        'request_message': requestMessage,
      };

      // Add proposed changes if provided
      if (proposedChanges != null && proposedChanges.isNotEmpty) {
        requestBody['proposed_changes'] = proposedChanges;
      }

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/request-change/'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'request_id': data['request_id']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to request change',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getMyChangeRequests() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/my-change-requests/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'change_requests': data['change_requests']};
      } else {
        return {'success': false, 'error': 'Failed to load change requests'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getPendingChangeRequests() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/pending-change-requests/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'change_requests': data['change_requests']};
      } else {
        return {'success': false, 'error': 'Failed to load pending requests'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> handleChangeRequest({
    required String requestId,
    required dynamic newValue,
    String? responseMessage,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/handle-change-request/$requestId/'),
        headers: await _getHeaders(),
        body: json.encode({
          'new_value': newValue,
          'response_message': responseMessage ?? '',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to handle request',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getModifiedEntries() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/modified-entries/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'labour_entries': data['labour_entries'],
          'material_entries': data['material_entries'],
        };
      } else {
        return {'success': false, 'error': 'Failed to load modified entries'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================
  // SUPERVISOR: UPLOAD PHOTOS
  // ============================================

  Future<List<int>> _compressImage(XFile photoFile) async {
    try {
      final bytes = await photoFile.readAsBytes();
      final originalSize = bytes.length;

      // Decode the image
      final image = img.decodeImage(bytes);
      if (image == null) {
        AppLogger.d('⚠️ [COMPRESS] Could not decode image, using original');
        return bytes;
      }

      // Resize image to max 1000x800px to reduce file size
      final resized = img.copyResize(
        image,
        width: image.width > 1000 ? 1000 : image.width,
        height: image.height > 800 ? 800 : image.height,
        interpolation: img.Interpolation.linear,
      );

      // Encode back to JPEG with 85% quality
      final compressedBytes = img.encodeJpg(resized, quality: 85);

      final compressedSize = compressedBytes.length;
      final reduction = ((1 - (compressedSize / originalSize)) * 100).toStringAsFixed(1);
      AppLogger.d('📸 [COMPRESS] ${photoFile.name}: ${(originalSize / 1024).toStringAsFixed(0)}KB → ${(compressedSize / 1024).toStringAsFixed(0)}KB ($reduction% reduction)');

      return compressedBytes;
    } catch (e) {
      AppLogger.d('⚠️ [COMPRESS] Error compressing image: $e, using original');
      return await photoFile.readAsBytes();
    }
  }

  Future<Map<String, dynamic>> uploadSupervisorPhotos({
    required String siteId,
    required List<dynamic> photos, // List of XFile
    required String timeOfDay, // 'morning' or 'evening'
  }) async {
    try {
      final token = await _authService.getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/construction/supervisor-upload-photos/'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer ${token ?? ''}';

      // Add fields
      request.fields['site_id'] = siteId.toString();
      request.fields['time_of_day'] = timeOfDay;

      // Add photos with compression - Web and Mobile compatible
      for (var photo in photos) {
        final compressedBytes = await _compressImage(photo);

        final file = http.MultipartFile.fromBytes(
          'photos',
          compressedBytes,
          filename: photo.name,
        );
        request.files.add(file);
      }

      // Send with 60s timeout so large photos don't hang forever
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () =>
            throw TimeoutException('Upload timed out. Check your connection and try again.'),
      );
      final response = await http.Response.fromStream(streamedResponse);

      // Guard against non-JSON responses (e.g. nginx 413 / 502 HTML pages)
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {
          'success': false,
          'error': 'Server error (${response.statusCode}). Please try again.',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Photos uploaded successfully',
          'photo_count': data['photo_count'] ?? photos.length,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? data['message'] ?? 'Failed to upload photos (${response.statusCode})',
        };
      }
    } catch (e) {
      AppLogger.d('Error uploading photos: $e');
      final msg = e is TimeoutException ? e.message ?? 'Upload timed out' : 'Network error: $e';
      return {'success': false, 'error': msg};
    }
  }

  // ============================================
  // GET SUPERVISOR UPLOADED PHOTOS
  // ============================================

  Future<Map<String, dynamic>> getSupervisorUploadedPhotos({
    required String siteId,
  }) async {
    try {
      final token = await _authService.getToken();

      AppLogger.d('🖼️ [PHOTOS] Fetching uploaded photos for site: $siteId');

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/supervisor-photos/?site_id=$siteId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
      );

      AppLogger.d('🖼️ [PHOTOS] Response status: ${response.statusCode}');
      AppLogger.d('🖼️ [PHOTOS] Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final photos = List<Map<String, dynamic>>.from(data['photos'] ?? []);
        AppLogger.d('🖼️ [PHOTOS] Loaded ${photos.length} photos');
        return {'success': true, 'photos': photos};
      } else {
        AppLogger.d('🖼️ [PHOTOS] Error: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load photos',
        };
      }
    } catch (e) {
      AppLogger.d('🖼️ [PHOTOS] Exception: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================
  // WORKING SITES (Accountant assigns to Supervisor)
  // ============================================

  Future<Map<String, dynamic>> getAllSites() async {
    try {
      final token = await _authService.getToken();

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/all-sites/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'sites': List<Map<String, dynamic>>.from(data['sites'] ?? []),
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load sites',
        };
      }
    } catch (e) {
      AppLogger.d('Error loading sites: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getSupervisorsList() async {
    try {
      final token = await _authService.getToken();

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/supervisors-list/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'supervisors': List<Map<String, dynamic>>.from(
            data['supervisors'] ?? [],
          ),
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load supervisors',
        };
      }
    } catch (e) {
      AppLogger.d('Error loading supervisors: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> assignWorkingSites({
    required List<Map<String, dynamic>> sites,
  }) async {
    try {
      final token = await _authService.getToken();

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/assign-working-sites/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
        body: json.encode({'sites': sites}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'assigned_count': data['assigned_count'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to assign sites',
        };
      }
    } catch (e) {
      AppLogger.d('Error assigning sites: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getWorkingSites() async {
    try {
      final token = await _authService.getToken();
      final user = await _authService.getCurrentUser();
      final userRole = user?['role'] ?? '';

      AppLogger.d('🔍 [SERVICE] getWorkingSites called');
      AppLogger.d('🔍 [SERVICE] User role: $userRole');

      // Use different endpoint based on role
      String endpoint;
      if (userRole == 'Admin') {
        endpoint = '$baseUrl/construction/admin/all-working-sites/';
        AppLogger.d('✅ [SERVICE] Using ADMIN endpoint: $endpoint');
      } else {
        endpoint = '$baseUrl/construction/working-sites/';
        AppLogger.d('✅ [SERVICE] Using SUPERVISOR endpoint: $endpoint');
      }

      AppLogger.d('🔍 [SERVICE] Making request to: $endpoint');

      final response = await ApiClient.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
      );

      AppLogger.d('📊 [SERVICE] Response status: ${response.statusCode}');
      AppLogger.d('📊 [SERVICE] Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final sites = List<Map<String, dynamic>>.from(data['sites'] ?? []);
        AppLogger.d('✅ [SERVICE] Success! Returning ${sites.length} sites');
        return {'success': true, 'sites': sites};
      } else {
        AppLogger.d('❌ [SERVICE] Error response: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load working sites',
        };
      }
    } catch (e) {
      AppLogger.d('❌ [SERVICE] Exception: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getTodaySitesWithEntries() async {
    try {
      final token = await _authService.getToken();

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/today-sites-with-data/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'sites': List<Map<String, dynamic>>.from(data['sites'] ?? []),
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load today sites with data',
        };
      }
    } catch (e) {
      AppLogger.d('Error loading today sites with data: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getTotalCounts() async {
    try {
      final token = await _authService.getToken();

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/total-counts/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'total_areas': data['total_areas'] ?? 0,
          'total_streets': data['total_streets'] ?? 0,
          'total_sites': data['total_sites'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load total counts',
        };
      }
    } catch (e) {
      AppLogger.d('Error loading total counts: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Add client requirement
  Future<bool> addClientRequirement(
    String siteId,
    String description,
    double amount,
  ) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/accountant/add-client-requirement/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'site_id': siteId,
          'description': description,
          'amount': amount,
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        AppLogger.d(
          '❌ Failed to add client requirement: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      AppLogger.d('❌ Error adding client requirement: $e');
      return false;
    }
  }

  Future<bool> updateClientRequirement(
    String requirementId,
    String? description,
    double? amount,
  ) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final body = <String, dynamic>{};
      if (description != null) body['description'] = description;
      if (amount != null) body['amount'] = amount;

      if (body.isEmpty) return false;

      final response = await ApiClient.put(
        Uri.parse('$baseUrl/accountant/update-client-requirement/$requirementId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        AppLogger.d(
          '❌ Failed to update client requirement: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      AppLogger.d('❌ Error updating client requirement: $e');
      return false;
    }
  }

  // ============================================
  // CLIENT APIS
  // ============================================

  Future<Map<String, dynamic>> getClientSiteDetails() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/client/site-details/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [CLIENT] Site details loaded');
        return data;
      }

      AppLogger.d('❌ [CLIENT] Error: ${response.statusCode}');
      return {'sites': []};
    } catch (e) {
      AppLogger.d('❌ [CLIENT] Exception: $e');
      return {'sites': []};
    }
  }

  Future<Map<String, dynamic>> getClientMaterials(String siteId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/client/materials/?site_id=$siteId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [CLIENT] Materials loaded: ${data['count']} items');
        return data;
      }

      AppLogger.d('❌ [CLIENT MATERIALS] Error: ${response.statusCode}');
      return {'materials': []};
    } catch (e) {
      AppLogger.d('❌ [CLIENT MATERIALS] Exception: $e');
      return {'materials': []};
    }
  }

  Future<Map<String, dynamic>> getClientPhotosByDate({
    required String siteId,
    String? filterDate,
  }) async {
    try {
      String url = '$baseUrl/client/photos-by-date/?site_id=$siteId';
      if (filterDate != null && filterDate.isNotEmpty) {
        url += '&date=$filterDate';
      }

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [CLIENT PHOTOS] Loaded: ${data['total_photos']} photos');
        AppLogger.d(
          '   Supervisor: ${data['supervisor_photos']}, Engineer: ${data['engineer_photos']}',
        );
        if (filterDate != null) {
          AppLogger.d('   Filtered by date: $filterDate');
        }
        return data;
      }

      AppLogger.d('❌ [CLIENT PHOTOS] Error: ${response.statusCode}');
      return {'photos_by_date': {}, 'dates': [], 'total_photos': 0};
    } catch (e) {
      AppLogger.d('❌ [CLIENT PHOTOS] Exception: $e');
      return {'photos_by_date': {}, 'dates': [], 'total_photos': 0};
    }
  }

  Future<Map<String, dynamic>?> getClientBudgetAllocation(String siteId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/budget/allocation/$siteId/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [CLIENT BUDGET] Budget allocation loaded for site: $siteId');
        return data;
      } else if (response.statusCode == 404) {
        AppLogger.d(
          'ℹ️ [CLIENT BUDGET] No budget allocation found for site: $siteId',
        );
        return null;
      }

      AppLogger.d('❌ [CLIENT BUDGET] Error: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.d('❌ [CLIENT BUDGET] Exception: $e');
      return null;
    }
  }

  // ============================================
  // CLIENT COMPLAINTS APIs
  // ============================================

  Future<Map<String, dynamic>> getClientComplaints({String? siteId}) async {
    try {
      String url = '$baseUrl/client/complaints/';
      if (siteId != null && siteId.isNotEmpty) {
        url += '?site_id=$siteId';
      }

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [CLIENT] Complaints loaded: ${data['total_count']} items');
        return data;
      }

      AppLogger.d('❌ [CLIENT COMPLAINTS] Error: ${response.statusCode}');
      return {'complaints': [], 'total_count': 0};
    } catch (e) {
      AppLogger.d('❌ [CLIENT COMPLAINTS] Exception: $e');
      return {'complaints': [], 'total_count': 0};
    }
  }

  Future<Map<String, dynamic>> createClientComplaint({
    required String siteId,
    required String title,
    String? description,
    String priority = 'MEDIUM',
    String? proofImageUrl,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/client/complaints/create/'),
        headers: await _getHeaders(),
        body: json.encode({
          'site_id': siteId,
          'title': title,
          'description': description ?? '',
          'priority': priority,
          'proof_image_url': proofImageUrl ?? '',
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [CLIENT] Complaint created: ${data['complaint']['id']}');
        return data;
      }

      AppLogger.d('❌ [CLIENT CREATE COMPLAINT] Error: ${response.statusCode}');
      AppLogger.d('Response: ${response.body}');
      return {'success': false, 'error': 'Failed to create complaint'};
    } catch (e) {
      AppLogger.d('❌ [CLIENT CREATE COMPLAINT] Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getComplaintMessages(String complaintId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/client/complaints/$complaintId/messages/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [CLIENT] Messages loaded: ${data['total_count']} items');
        return data;
      }

      AppLogger.d('❌ [CLIENT MESSAGES] Error: ${response.statusCode}');
      return {'messages': [], 'total_count': 0};
    } catch (e) {
      AppLogger.d('❌ [CLIENT MESSAGES] Exception: $e');
      return {'messages': [], 'total_count': 0};
    }
  }

  Future<Map<String, dynamic>> sendComplaintMessage({
    required String complaintId,
    required String message,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/client/complaints/$complaintId/messages/send/'),
        headers: await _getHeaders(),
        body: json.encode({'message': message}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [CLIENT] Message sent');
        return data;
      }

      AppLogger.d('❌ [CLIENT SEND MESSAGE] Error: ${response.statusCode}');
      return {'success': false, 'error': 'Failed to send message'};
    } catch (e) {
      AppLogger.d('❌ [CLIENT SEND MESSAGE] Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================
  // ARCHITECT CLIENT COMPLAINTS APIs
  // ============================================

  Future<Map<String, dynamic>> getClientComplaintsForArchitect({
    String? siteId,
    String? status,
  }) async {
    try {
      String url = '$baseUrl/construction/client-complaints/';
      List<String> params = [];

      if (siteId != null && siteId.isNotEmpty) {
        params.add('site_id=$siteId');
      }
      if (status != null && status.isNotEmpty) {
        params.add('status=$status');
      }

      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d(
          '✅ [ARCHITECT] Client complaints loaded: ${data['total_count']} items',
        );
        return data;
      }

      AppLogger.d('❌ [ARCHITECT CLIENT COMPLAINTS] Error: ${response.statusCode}');
      return {'complaints': [], 'total_count': 0};
    } catch (e) {
      AppLogger.d('❌ [ARCHITECT CLIENT COMPLAINTS] Exception: $e');
      return {'complaints': [], 'total_count': 0};
    }
  }

  Future<Map<String, dynamic>> getComplaintMessagesArchitect(
    String complaintId,
  ) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/complaints/$complaintId/messages/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [ARCHITECT] Messages loaded: ${data['total_count']} items');
        return data;
      }

      AppLogger.d('❌ [ARCHITECT MESSAGES] Error: ${response.statusCode}');
      return {'messages': [], 'total_count': 0};
    } catch (e) {
      AppLogger.d('❌ [ARCHITECT MESSAGES] Exception: $e');
      return {'messages': [], 'total_count': 0};
    }
  }

  Future<Map<String, dynamic>> sendComplaintMessageArchitect({
    required String complaintId,
    required String message,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse(
          '$baseUrl/construction/complaints/$complaintId/messages/send/',
        ),
        headers: await _getHeaders(),
        body: json.encode({'message': message}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        AppLogger.d('✅ [ARCHITECT] Message sent');
        return data;
      }

      AppLogger.d('❌ [ARCHITECT SEND MESSAGE] Error: ${response.statusCode}');
      return {'success': false, 'error': 'Failed to send message'};
    } catch (e) {
      AppLogger.d('❌ [ARCHITECT SEND MESSAGE] Exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================
  // MATERIAL REQUIREMENTS SYSTEM
  // ============================================

  /// Submit material requirement (Supervisor)
  Future<Map<String, dynamic>> submitMaterialRequirement({
    required String siteId,
    required String materialName,
    required double quantity,
    required String unit,
    String priority = 'normal',
    String notes = '',
  }) async {
    try {
      final token = await _authService.getToken();

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/material-requirements/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
        body: json.encode({
          'site_id': siteId,
          'material_name': materialName,
          'quantity': quantity,
          'unit': unit,
          'priority': priority,
          'notes': notes,
        }),
      );

      // Check if response is JSON
      if (response.headers['content-type']?.contains('application/json') !=
          true) {
        AppLogger.d(
          'Error: Server returned non-JSON response (status ${response.statusCode})',
        );
        return {
          'success': false,
          'error':
              'Backend endpoint not ready. Please wait for deployment to complete.',
        };
      }

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Material requirement submitted',
          'requirement_id': data['requirement_id'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to submit material requirement',
        };
      }
    } catch (e) {
      AppLogger.d('Error submitting material requirement: $e');
      return {
        'success': false,
        'error':
            'Backend not ready yet. Please try again after deployment completes.',
      };
    }
  }

  /// Get material requirements (Admin/Accountant/Supervisor)
  Future<Map<String, dynamic>> getMaterialRequirements() async {
    try {
      final token = await _authService.getToken();

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/construction/material-requirements/list/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'requirements': data['requirements'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load material requirements',
        };
      }
    } catch (e) {
      AppLogger.d('Error loading material requirements: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Update material requirement status (Admin/Accountant)
  Future<Map<String, dynamic>> updateMaterialRequirementStatus({
    required String requirementId,
    required String status,
  }) async {
    try {
      final token = await _authService.getToken();

      final response = await ApiClient.put(
        Uri.parse(
          '$baseUrl/construction/material-requirements/$requirementId/status/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
        body: json.encode({'status': status}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Status updated',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to update status',
        };
      }
    } catch (e) {
      AppLogger.d('Error updating material requirement status: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Delete material requirement
  Future<Map<String, dynamic>> deleteMaterialRequirement(
    String requirementId,
  ) async {
    try {
      final token = await _authService.getToken();

      final response = await ApiClient.delete(
        Uri.parse(
          '$baseUrl/construction/material-requirements/$requirementId/delete/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Requirement deleted',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to delete requirement',
        };
      }
    } catch (e) {
      AppLogger.d('Error deleting material requirement: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ============================================
  // ACCOUNTANT COMPARISON ENDPOINTS
  // ============================================

  /// Get entries by date and role for comparison
  Future<List<Map<String, dynamic>>> getEntriesByDateAndRole(
    String date,
    String role,
  ) async {
    AppLogger.d(
      '🔍 [SERVICE] getEntriesByDateAndRole called - date: $date, role: $role',
    );
    try {
      final token = await _authService.getToken();
      if (token == null) {
        AppLogger.d('❌ [SERVICE] No token available');
        return [];
      }

      final url =
          '$baseUrl/construction/entries-by-date-role/?date=$date&role=$role';
      AppLogger.d('🔍 [SERVICE] URL: $url');

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      AppLogger.d('📊 [SERVICE] Response status: ${response.statusCode}');
      AppLogger.d('📊 [SERVICE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        AppLogger.d('✅ [SERVICE] Parsed ${data.length} items');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      AppLogger.d('❌ [SERVICE] Non-200 status code');
      return [];
    } catch (e) {
      AppLogger.d('❌ [SERVICE] Error fetching entries by date: $e');
      return [];
    }
  }

  /// Get approved entries grouped by site and date
  Future<List<Map<String, dynamic>>> getApprovedEntries(String date) async {
    AppLogger.d('🔍 [SERVICE] getApprovedEntries called - date: $date');
    try {
      final token = await _authService.getToken();
      if (token == null) {
        AppLogger.d('❌ [SERVICE] No token available');
        return [];
      }

      final url = '$baseUrl/construction/approved-entries/?date=$date';
      AppLogger.d('🔍 [SERVICE] URL: $url');

      final response = await ApiClient.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      AppLogger.d('📊 [SERVICE] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> entries = data['approved_entries'] ?? [];
        AppLogger.d('✅ [SERVICE] Parsed ${entries.length} approved entries');
        return entries.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      AppLogger.d('❌ [SERVICE] Non-200 status code');
      return [];
    } catch (e) {
      AppLogger.d('❌ [SERVICE] Error fetching approved entries: $e');
      return [];
    }
  }

  /// Confirm a cash entry from supervisor/engineer entry
  Future<Map<String, dynamic>> confirmCashEntry({
    required String siteId,
    required String entryDate,
    required String sourceType,
    String? sourceEntryId,
    required List<Map<String, dynamic>> labourEntries,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return {'success': false, 'error': 'No token'};

      final payload = {
        'site_id': siteId,
        'entry_date': entryDate,
        'source_type': sourceType,
        'source_entry_id': sourceEntryId,
        'labour_entries': labourEntries,
      };

      AppLogger.d('🔵 [CONFIRM-SERVICE] Sending confirmation request');
      AppLogger.d('🔵 [CONFIRM-SERVICE] Payload: $payload');

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/confirm-cash-entry/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );

      AppLogger.d('🔵 [CONFIRM-SERVICE] Response status: ${response.statusCode}');
      AppLogger.d('🔵 [CONFIRM-SERVICE] Response body: ${response.body}');

      final data = json.decode(response.body);
      AppLogger.d('🔵 [CONFIRM-SERVICE] Parsed data: $data');

      if (response.statusCode == 201 || response.statusCode == 200) {
        AppLogger.d('✅ [CONFIRM-SERVICE] Confirmation successful');
        return {
          'success': true,
          'message': data['message'] ?? 'Entry confirmed successfully',
        };
      } else {
        AppLogger.d('❌ [CONFIRM-SERVICE] Confirmation failed with status ${response.statusCode}');
        return {
          'success': false,
          'error': data['error'] ?? data['message'] ?? 'Failed to confirm entry',
        };
      }
    } catch (e) {
      AppLogger.d('❌ [CONFIRM-SERVICE] Error confirming cash entry: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create a custom cash entry
  Future<Map<String, dynamic>> createCustomCashEntry({
    required String siteId,
    required String entryDate,
    required List<Map<String, dynamic>> labourEntries,
    String? notes,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return {'success': false, 'error': 'No token'};

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/construction/create-custom-cash-entry/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'site_id': siteId,
          'entry_date': entryDate,
          'labour_entries': labourEntries,
          'notes': notes,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Failed to create'};
      }
    } catch (e) {
      AppLogger.d('Error creating custom cash entry: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check if cash entry exists for a site and date
  Future<Map<String, dynamic>> checkCashEntryExists({
    required String siteId,
    required String date,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return {'exists': false};

      final response = await ApiClient.get(
        Uri.parse(
          '$baseUrl/construction/check-cash-entry/?site_id=$siteId&date=$date',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'exists': false};
    } catch (e) {
      AppLogger.d('Error checking cash entry: $e');
      return {'exists': false};
    }
  }

  /// Get labour rates (global or site-specific)
  Future<Map<String, dynamic>> getLabourRates(String siteId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return {'rates': []};

      final response = await ApiClient.get(
        Uri.parse('$baseUrl/budget/labour-rates/$siteId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'rates': []};
    } catch (e) {
      AppLogger.d('Error getting labour rates: $e');
      return {'rates': []};
    }
  }
}
