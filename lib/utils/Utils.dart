import 'dart:io';

class UserAgent {
  static String get ios =>
      "Mozilla/5.0 (iPad; CPU OS 17_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/134.0.6998.99 Mobile/15E148 Safari/604.1";

  static String get android =>
      "Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UP1A.230905.014) AppleWebKit/605.1.15 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/604.1";

  static String get current => Platform.isIOS ? ios : android;
}