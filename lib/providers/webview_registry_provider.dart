import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/platform_webview.dart';

/// 활성 WebView 컨트롤러 레지스트리
/// key: tabId (일반 탭) | 'split' (분할 패널)
final webviewRegistryProvider =
    StateProvider<Map<String, PlatformWebViewController>>((ref) => const {});
