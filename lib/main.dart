import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ceres/screens/NewTabWebView.dart';
import 'package:ceres/widgets/LoadingOverlay.dart';
import 'package:ceres/widgets/NoConnectionBox.dart';
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
  bool? _connectionStatus;
  late InAppWebViewController _webViewController;
  String _startUrl = serverUrl;
  bool _isDomainLoaded = false;
  Map<String, dynamic> data = {};
  late final String chromeUserAgent;
  bool _showGoogleCloseButton = false;
  bool _isPageReady = false;
  bool _bgInitDone = false;
  bool _heartbeatAttached = false;
  //poate o sa il folosesc later, daca consum prea mult ram (sau nu se inchide automat listener-ul dupa ce am oprit tracking-ul)
  //late StreamSubscription<bg.HeartbeatEvent> _hbSub;

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

  Future<void> _initBgGeo() async {
    if (_bgInitDone) return;
    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy : bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter  : 10,
      stopTimeout     : 5,
      debug           : false,
      logLevel        : bg.Config.LOG_LEVEL_INFO,
      showsBackgroundLocationIndicator : true,
      disableMotionActivityUpdates     : true,
      stopOnTerminate : false,
      startOnBoot     : true,
      heartbeatInterval: 300,
    ));

    bg.BackgroundGeolocation.onLocation(
            (l) => debugPrint("📍 ${l.coords.latitude},${l.coords.longitude}"));

    if (!_heartbeatAttached) {
      _heartbeatAttached = true;

      bg.BackgroundGeolocation.onHeartbeat((event) async {
        await bg.BackgroundGeolocation.getCurrentPosition(
          persist         : true,
          desiredAccuracy : bg.Config.DESIRED_ACCURACY_HIGH,
          timeout         : 30,
          samples         : 1,
        );
      });
    }
    _bgInitDone = true;
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

    if (!_isPageReady) return;

    if (_webViewController != null) {
      if (state == AppLifecycleState.paused) {
        _webViewController.evaluateJavascript(
            source: "if (window.webApp && typeof window.webApp.call === 'function') { window.webApp.call('enterInBackground',''); }"
        );
      } else if (state == AppLifecycleState.resumed) {
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
    return Scaffold(
      body: _connectionStatus!
          ? Stack(
              children: [
                _buildWebView(),
                if (!_isPageReady) LoadingOverlay(),
              ],
            )
          : NoConnectionBox(onRetry: () { _initConnectivity(); },),
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
                    final duration = args.isNotEmpty ? int.tryParse(args[0].toString()) : null;
                    if (duration != null) {
                      startTracking(duration);
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
                  callback: (args) async {
                    setState(() {
                      _isPageReady = true;
                    });
                    final payload = jsonEncode({});
                    await _initBgGeo();
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
  //modified the logic of startTracking (IOS different than android, from what i read , i need to ask later (second time) to always allow in the
  //background to gather the location
  Future<void> startTracking(int duration) async {
    var perm = await bg.BackgroundGeolocation.requestPermission();

    if (perm == 4) {                       // 4 == WHEN_IN_USE
      perm = await bg.BackgroundGeolocation.requestPermission();
    }

    if (perm != 3) {                       // 3 == AUTHORIZED (Always)
      await _webViewController.evaluateJavascript(
          source:"window.webApp?.call?.('message', "
              "'{\"errorMessage\":\"Location permission denied\"}');");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cookieJson = prefs.getString('cookies');
    if (cookieJson == null) {
      final payload = jsonEncode({
        "errorMessage": "No cookies found. Cannot start tracking."
      });
      await _webViewController.evaluateJavascript(
          source: "window.webApp.call('message', '$payload');"
      );
      return;
    }

    final List allCookies = jsonDecode(cookieJson);
    final neededCookieNames = {'rememberMe', '__stripe_mid', 'SESSION'};
    final filteredCookies = allCookies.where((c) => neededCookieNames.contains(c['name'])).toList();
    final cookieHeaderValue = filteredCookies.map((c) => '${c['name']}=${c['value']}').join('; ');

    await bg.BackgroundGeolocation.setConfig(bg.Config(
      url: "$serverUrl/tracking/updateMobileDeviceLocation",
      method: 'POST',
      headers: {
        'Cookie': cookieHeaderValue,
        'Content-Type': 'application/json',
      },
      stopAfterElapsedMinutes : duration,
      heartbeatInterval       : 300,
      isMoving                : true,
      distanceFilter          : 10,
      stopTimeout             : 5,
      stationaryRadius        : 5,
    ));

    await bg.BackgroundGeolocation.getCurrentPosition(
        persist:false,
        desiredAccuracy:bg.Config.DESIRED_ACCURACY_HIGH
    );

    await bg.BackgroundGeolocation.start();

    final payload = jsonEncode({"duration": duration});
    await _webViewController.evaluateJavascript(
        source: "window.webApp.call('startTracking', '$payload');"
    );

    debugPrint("✅ BackgroundGeolocation started successfully.");
  }

  Future<void> _stopBackgroundGeolocation() async {
    bg.BackgroundGeolocation.stop();
    debugPrint("BackgroundGeolocation stopped.");
  }
}
