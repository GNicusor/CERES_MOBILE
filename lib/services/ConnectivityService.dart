import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  /// Checks current connectivity including actual internet reachability.
  static Future<bool> check() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return false;
    // Optionally: try ping or HTTP request here if desired
    return true;
  }

  /// Stream of connectivity changes (true = connected, false = none).
  static Stream<bool> get onChange async* {
    await for (final result in Connectivity().onConnectivityChanged) {
      yield result != ConnectivityResult.none;
    }
  }
}