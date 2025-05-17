import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCookieKey = 'cookies';

class CookieService {
  static Future<void> saveFromUri(Uri uri) async {
    final cookies = await CookieManager.instance().getCookies(url: WebUri(uri.toString()));
    final list = cookies.map((c) => {
      'name': c.name,
      'value': c.value,
      'domain': c.domain,
      'path': c.path,
      'expiresDate': c.expiresDate,
      'isSecure': c.isSecure,
      'isHttpOnly': c.isHttpOnly,
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_kCookieKey, jsonEncode(list));
  }

  /// Loads stored cookies as a header string for HTTP requests.
  static Future<String?> loadHeader({Set<String>? allowedNames}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kCookieKey);
    if (jsonStr == null) return null;
    final List all = jsonDecode(jsonStr);
    final filtered = allowedNames == null
        ? all
        : all.where((c) => allowedNames.contains(c['name'])).toList();
    return filtered.map((c) => "\${c['name']}=\${c['value']}").join('; ');
  }
}