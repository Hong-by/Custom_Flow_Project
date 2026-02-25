import 'dart:io';
import 'platform_webview_interface.dart';
import 'platform_webview_windows.dart';
import 'platform_webview_macos.dart';

export 'platform_webview_interface.dart';

/// 현재 플랫폼에 맞는 WebViewController 인스턴스 생성
PlatformWebViewController createPlatformWebView() {
  if (Platform.isWindows) return WindowsWebViewController();
  if (Platform.isMacOS) return MacOSWebViewController();
  throw UnsupportedError('지원하지 않는 플랫폼: ${Platform.operatingSystem}');
}
