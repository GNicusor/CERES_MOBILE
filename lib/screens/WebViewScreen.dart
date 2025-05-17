import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// Services
import '../services/ConnectivityService.dart';
import '../services/DomainService.dart';
import '../services/GeolocationService.dart';

// Widgets
import '../widgets/LoadingOverlay.dart';
import '../widgets/NoConnectionBox.dart';

class WebViewScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const WebViewScreen({Key? key, required this.onLocaleChanged}) : super(key: key);

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with WidgetsBindingObserver {
  late InAppWebViewController _controller;

  bool _isConnected = false;
  bool _domainLoaded = false;
  bool _pageReady = false;
  String _startUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initialize() async {
    // Load preferred domain and connectivity
    _startUrl = await DomainService.load();
    _isConnected = await ConnectivityService.check();
    setState(() => _domainLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    // Show spinner while loading
    if (!_domainLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: _isConnected
          ? Stack(
        children: [
          _buildWebView(),
          if (!_pageReady) LoadingOverlay(),
        ],
      )
          : NoConnectionBox(onRetry: _retryConnection),
    );
  }

  Future<void> _retryConnection() async {
    final connected = await ConnectivityService.check();
    setState(() => _isConnected = connected);
  }

  Widget _buildWebView() {
    return SafeArea(
      bottom: false,
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_startUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          // ... other settings
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
          _registerJsHandlers();
        },
        onLoadStart: (controller, uri) {
          // handle domain changes
        },
        onLoadStop: (controller, uri) {
          setState(() => _pageReady = true);
          // optionally store cookies or notify JS
        },
      ),
    );
  }

  void _registerJsHandlers() {
    _controller.addJavaScriptHandler(
      handlerName: 'startTracking',
      callback: (args) {
        final duration = int.parse(args[0].toString());
        GeolocationService.startTracking(
          duration: duration,
          onLocation: _sendLocationToWeb,
          onError: _sendErrorToWeb,
        );
      },
    );

    _controller.addJavaScriptHandler(
      handlerName: 'stopTracking',
      callback: (_) => GeolocationService.stopTracking(),
    );

    _controller.addJavaScriptHandler(
      handlerName: 'changeLanguage',
      callback: (args) {
        final code = args[0].toString();
        widget.onLocaleChanged(Locale(code));
      },
    );
  }

  void _sendLocationToWeb(Map<String, dynamic> coords) {
    final payload = jsonEncode(coords);
    _controller.evaluateJavascript(
      source: "window.webApp.call('locationUpdate', '$payload');",
    );
  }

  void _sendErrorToWeb(String message) {
    final payload = jsonEncode({'error': message});
    _controller.evaluateJavascript(
      source: "window.webApp.call('error', '$payload');",
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // forward to web app
  }
}
