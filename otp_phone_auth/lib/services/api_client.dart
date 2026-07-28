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

  static bool _handle(http.BaseResponse response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    return true;
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await http
        .get(url, headers: headers)
        .timeout(timeout ?? defaultTimeout);
    _handle(response);
    return response;
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
    _handle(response);
    return response;
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
    _handle(response);
    return response;
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
    _handle(response);
    return response;
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
    _handle(response);
    return response;
  }

  /// For [http.MultipartRequest] uploads, which can't go through the
  /// methods above — applies the same default timeout + 401 check to
  /// `request.send()`.
  static Future<http.StreamedResponse> sendMultipart(
    http.MultipartRequest request, {
    Duration? timeout,
  }) async {
    final streamed = await request.send().timeout(timeout ?? defaultTimeout);
    _handle(streamed);
    return streamed;
  }
}
