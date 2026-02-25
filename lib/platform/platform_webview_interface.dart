import 'package:flutter/material.dart';

/// WebView 로딩 상태
enum WebViewLoadingState { loading, completed }

/// 플랫폼별 WebView 컨트롤러 추상 인터페이스
///
/// Windows: webview_windows (WebView2)
/// macOS:   webview_flutter (WKWebView)
abstract class PlatformWebViewController {
  /// WebView 엔진 초기화
  Future<void> initialize();

  /// URL 로드
  Future<void> loadUrl(String url);

  /// JavaScript 실행
  Future<dynamic> executeScript(String script);

  /// 모든 페이지 로드 시 자동 실행될 스크립트 등록
  Future<void> addScriptOnDocumentCreated(String script);

  /// 로딩 상태 스트림 (loading / completed)
  Stream<WebViewLoadingState> get loadingStateStream;

  /// JavaScript → Dart 메시지 스트림
  Stream<String> get messageStream;

  /// 수동 스크롤 핸들링 필요 여부
  /// Windows WebView2: true (네이티브 스크롤 이벤트가 Flutter로 전달되지 않음)
  /// macOS WKWebView: false (WKWebView가 자체적으로 스크롤 처리)
  bool get needsManualScrollHandling;

  /// WebView 위젯 반환
  Widget buildWidget();

  /// 리소스 해제
  void dispose();
}
