import '../config/app_config.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Django backend URL
  static String get baseUrl => AppConfig.baseUrl;
  static const Duration requestTimeout = Duration(seconds: 10);

  // The JWT and cached user profile are session credentials, not app
  // preferences — they belong in the platform keystore/keychain, not
  // plaintext SharedPreferences.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _token;
  String? _refreshToken;
  Map<String, dynamic>? _currentUser;

  // Get stored token
  Future<String?> getToken() async {
    if (_token != null) return _token;

    _token = await _storage.read(key: 'auth_token');
    return _token;
  }

  // Get stored refresh token
  Future<String?> getRefreshToken() async {
    if (_refreshToken != null) return _refreshToken;

    _refreshToken = await _storage.read(key: 'refresh_token');
    return _refreshToken;
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    final userJson = await _storage.read(key: 'current_user');
    if (userJson != null) {
      _currentUser = json.decode(userJson);
    }
    return _currentUser;
  }

  // Store token and user data
  Future<void> _storeAuthData(
    String token,
    Map<String, dynamic> user, {
    String? refreshToken,
  }) async {
    _token = token;
    _currentUser = user;

    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'current_user', value: json.encode(user));

    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }
  }

  /// Exchange the stored refresh token for a new access token.
  ///
  /// Returns the new access token on success (and updates stored auth data
  /// so [getToken] picks it up immediately), or null if the refresh token
  /// itself is missing/invalid/expired/revoked — at which point the caller
  /// should treat this as a real logout, since there's no way to recover
  /// the session without the user signing in again.
  Future<String?> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return null;

    try {
      // Deliberately uses plain http.post, NOT ApiClient.post — this call is
      // what ApiClient's own 401 handling calls into (see api_client.dart's
      // onTokenExpired), so routing it back through ApiClient would recurse
      // forever the moment a refresh token is actually invalid/expired.
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'refresh_token': refreshToken}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['access_token'] as String?;
        if (newToken == null) return null;

        _token = newToken;
        await _storage.write(key: 'auth_token', value: newToken);
        return newToken;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Clear auth data
  Future<void> clearAuthData() async {
    _token = null;
    _refreshToken = null;
    _currentUser = null;

    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'current_user');
  }

  // Register new user
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'phone': phone,
          'password': password,
          'full_name': fullName,
          'role': role,
        }),
        timeout: requestTimeout,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'user_id': data['user_id'],
          'status': data['status'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString().contains('TimeoutException')
            ? 'Connection timeout - please check your internet'
            : 'Network error: $e',
      };
    }
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
        timeout: requestTimeout,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Store token and user data
        await _storeAuthData(
          data['access_token'],
          data['user'],
          refreshToken: data['refresh_token'] as String?,
        );

        return {'success': true, 'user': data['user']};
      } else if (response.statusCode == 403) {
        // Pending or rejected
        return {
          'success': false,
          'error': data['error'],
          'status': data['status'],
        };
      } else {
        return {'success': false, 'error': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString().contains('TimeoutException')
            ? 'Connection timeout - please check your internet'
            : 'Network error: $e',
      };
    }
  }

  // Check approval status
  Future<Map<String, dynamic>> checkApprovalStatus(String username) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/auth/status/?username=$username'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'status': data['status'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to check status',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get available roles
  Future<List<String>> getRoles() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/auth/roles/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['roles']);
      }
      return [
        'Supervisor',
        'Site Engineer',
        'Accountant',
        'Architect',
        'Owner',
      ];
    } catch (e) {
      return [
        'Supervisor',
        'Site Engineer',
        'Accountant',
        'Architect',
        'Owner',
      ];
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? address,
  }) async {
    try {
      final token = await getToken();
      final response = await ApiClient.put(
        Uri.parse('$baseUrl/user/profile/update/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'full_name': name,
          'email': email,
          'phone': phone,
          if (address != null && address.isNotEmpty) 'address': address,
        }),
        timeout: requestTimeout,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Update locally cached user data
        if (_currentUser != null) {
          _currentUser = {
            ..._currentUser!,
            'name': name,
            'email': email,
            'phone': phone,
            if (address != null) 'address': address,
          };
          await _storage.write(
            key: 'current_user',
            value: json.encode(_currentUser),
          );
        }
        return {'success': true};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? data['detail'] ?? 'Update failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString().contains('TimeoutException')
            ? 'Connection timeout - please check your internet'
            : 'Network error: $e',
      };
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Logout (clear token only, no server call - one-time login)
  Future<void> logout() async {
    await clearAuthData();
  }
}
