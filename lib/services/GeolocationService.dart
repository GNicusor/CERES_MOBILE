import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

class GeolocationService {
  static Completer<bg.Location>? _FirstLocation;

  /// Starts background tracking for [duration] minutes.
  /// onLocation: called with {'latitude': x, 'longitude': y} once.
  /// onError: called with error message.
  static Future<void> startTracking({
    required int duration,
    required void Function(Map<String, dynamic>) onLocation,
    required void Function(String) onError,
  }) async {
    // Permission check
    final status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      final req = await Permission.locationAlways.request();
      if (!req.isGranted) {
        onError('Location permission denied');
        return;
      }
    }

    // Configure and start BG Geo
    try {
      await bg.BackgroundGeolocation.ready(bg.Config(
        url: 'https://ubuntu1.vlahi.com/tracking/updateMobileDeviceLocation',
        method: 'POST',
        autoSync: true,
        distanceFilter: 10,
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        stopOnTerminate: false,
        enableHeadless: true,
        debug: false,
        logLevel: bg.Config.LOG_LEVEL_OFF,
        stopAfterElapsedMinutes: duration,
      ));
      await bg.BackgroundGeolocation.start();
    } catch (e) {
      onError('Error initializing geolocation: \$e');
      return;
    }

    // One-time location callback
    _FirstLocation = Completer<bg.Location>();
    bg.BackgroundGeolocation.onLocation((loc) {
      if (!_FirstLocation!.isCompleted) {
        _FirstLocation!.complete(loc);
        onLocation({
          'latitude': loc.coords.latitude,
          'longitude': loc.coords.longitude,
        });
      }
    });
  }

  /// Stops background tracking
  static Future<void> stopTracking() async {
    await bg.BackgroundGeolocation.stop();
  }
}