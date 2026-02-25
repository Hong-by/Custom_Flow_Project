import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'platform_webview_interface.dart';

/// macOS WKWebView 구현체
class MacOSWebViewController implements PlatformWebViewController {
  late final WebViewController _controller;

  final _loadingStateController =
      StreamController<WebViewLoadingState>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  /// 페이지 로드 시마다 자동 실행할 스크립트 목록
  final List<String> _documentCreatedScripts = [];

  /// window.chrome.webview.postMessage 호환 심
  /// Windows WebView2 API를 에뮬레이션하여 기존 JS 코드가 양쪽 플랫폼에서 동작
  static const _postMessageShim = '''
    (function() {
      if (!window.chrome) window.chrome = {};
      if (!window.chrome.webview) {
        window.chrome.webview = {
          postMessage: function(msg) {
            nativeChannel.postMessage(msg);
          }
        };
      }
    })();
  ''';

  @override
  Future<void> initialize() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/131.0.0.0 Safari/537.36',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          _loadingStateController.add(WebViewLoadingState.loading);
        },
        onPageFinished: (_) {
          _loadingStateController.add(WebViewLoadingState.completed);
          // postMessage 호환 심 주입
          _controller.runJavaScript(_postMessageShim).catchError((_) {});
          // 등록된 사용자 스크립트 실행
          for (final script in _documentCreatedScripts) {
            _controller.runJavaScript(script).catchError((_) {});
          }
        },
      ))
      ..addJavaScriptChannel(
        'nativeChannel',
        onMessageReceived: (message) {
          _messageController.add(message.message);
        },
      );
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
