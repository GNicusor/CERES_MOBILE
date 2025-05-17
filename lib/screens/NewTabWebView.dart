import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// PDF Viewer Screen
import '../PDFViewer.dart';

class NewTabWebView extends StatefulWidget {
  final int? windowId;
  const NewTabWebView({Key? key, this.windowId}) : super(key: key);

  @override
  _NewTabWebViewState createState() => _NewTabWebViewState();
}

class _NewTabWebViewState extends State<NewTabWebView> {
  late InAppWebViewController _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent AppBar with close button
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF2199f9),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: InAppWebView(
        windowId: widget.windowId,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: false,
          clearSessionCache: true,
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url.toString();

          // Intercept PDF links and open in dedicated PDF viewer
          if (url.toLowerCase().endsWith('.pdf')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PDFViewer(pdfUrl: url),
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