import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'platform_webview_interface.dart';

/// macOS 네이티브 WKWebView 구현체
///
/// Google OAuth 로그인 + 팝업(window.open) 처리를 위해
/// Flutter 플러그인 대신 네이티브 WKWebView를 직접 사용한다.
///
/// 핵심:
/// 1. messageHandler를 등록하지 않음 → Google의 WKWebView 감지 우회
/// 2. WKUIDelegate로 팝업 처리 → Claude/Notion OAuth 지원
/// 3. Chrome User-Agent → 모든 사이트 정상 렌더링
class MacOSWebViewController implements PlatformWebViewController {
  static int _idCounter = 0;
  final String _channelName = 'native_webview_${_idCounter++}';
  late final MethodChannel _channel;

  final _loadingStateController =
      StreamController<WebViewLoadingState>.broadcast();
  final _messageController = StreamController<String>.broadcast();
  final List<String> _documentCreatedScripts = [];
  String? _pendingUrl;
  bool _channelReady = false;

  /// window.chrome.webview.postMessage 호환 심
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
    _channel = MethodChannel(_channelName);
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPageStarted':
        _loadingStateController.add(WebViewLoadingState.loading);
      case 'onPageFinished':
        _loadingStateController.add(WebViewLoadingState.completed);
        // 스크립트 주입
        _invokeJS(_postMessageShim);
        for (final script in _documentCreatedScripts) {
          _invokeJS(script);
        }
      case 'onMessage':
        _messageController.add(call.arguments as String? ?? '');
    }
  }

  void _invokeJS(String script) {
    if (_channelReady) {
      _channel.invokeMethod('evaluateJavaScript', script).catchError((_) {});
    }
  }

  @override
  Future<void> loadUrl(String url) async {
    if (_channelReady) {
      await _channel.invokeMethod('loadUrl', url);
    } else {
      _pendingUrl = url;
    }
  }

  @override
  Future<dynamic> executeScript(String script) async {
    if (_channelReady) {
      return await _channel.invokeMethod('evaluateJavaScript', script);
    }
    return null;
  }

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
  bool get supportsNativeSuspend => false;

  @override
  Future<void> suspend() async {}

  @override
  Future<void> resume() async {}

  @override
  Widget buildWidget() {
    return _NativeWebViewWidget(
      channelName: _channelName,
      pendingUrl: _pendingUrl,
      onReady: () {
        _channelReady = true;
        if (_pendingUrl != null) {
          _channel.invokeMethod('loadUrl', _pendingUrl!).catchError((_) {});
        }
      },
    );
  }

  @override
  void dispose() {
    _loadingStateController.close();
    _messageController.close();
  }
}

class _NativeWebViewWidget extends StatefulWidget {
  final String channelName;
  final String? pendingUrl;
  final VoidCallback onReady;

  const _NativeWebViewWidget({
    required this.channelName,
    required this.pendingUrl,
    required this.onReady,
  });

  @override
  State<_NativeWebViewWidget> createState() => _NativeWebViewWidgetState();
}

class _NativeWebViewWidgetState extends State<_NativeWebViewWidget> {
  bool _created = false;

  @override
  Widget build(BuildContext context) {
    return AppKitView(
      viewType: 'native_webview',
      creationParams: {'channelName': widget.channelName},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (_) {
        if (!_created) {
          _created = true;
          // 네이티브 뷰 생성 완료 → 대기 중인 URL 로드
          Future.delayed(const Duration(milliseconds: 100), widget.onReady);
        }
      },
    );
  }
}
