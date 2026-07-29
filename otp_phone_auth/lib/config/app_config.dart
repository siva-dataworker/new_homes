/// Centralised app configuration.
///
/// The backend URL is read from --dart-define at build time:
///   flutter build apk --dart-define=BASE_URL=http://187.127.164.22:8000/api
///
/// If not provided it falls back to the VPS backend below.
/// TODO: this is plain HTTP (no TLS configured on the VPS yet) — move to
/// HTTPS once a domain + certificate is set up on srv1651526.hstgr.cloud.
/// Render (new-essentials.onrender.com) is no longer live; do not revert to it.
class AppConfig {
  /// Base API URL.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://187.127.164.22:8000/api',
  );

  /// Media / file base URL (same host, no /api suffix).
  static const String mediaBaseUrl = String.fromEnvironment(
    'MEDIA_BASE_URL',
    defaultValue: 'http://187.127.164.22:8000',
  );

  /// Build a full URL for a media file path returned by the backend.
  /// e.g.  AppConfig.mediaUrl('/media/photos/abc.jpg')
  static String mediaUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$mediaBaseUrl$path';
  }
}
