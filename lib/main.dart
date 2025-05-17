import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_core/localizations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'PDFViewer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const serverUrl = "https://ceres.vlahi.com";
//const serverUrl = "https://ubuntu1.vlahi.com";

void main() {
  FlutterNativeSplash.preserve(
      widgetsBinding: WidgetsFlutterBinding.ensureInitialized());

  Future.delayed(const Duration(seconds: 5), () {
    FlutterNativeSplash.remove();
  });

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('language_code') ?? 'en';
    setState(() {
      _locale = Locale(code);
    });
  }

  void setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CERES WebView',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('zh'),
        Locale('de'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FullScreenWebView(onLocaleChanged: setLocale),
    );
  }
}

class FullScreenWebView extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const FullScreenWebView({ Key? key, required this.onLocaleChanged }) : super(key: key);

  @override
  _FullScreenWebViewState createState() => _FullScreenWebViewState();
}

class _FullScreenWebViewState extends State<FullScreenWebView> with WidgetsBindingObserver{
  // null = checking, true = connected, false = no connection
  bool? _connectionStatus;
  bool _hasAskedPermission = false;
  late InAppWebViewController _webViewController;
  String _startUrl = serverUrl;
  bool _isDomainLoaded = false; // Flag to ensure domain is loaded
  Map<String, dynamic> data = {"name": "Alice", "age": 30};
  bool _firstLocationSent = false;
  late final String chromeUserAgent;
  bool _showGoogleCloseButton = false;
  bool _isPageReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeApp();
    chromeUserAgent = Platform.isIOS
        ? "Mozilla/5.0 (iPad; CPU OS 17_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/134.0.6998.99 Mobile/15E148 Safari/604.1"
        : "Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UP1A.230905.014) AppleWebKit/605.1.15 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/604.1";
  }

  Future<void> _initializeApp() async {
    await _loadPreferredDomain();
    await _initConnectivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore system UI when exiting.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_webViewController != null) {
      if (state == AppLifecycleState.paused) {
        // When entering background.
        _webViewController.evaluateJavascript(
            source: "if (window.webApp && typeof window.webApp.call === 'function') { window.webApp.call('enterInBackground',''); }"
        );
      } else if (state == AppLifecycleState.resumed) {
        // When exiting background.
        _webViewController.evaluateJavascript(
            source: "if (window.webApp && typeof window.webApp.call === 'function') { window.webApp.call('exitFromBackground',''); }"
        );
      }
    }
  }

  Future<void> _loadPreferredDomain() async {
    final prefs = await SharedPreferences.getInstance();
    final domain = prefs.getString("preferred_domain") ?? "ceres";
    setState(() {
      _startUrl = domain == "icl"
          ? "https://icl.vlahi.com"
          : serverUrl;
      _isDomainLoaded = true;
    });
  }

  Future<void> _savePreferredDomain(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("preferred_domain", domain);
  }

  Future<void> _initConnectivity() async {
    setState(() {
      _connectionStatus = null; // Indicate loading
    });
    final connectivityResult = await Connectivity().checkConnectivity();
    bool isConnected = connectivityResult != ConnectivityResult.none;
    if (isConnected) {
      isConnected = await _checkInternet();
    }
    setState(() {
      _connectionStatus = isConnected;
    });
  }

  Future<bool> _checkInternet() async {
    try {
      final response = await http
          .get(Uri.parse("https://www.google.com"))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void reloadWebView() {
    _webViewController.reload();
  }

  @override
  Widget build(BuildContext context) {
    // While checking connectivity / domain load, show spinner.
    if (!_isDomainLoaded || _connectionStatus == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Show the WebView or the no-connection screen.
    return Scaffold(
      body: _connectionStatus!
          ? Stack(
              children: [
                _buildWebView(),
                if (!_isPageReady) _buildLoadingOverlay(context),
              ],
            )
          : _buildNoConnectionBox(context),
    );
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFF2199f9),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_startUrl)),
              onGeolocationPermissionsShowPrompt: (controller, origin) async {
                return GeolocationPermissionShowPromptResponse(
                  origin: origin,
                  allow: true,
                  retain: true,
                );
              },
              onWebViewCreated: (controller) {
                _webViewController = controller;

                _webViewController.addJavaScriptHandler(
                  handlerName: "startTracking",
                  callback: (args) {
                    if (args.isNotEmpty) {
                      final duration = int.tryParse(args[0].toString());
                      if (duration != null) {
                        _startBackgroundGeolocation(duration);
                        final payload = jsonEncode({'duration': duration});
                        _webViewController.evaluateJavascript(
                            source: "if (window.webApp && typeof window.webApp.call === 'function') { window.webApp.call('startTracking', '$payload'); }"
                        );
                      }
                    }
                    return;
                  },
                );
                _webViewController.addJavaScriptHandler(
                  handlerName: "changeLanguage",
                  callback: (args) {
                    if (args.isNotEmpty) {
                      final raw = args[0].toString();
                      final code = raw.split(RegExp('[-_]')).first.toLowerCase();
                      const supported = ['en','es','fr','zh','de'];
                      if (supported.contains(code)) {
                        widget.onLocaleChanged(Locale(code));
                      } else {
                        debugPrint('Unsupported locale code from WebView: $raw');
                      }
                    }
                    return;
                  },
                );
                _webViewController.addJavaScriptHandler(
                  handlerName: "stopTracking",
                  callback: (args) {
                    _stopBackgroundGeolocation();
                    final payload = jsonEncode({});
                    _webViewController.evaluateJavascript(
                        source: "if (window.webApp && typeof window.webApp.call === 'function') { window.webApp.call('stopTracking', '$payload'); }"
                    );
                    return;
                  },
                );

                _webViewController.addJavaScriptHandler(
                  handlerName: "pageReady",
                  callback: (args) {
                    setState(() {
                      _isPageReady = true;
                    });
                    final payload = jsonEncode({});
                    _webViewController.evaluateJavascript(
                        source: "if (window.webApp && typeof window.webApp.call === 'function') { window.webApp.call('pageReady', '$payload'); }"
                    );
                    return;
                  },
                );
              },
              onLoadStart: (controller, url) async {
                if (url != null && (url.host.contains("google.com") || url.host.contains("facebook.com") || url.host.contains("login.live.com") || url.host.contains("appleid.apple.com") || url.host.contains("login.microsoftonline.com"))){
                  setState(() {
                    _showGoogleCloseButton = true;
                  });
                } else {
                  setState(() {
                    _showGoogleCloseButton = false;
                  });
                }

                if (url != null && url.host.contains("icl.vlahi.com")) {
                  _savePreferredDomain("icl");
                }
              },
              onLoadStop: (controller, url) async {
                String jsonData = jsonEncode(data);
                try {
                  await controller.evaluateJavascript(
                      source: "if (typeof myFlutterHandler === 'function') { myFlutterHandler2('$jsonData'); }");
                } catch (e) {
                  debugPrint('Eroare flutter , something has gone wrong with my flutterHandler');
                }

                if (url == null) return;

                final cookies = await CookieManager.instance().getCookies(url: url);
                if (cookies.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  final cookieList = cookies.map((c) {
                    return {
                      'name': c.name,
                      'value': c.value,
                      'domain': c.domain,
                      'path': c.path,
                      'expiresDate': c.expiresDate,
                      'isSecure': c.isSecure,
                      'isHttpOnly': c.isHttpOnly,
                    };
                  }).toList();
                  await prefs.setString('cookies', jsonEncode(cookieList));
                  debugPrint('Cookies stored: $cookieList');
                }
              },
              onCreateWindow: (controller, createWindowAction) async {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewTabWebView(windowId: createWindowAction.windowId),
                  ),
                );
                return true;
              },
              initialSettings: InAppWebViewSettings(
                userAgent: chromeUserAgent,
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true,
                mediaPlaybackRequiresUserGesture: false,
                hardwareAcceleration: true,
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: true,
                clearCache: true,
              ),
            ),
          ),

          if (_showGoogleCloseButton)
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () async {
                  await _webViewController.loadUrl(
                    urlRequest: URLRequest(url: WebUri(_startUrl)),
                  );
                  setState(() {
                    _showGoogleCloseButton = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final boxWidth = screenSize.width * 0.85;
    final boxHeight = screenSize.height * 0.66;
    return Container(
      color: Colors.white.withOpacity(0.95),
      child: Center(
        child: Container(
          width: boxWidth,
          height: boxHeight,
          padding: EdgeInsets.all(screenSize.width * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: Offset(2, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo_connection_out.png',
                width: screenSize.width * 0.15,
                height: screenSize.width * 0.15,
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.welcome,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
               Text(
                AppLocalizations.of(context)!.loadingMessage,
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startBackgroundGeolocation(int duration) async {
    try {
      final status = await Permission.locationWhenInUse.status;

      if (status.isDenied || status.isPermanentlyDenied) {
        // Request permission
        final newStatus = await Permission.locationWhenInUse.request();
        if (!newStatus.isGranted) {
          debugPrint("Location permission denied. Cannot start tracking.");

          final payload = jsonEncode({
            "errorMessage": "Location permission denied by user"
          });
          await _webViewController.evaluateJavascript(
              source: """
            if (window.webApp && typeof window.webApp.call === 'function') {
              window.webApp.call('message', '$payload');
            }
          """
          );
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final cookieJson = prefs.getString('cookies');
      if (cookieJson == null) {
        debugPrint("No cookies in SharedPreferences—cannot start geolocation.");
        final payload = jsonEncode({
          "errorMessage": "No cookies found. Cannot start geolocation."
        });
        await _webViewController.evaluateJavascript(
            source: """
          if (window.webApp && typeof window.webApp.call === 'function') {
            window.webApp.call('message', '$payload');
          }
        """
        );
        return;
      }

      final List allCookies = jsonDecode(cookieJson);
      final neededCookieNames = {'rememberMe', '__stripe_mid', 'SESSION'};
      final filteredCookies = allCookies
          .where((c) => neededCookieNames.contains(c['name']))
          .toList();
      final cookieHeaderValue =
      filteredCookies.map((c) => '${c['name']}=${c['value']}').join('; ');
      debugPrint("Cookie header: $cookieHeaderValue");

      // Wrap the background-geolocation config in a try-catch
      try {
        bg.BackgroundGeolocation.ready(
          bg.Config(
            url: "$serverUrl/tracking/updateMobileDeviceLocation",
            method: 'POST',
            headers: {
              'Cookie': cookieHeaderValue,
              'Content-Type': 'application/json',
            },
            autoSync: true,
            distanceFilter: 10,
            desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
            stopOnTerminate: false,
            enableHeadless: true,
            debug: true,
            logLevel: bg.Config.LOG_LEVEL_VERBOSE,
            stopAfterElapsedMinutes: duration,
            heartbeatInterval: 180,
            isMoving: true,
            stationaryRadius: 5,
            locationUpdateInterval: 60000,
            backgroundPermissionRationale: bg.PermissionRationale(
              title: "Allow CERES to access your location in the background?",
              message:
              "CERES collects location data only for user-initiated location sharing and tracking.",
              positiveAction: "Change to 'Allow all the time'",
              negativeAction: "Cancel",
            ),
          ),
        ).then((bg.State state) async {
          if (!state.enabled) {
            await bg.BackgroundGeolocation.start();
            debugPrint(
                "BackgroundGeolocation started. Will stop in ~$duration minutes.");
          }
          bg.BackgroundGeolocation.onHttp((bg.HttpEvent event) {
            debugPrint("[HTTP] status: \${event.status}, "
                "success: \${event.success}, response: \${event.responseText}");
          });
        });
      } catch (e) {
        debugPrint("Error initializing background geolocation: \$e");
        final payload = jsonEncode({
          "errorMessage": "Error initializing background geolocation: \$e"
        });
        await _webViewController.evaluateJavascript(
            source: """
          if (window.webApp && typeof window.webApp.call === 'function') {
            window.webApp.call('message', '$payload');
          }
        """
        );
        return;
      }

      _firstLocationSent = false;

      bg.BackgroundGeolocation.onLocation((bg.Location location) async {
        if (!_firstLocationSent) {
          _firstLocationSent = true;
          final lat = location.coords.latitude;
          final lng = location.coords.longitude;

          final payload = jsonEncode({
            "latitude": lat,
            "longitude": lng,
          });

          final jsCall = """
          if (window.webApp && typeof window.webApp.call === 'function') {
            window.webApp.call('startTracking', '$payload');
          }
        """;

          try {
            await _webViewController.evaluateJavascript(source: jsCall);
            debugPrint("✅ Sent location via window.webApp.call()");
          } catch (e) {
            debugPrint("❌ JS call failed: \$e");
          }
        }
      });

      bg.BackgroundGeolocation.onHeartbeat((bg.HeartbeatEvent event) {
        debugPrint("[HEARTBEAT] Sending forced location update.");
        bg.BackgroundGeolocation
            .getCurrentPosition(
          persist: true,
          samples: 1,
          desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        )
            .then((bg.Location location) {
          debugPrint("[HEARTBEAT LOCATION] \${location.coords}");
        });
      });
    } catch (e) {
      debugPrint("Unexpected error in _startBackgroundGeolocation: \$e");
      final payload = jsonEncode({
        "errorMessage": "Unexpected error in _startBackgroundGeolocation: \$e"
      });
      await _webViewController.evaluateJavascript(
          source: """
        if (window.webApp && typeof window.webApp.call === 'function') {
          window.webApp.call('message', '$payload');
        }
      """
      );
    }
  }


  Future<void> _stopBackgroundGeolocation() async {
    bg.BackgroundGeolocation.stop();
    debugPrint("BackgroundGeolocation stopped.");
  }

  //sa creez alt connectionBox , cand internetul e foarte slow , si apare pe perioada cand se incarca pagina, ascult
  // la call'ul lu cristi
  //primu test sa facem doar cu onloadstop
  Widget _buildNoConnectionBox(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final boxWidth = screenSize.width * 0.85;
    final boxHeight = screenSize.height * 0.66;
    return Center(
      child: Container(
        width: boxWidth,
        height: boxHeight,
        padding: EdgeInsets.all(screenSize.width * 0.04),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: Offset(2, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo_connection_out.png',
              width: screenSize.width * 0.15,
              height: screenSize.width * 0.15,
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.welcome,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.noConnectionMessage,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _initConnectivity(); // Retry connectivity
              },
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}

// Secondary WebView for target="_blank" links
class NewTabWebView extends StatefulWidget {
  final int? windowId;
  const NewTabWebView({Key? key, this.windowId}) : super(key: key);

  @override
  _NewTabWebViewState createState() => _NewTabWebViewState();
}

class _NewTabWebViewState extends State<NewTabWebView> {
  late InAppWebViewController _newWebViewController;
  final String chromeUserAgent = "Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UP1A.230905.014) AppleWebKit/605.1.15 (KHTML, like Gecko) Chrome/134.0.0.0 Mobile Safari/604.1";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF2199f9),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: InAppWebView(
        windowId: widget.windowId,
        initialSettings: InAppWebViewSettings(
            //userAgent: chromeUserAgent,
            javaScriptEnabled: true,
            allowsInlineMediaPlayback: true,
            mediaPlaybackRequiresUserGesture: false,
            hardwareAcceleration: false,
            useShouldOverrideUrlLoading: true,
            clearSessionCache: true),
            onWebViewCreated: (controller) {
            _newWebViewController = controller;
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url.toString();

          if (url.toLowerCase().endsWith(".pdf")) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PDFViewer(pdfUrl: url),
              ),
            );
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
