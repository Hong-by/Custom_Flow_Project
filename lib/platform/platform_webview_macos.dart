import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'platform_webview_interface.dart';

/// macOS WKWebView 구현체
///
/// Google OAuth 로그인을 허용하기 위해:
/// 1. JavaScript 채널(messageHandler)을 등록하지 않는다
///    → WKWebView 감지 지표인 window.webkit.messageHandlers가 생성되지 않음
/// 2. User-Agent를 Safari로 설정한다
/// 3. JS→Flutter 통신은 커스텀 URL 스킴(cfmsg://)으로 대체한다
class MacOSWebViewController implements PlatformWebViewController {
  late final WebViewController _controller;

  final _loadingStateController =
      StreamController<WebViewLoadingState>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  final List<String> _documentCreatedScripts = [];

  /// Safari 18 User-Agent (macOS Sequoia)
  static const _safariUA =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/18.3 Safari/605.1.15';

  /// window.chrome.webview.postMessage 호환 심
  /// messageHandler 대신 커스텀 URL 스킴으로 메시지를 전달한다.
  static const _postMessageShim = '''
    (function() {
      if (!window.chrome) window.chrome = {};
      if (!window.chrome.webview) {
        window.chrome.webview = {
          postMessage: function(msg) {
            var iframe = document.createElement('iframe');
            iframe.style.display = 'none';
            iframe.src = 'cfmsg://' + encodeURIComponent(String(msg));
            document.body.appendChild(iframe);
            setTimeout(function() { iframe.remove(); }, 100);
          }
        };
      }
    })();
  ''';

  @override
  Future<void> initialize() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_safariUA)
      // ★ addJavaScriptChannel 호출하지 않음 — WKWebView 감지 방지
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          _loadingStateController.add(WebViewLoadingState.loading);
        },
        onPageFinished: (_) {
          _loadingStateController.add(WebViewLoadingState.completed);
          _controller.runJavaScript(_postMessageShim).catchError((_) {});
          for (final script in _documentCreatedScripts) {
            _controller.runJavaScript(script).catchError((_) {});
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          // 커스텀 URL 스킴으로 전달된 JS 메시지를 수신
          if (request.url.startsWith('cfmsg://')) {
            try {
              final msg = Uri.decodeComponent(
                request.url.substring('cfmsg://'.length),
              );
              _messageController.add(msg);
            } catch (_) {}
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
  }

  @override
  Future<void> loadUrl(String url) =>
      _controller.loadRequest(Uri.parse(url));

  @override
  Future<dynamic> executeScript(String script) =>
      _controller.runJavaScript(script);

  @override
  Future<void> addScriptOnDocumentCreated(String script) async {
    _documentCreatedScripts.add(script);
  }

  @override
  Stream<WebViewLoadingState> get loadingStateStream =>
      _loadingStateController.stream;

  @override
  Stream<String> get messageStream => _messageController.stream;

  @override
  bool get needsManualScrollHandling => false;

  @override
  Widget buildWidget() => WebViewWidget(controller: _controller);

  @override
  void dispose() {
    _loadingStateController.close();
    _messageController.close();
  }
}
