import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../platform/platform_webview.dart';
import '../../models/tab_item.dart';
import '../../core/constants.dart';
import '../../providers/active_tab_provider.dart';
import '../../providers/focused_tab_provider.dart';
import '../../providers/tabs_provider.dart';
import '../../providers/webview_registry_provider.dart';

/// 웹뷰 탭 패널 (플랫폼별 WebView 엔진 사용)
/// Windows: WebView2 / macOS: WKWebView
class WebViewTab extends ConsumerStatefulWidget {
  final TabItem tab;

  const WebViewTab({super.key, required this.tab});

  @override
  ConsumerState<WebViewTab> createState() => _WebViewTabState();
}

class _WebViewTabState extends ConsumerState<WebViewTab> {
  final _controller = createPlatformWebView();
  bool _isLoading = true;
  bool _initialized = false;

  /// 한글 폰트 CSS 주입
  /// Material Icons / Material Symbols 등 아이콘 폰트 클래스는 제외
  static const String _fontInjectionJs = r'''
    (function() {
      var style = document.createElement('style');
      style.innerHTML =
        "html,body,*:not([class*='material-icons']):not([class*='material-symbols'])"
        + ":not([class*='icon']):not([class*='Icon']):not([class*='goog-icon'])"
        + ":not(.google-symbols)"
        + "{"
        + "font-family:-apple-system,'Noto Sans KR','Malgun Gothic','맑은 고딕',sans-serif!important;"
        + "-webkit-font-smoothing:antialiased;"
        + "letter-spacing:-0.02em;}";
      (document.head || document.body || document.documentElement).appendChild(style);
    })();
  ''';

  /// Ctrl+Tab / Ctrl+Shift+Tab 을 Flutter로 전달하는 JS
  /// macOS에서는 platform_webview_macos.dart의 postMessage 호환 심이
  /// window.chrome.webview.postMessage를 에뮬레이션한다.
  static const String _ctrlTabScript = r'''
    (function() {
      document.addEventListener('keydown', function(e) {
        if (e.ctrlKey && (e.key === 'Tab' || e.keyCode === 9)) {
          e.preventDefault();
          e.stopPropagation();
          try {
            window.chrome.webview.postMessage(e.shiftKey ? 'ctrl+shift+tab' : 'ctrl+tab');
          } catch(_) {}
        }
      }, true);
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _controller.initialize();

      // 레지스트리에 컨트롤러 등록 (분할 모드 스크롤 핸들링용)
      if (mounted) {
        ref.read(webviewRegistryProvider.notifier).update(
          (m) => {...m, widget.tab.id: _controller},
        );
      }

      try {
        await _controller.addScriptOnDocumentCreated(_ctrlTabScript);
      } catch (_) {}

      _controller.messageStream.listen((message) {
        if (!mounted) return;
        _handleWebMessage(message);
      });

      _controller.loadingStateStream.listen((state) {
        if (!mounted) return;
        setState(() => _isLoading = state == WebViewLoadingState.loading);
        if (state == WebViewLoadingState.completed) {
          _controller.executeScript(_fontInjectionJs).catchError((_) {});
        }
      });

      await _controller.loadUrl(widget.tab.url);

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint('[WebView] 초기화 오류: $e');
      if (mounted) setState(() => _initialized = true);
    }
  }

  void _handleWebMessage(String message) {
    switch (message) {
      case 'ctrl+tab':
        _cycleTabFocus(isShift: false);
      case 'ctrl+shift+tab':
        _cycleTabFocus(isShift: true);
    }
  }

  void _cycleTabFocus({required bool isShift}) {
    final tabs = ref.read(tabsProvider).value;
    if (tabs == null || tabs.isEmpty) return;

    final currentIndex = ref.read(focusedTabIndexProvider);
    if (currentIndex == null) {
      final activeId = ref.read(activeTabIdProvider);
      final idx = tabs.indexWhere((t) => t.id == activeId);
      ref.read(focusedTabIndexProvider.notifier).state = idx >= 0 ? idx : 0;
    } else if (isShift) {
      ref.read(focusedTabIndexProvider.notifier).state =
          (currentIndex - 1 + tabs.length) % tabs.length;
    } else {
      ref.read(focusedTabIndexProvider.notifier).state =
          (currentIndex + 1) % tabs.length;
    }
  }

  @override
  void dispose() {
    final tabId = widget.tab.id;
    ref.read(webviewRegistryProvider.notifier).update(
      (m) => Map<String, PlatformWebViewController>.from(m)..remove(tabId),
    );
    _controller.dispose();
    super.dispose();
  }

  /// 커서 위치(x, y)에서 실제 스크롤 가능한 요소를 찾아 스크롤하는 JS
  /// Windows WebView2 전용 — macOS WKWebView는 네이티브 스크롤 지원
  String _scrollScript(double x, double y, double dx, double dy) => '''
(function() {
  var el = document.elementFromPoint($x, $y);
  while (el && el !== document.documentElement) {
    var st = window.getComputedStyle(el);
    var oy = st.overflowY, ox = st.overflowX;
    if (((oy === 'auto' || oy === 'scroll') && el.scrollHeight > el.clientHeight) ||
        ((ox === 'auto' || ox === 'scroll') && el.scrollWidth > el.clientWidth)) {
      el.scrollBy($dx, $dy);
      return;
    }
    el = el.parentElement;
  }
  window.scrollBy($dx, $dy);
})();
''';

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(kColorAccentPrimary),
          strokeWidth: 2,
        ),
      );
    }

    Widget webview = _controller.buildWidget();

    // Windows: WebView2는 네이티브 스크롤 이벤트를 Flutter로 전달하지 않으므로 JS로 처리
    // macOS: WKWebView가 자체 스크롤 처리하므로 Listener 불필요
    if (_controller.needsManualScrollHandling) {
      webview = Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _controller
                .executeScript(_scrollScript(
                  event.localPosition.dx,
                  event.localPosition.dy,
                  event.scrollDelta.dx,
                  event.scrollDelta.dy,
                ))
                .catchError((_) {});
          }
        },
        child: webview,
      );
    }

    return Stack(
      children: [
        webview,
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: Color(kColorAccentPrimary),
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }
}
