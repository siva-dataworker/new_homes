import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin wrapper around [http]'s free-function API.
///
/// Every request gets a default timeout so a slow/unresponsive backend
/// (the norm on a construction site's connectivity) fails fast instead of
/// hanging a screen's loading state forever, and every response is checked
/// for 401 so an expired session triggers [onUnauthorized] once, in one
/// place, instead of every caller silently failing with no explanation.
///
/// Drop-in replacement for `http.get`/`http.post`/`http.put`/`http.patch`/
/// `http.delete` — same signatures, so existing call sites only need their
/// receiver swapped from `http` to `ApiClient`.
class ApiClient {
  ApiClient._();

  static const Duration defaultTimeout = Duration(seconds: 20);

  /// Set once, from `main.dart`, to route an expired/invalid session to
  /// logout + the login screen. Left null-safe so services can be tested
  /// or used before the app wires this up.
  static void Function()? onUnauthorized;

  /// Set once, from `main.dart`, to attempt a token refresh on a 401 before
  /// giving up. Returns the new access token on success, or null if the
  /// refresh token itself is missing/invalid/expired — at which point
  /// [onUnauthorized] fires instead. Every method below retries its request
  /// exactly once, with the Authorization header swapped to the new token,
  /// so an expired 30-minute access token no longer destroys whatever the
  /// user was in the middle of doing on a 30-day-valid session.
  static Future<String?> Function()? onTokenExpired;

  static Map<String, String>? _withRefreshedAuth(
    Map<String, String>? headers,
    String newToken,
  ) {
    if (headers == null || !headers.containsKey('Authorization')) {
      return headers;
    }
    return {...headers, 'Authorization': 'Bearer $newToken'};
  }

  /// Returns the new token to retry with, or null if the caller should just
  /// return the original (401) response as-is.
  static Future<String?> _tryRefresh() async {
    if (onTokenExpired == null) {
      onUnauthorized?.call();
      return null;
    }
    final newToken = await onTokenExpired!();
    if (newToken == null) {
      onUnauthorized?.call();
      return null;
    }
    return newToken;
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await http
        .get(url, headers: headers)
        .timeout(timeout ?? defaultTimeout);
    if (response.statusCode != 401) return response;

    final newToken = await _tryRefresh();
    if (newToken == null) return response;
    return http
        .get(url, headers: _withRefreshedAuth(headers, newToken))
        .timeout(timeout ?? defaultTimeout);
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
  }) async {
    final response = await http
        .post(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout ?? defaultTimeout);
    if (response.statusCode != 401) return response;

    final newToken = await _tryRefresh();
    if (newToken == null) return response;
    return http
        .post(
          url,
          headers: _withRefreshedAuth(headers, newToken),
          body: body,
          encoding: encoding,
        )
        .timeout(timeout ?? defaultTimeout);
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
  }) async {
    final response = await http
        .put(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout ?? defaultTimeout);
    if (response.statusCode != 401) return response;

    final newToken = await _tryRefresh();
    if (newToken == null) return response;
    return http
        .put(
          url,
          headers: _withRefreshedAuth(headers, newToken),
          body: body,
          encoding: encoding,
        )
        .timeout(timeout ?? defaultTimeout);
  }

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
  }) async {
    final response = await http
        .patch(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout ?? defaultTimeout);
    if (response.statusCode != 401) return response;

    final newToken = await _tryRefresh();
    if (newToken == null) return response;
    return http
        .patch(
          url,
          headers: _withRefreshedAuth(headers, newToken),
          body: body,
          encoding: encoding,
        )
        .timeout(timeout ?? defaultTimeout);
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
  }) async {
    final response = await http
        .delete(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout ?? defaultTimeout);
    if (response.statusCode != 401) return response;

    final newToken = await _tryRefresh();
    if (newToken == null) return response;
    return http
        .delete(
          url,
          headers: _withRefreshedAuth(headers, newToken),
          body: body,
          encoding: encoding,
        )
        .timeout(timeout ?? defaultTimeout);
  }

  /// For [http.MultipartRequest] uploads, which can't go through the
  /// methods above — applies the same default timeout + 401 check to
  /// `request.send()`. Note: a MultipartRequest's file streams are
  /// single-use, so a true retry isn't possible here if fields/files were
  /// already consumed — this at least refreshes the token and surfaces
  /// [onUnauthorized] correctly rather than silently misreporting the
  /// failure as a generic error, matching the other methods' behavior.
  static Future<http.StreamedResponse> sendMultipart(
    http.MultipartRequest request, {
    Duration? timeout,
  }) async {
    final streamed = await request.send().timeout(timeout ?? defaultTimeout);
    if (streamed.statusCode == 401) {
      await _tryRefresh();
    }
    return streamed;
  }
}
