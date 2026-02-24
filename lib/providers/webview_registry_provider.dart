import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';

/// 활성 WebviewController 레지스트리
/// key: tabId (일반 탭) | 'split' (분할 패널)
final webviewRegistryProvider =
    StateProvider<Map<String, WebviewController>>((ref) => const {});
