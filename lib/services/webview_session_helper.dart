import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comparison_models.dart';

/// 100% On-Device Session Manager & Headless WebView Scraper.
/// Replicates Toastr's `WebViewSessionHelper` & `BackgroundWebViewService`
/// WITHOUT sending your personal cookies/tokens to any external backend server.
class WebViewSessionHelper {
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static final CookieManager _cookieManager = CookieManager.instance();

  /// Extracts cookies for a platform URL from both native CookieManager and `document.cookie`
  /// and persists them strictly in local device storage (`SharedPreferences`).
  static Future<String> extractAndSaveCookies({
    required PlatformInfo platform,
    InAppWebViewController? controller,
  }) async {
    final Map<String, String> mergedCookies = {};

    try {
      final cookies = await _cookieManager.getCookies(url: WebUri(platform.baseUrl));
      for (final c in cookies) {
        if (c.name.isNotEmpty && c.value != null) {
          mergedCookies[c.name] = c.value.toString();
        }
      }
    } catch (e) {
      debugPrint('[WebViewSessionHelper] CookieManager read error for ${platform.id}: $e');
    }

    if (controller != null) {
      try {
        final jsCookieRaw = await controller.evaluateJavascript(source: 'document.cookie');
        if (jsCookieRaw is String && jsCookieRaw.isNotEmpty) {
          for (final part in jsCookieRaw.split(';')) {
            final idx = part.indexOf('=');
            if (idx > 0) {
              final k = part.substring(0, idx).trim();
              final v = part.substring(idx + 1).trim();
              if (k.isNotEmpty) mergedCookies[k] = v;
            }
          }
        }
      } catch (e) {
        debugPrint('[WebViewSessionHelper] document.cookie read error: $e');
      }
    }

    final cookieHeader =
        mergedCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookies_${platform.id}', cookieHeader);
    await prefs.setBool('connected_${platform.id}', cookieHeader.isNotEmpty);
    await prefs.setString(
      'synced_at_${platform.id}',
      DateTime.now().toIso8601String(),
    );

    return cookieHeader;
  }

  /// Extracts `window.localStorage` key/values from an active WebView
  static Future<Map<String, String>> extractLocalStorage(
      InAppWebViewController controller) async {
    final Map<String, String> result = {};
    try {
      final rawJson = await controller.evaluateJavascript(
        source: 'JSON.stringify(window.localStorage)',
      );
      if (rawJson is String && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            result[k.toString()] = v?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('[WebViewSessionHelper] localStorage extraction error: $e');
    }
    return result;
  }

  /// Runs a headless browser fetch inside the target origin (`url`) so Cloudflare / WAF
  /// cookies, TLS fingerprints, and same-origin headers are automatically applied on-device.
  static Future<dynamic> fetchJsonInHeadlessWebView({
    required String originUrl,
    required String targetApiUrl,
    String method = 'GET',
    Map<String, String>? headers,
    String? bodyJson,
    Duration timeout = const Duration(seconds: 18),
  }) async {
    final completer = Completer<dynamic>();
    HeadlessInAppWebView? headlessWebView;

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(originUrl)),
      initialSettings: InAppWebViewSettings(
        userAgent: mobileUserAgent,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        thirdPartyCookiesEnabled: true,
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          final headersJs = jsonEncode(headers ?? {'Accept': 'application/json'});
          final bodyPart =
              bodyJson != null ? ', body: ${jsonEncode(bodyJson)}' : '';
          final jsFetch = '''
            (async function() {
              try {
                const resp = await fetch(${jsonEncode(targetApiUrl)}, {
                  method: ${jsonEncode(method)},
                  headers: $headersJs,
                  credentials: 'include'$bodyPart
                });
                const text = await resp.text();
                return JSON.stringify({ status: resp.status, body: text });
              } catch (err) {
                return JSON.stringify({ status: 0, error: String(err) });
              }
            })();
          ''';

          final result = await controller.evaluateJavascript(source: jsFetch);
          if (result is String) {
            final wrapper = jsonDecode(result);
            if (wrapper is Map && wrapper['body'] is String) {
              try {
                completer.complete(jsonDecode(wrapper['body'] as String));
                return;
              } catch (_) {
                completer.complete(wrapper['body']);
                return;
              }
            }
          }
          completer.complete(null);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );

    try {
      await headlessWebView.run();
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } finally {
      await headlessWebView.dispose();
    }
  }
}
