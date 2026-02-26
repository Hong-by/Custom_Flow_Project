import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'platform_webview_interface.dart';

/// Windows WebView2 구현체
class WindowsWebViewController implements PlatformWebViewController {
  final WebviewController _controller = WebviewController();

  final _loadingStateController =
      StreamController<WebViewLoadingState>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';

  @override
  Future<void> initialize() async {
    await _controller.initialize();

    // Chrome User-Agent — Google OAuth 등 사이트 호환성 보장
    await _controller.setUserAgent(_userAgent);

    _controller.loadingState.listen((state) {
      if (state == LoadingState.loading) {
        _loadingStateController.add(WebViewLoadingState.loading);
      } else if (state == LoadingState.navigationCompleted) {
        _loadingStateController.add(WebViewLoadingState.completed);
      }
    });

    _controller.webMessage.listen((message) {
      if (message is String) {
        _messageController.add(message);
      }
    });
  }

  @override
  Future<void> loadUrl(String url) => _controller.loadUrl(url);

  @override
  Future<dynamic> executeScript(String script) =>
      _controller.executeScript(script);

  @override
  Future<void> addScriptOnDocumentCreated(String script) =>
      _controller.addScriptToExecuteOnDocumentCreated(script);

  @override
  Stream<WebViewLoadingState> get loadingStateStream =>
      _loadingStateController.stream;

  @override
  Stream<String> get messageStream => _messageController.stream;

  @override
  bool get needsManualScrollHandling => true;

  @override
  bool get supportsNativeSuspend => true;

  @override
  Future<void> suspend() => _controller.suspend();

  @override
  Future<void> resume() => _controller.resume();

  @override
  Widget buildWidget() => Webview(_controller);

  @override
  void dispose() {
    _loadingStateController.close();
    _messageController.close();
    _controller.dispose();
  }
}
