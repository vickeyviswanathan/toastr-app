import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:neopop/neopop.dart';
import 'package:provider/provider.dart';
import '../models/comparison_models.dart';
import '../providers/app_state_provider.dart';
import '../services/webview_session_helper.dart';
import '../theme/toastr_theme.dart';

/// Interactive WebView screen that lets you log in to Swiggy, Zomato, Blinkit,
/// Zepto, Instamart, or BigBasket directly on your phone and captures session cookies
/// strictly into local device storage (`SharedPreferences`).
class PlatformLoginWebViewScreen extends StatefulWidget {
  final PlatformInfo platform;

  const PlatformLoginWebViewScreen({
    super.key,
    required this.platform,
  });

  @override
  State<PlatformLoginWebViewScreen> createState() =>
      _PlatformLoginWebViewScreenState();
}

class _PlatformLoginWebViewScreenState
    extends State<PlatformLoginWebViewScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _isSavingSession = false;

  Future<void> _captureAndClose() async {
    setState(() => _isSavingSession = true);
    try {
      final cookieHeader = await WebViewSessionHelper.extractAndSaveCookies(
        platform: widget.platform,
        controller: _controller,
      );
      Map<String, String> localStore = {};
      if (_controller != null) {
        localStore = await WebViewSessionHelper.extractLocalStorage(_controller!);
      }

      if (!mounted) return;
      await context.read<AppStateProvider>().markPlatformSynced(
            platformId: widget.platform.id,
            cookieHeader: cookieHeader,
            localStorageData: localStore,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ToastrTheme.neonGreen,
          content: Text(
            '${widget.platform.name} session captured locally (${cookieHeader.length} bytes). Zero external servers used!',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSavingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link ${widget.platform.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Log in or set your location, then tap Save Session',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: NeoPopButton(
              color: ToastrTheme.primaryYellow,
              onTapUp: _isSavingSession ? null : _captureAndClose,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  _isSavingSession ? 'SAVING...' : 'SAVE SESSION',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              color: widget.platform.brandColor,
              backgroundColor: ToastrTheme.surface,
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.platform.loginUrl),
              ),
              initialSettings: InAppWebViewSettings(
                userAgent: WebViewSessionHelper.mobileUserAgent,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                thirdPartyCookiesEnabled: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onProgressChanged: (_, progress) {
                setState(() => _progress = progress / 100.0);
              },
            ),
          ),
        ],
      ),
    );
  }
}
