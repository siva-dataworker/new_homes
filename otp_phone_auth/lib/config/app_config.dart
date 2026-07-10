/// Centralised app configuration.
///
/// The backend URL is read from --dart-define at build time:
///   flutter build apk --dart-define=BASE_URL=https://new-essentials.onrender.com
///
/// If not provided it falls back to the production Render URL.
/// Never use a plain http:// address — all traffic must be HTTPS.
class AppConfig {
  /// Base API URL — always HTTPS, no trailing slash on the domain.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://new-essentials.onrender.com/api',
  );

  /// Media / file base URL (same host, no /api suffix).
  static const String mediaBaseUrl = String.fromEnvironment(
    'MEDIA_BASE_URL',
    defaultValue: 'https://new-essentials.onrender.com',
  );

  /// Build a full URL for a media file path returned by the backend.
  /// e.g.  AppConfig.mediaUrl('/media/photos/abc.jpg')
  static String mediaUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$mediaBaseUrl$path';
  }
}
