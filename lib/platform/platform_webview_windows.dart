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

  @override
  Future<void> initialize() async {
    await _controller.initialize();

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
  Widget buildWidget() => Webview(_controller);

  @override
  void dispose() {
    _loadingStateController.close();
    _messageController.close();
    _controller.dispose();
  }
}
