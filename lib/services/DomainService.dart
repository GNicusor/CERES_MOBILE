import 'package:shared_preferences/shared_preferences.dart';

const _kDomainKey = 'preferred_domain';

class DomainService {
  /// Returns the URL string of the preferred domain.
  static Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    final domain = prefs.getString(_kDomainKey) ?? 'ceres';
    return domain == 'icl'
        ? 'https://icl.vlahi.com'
        : 'https://ubuntu1.vlahi.com';
  }

  /// Saves the preference (e.g. 'icl' or 'ceres').
  static Future<void> save(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDomainKey, domain);
  }
}