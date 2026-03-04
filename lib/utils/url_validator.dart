/// Validates URLs before opening in external browser.
/// Prevents open redirect and phishing by allowlisting trusted domains.
class UrlValidator {
  UrlValidator._();

  /// Allowed host suffixes (e.g. 'kolenu.net' matches www.kolenu.net, cloud.kolenu.net).
  static const List<String> _allowedHostSuffixes = [
    'kolenu.net',
    'github.com',
    'testflight.apple.com',
    'apple.com',
    'google.com',
    'docs.google.com',
    'forms.google.com',
  ];

  /// Returns true if [url] is safe to open: https only, host in allowlist.
  static bool isSafeToOpen(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    return _allowedHostSuffixes.any((suffix) {
      return host == suffix || host.endsWith('.$suffix');
    });
  }
}
