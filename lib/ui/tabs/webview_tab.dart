import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../models/tab_item.dart';
import '../../core/constants.dart';
import '../../providers/active_tab_provider.dart';
import '../../providers/focused_tab_provider.dart';
import '../../providers/tabs_provider.dart';
import '../../providers/webview_registry_provider.dart';

/// 웹뷰 탭 패널 (webview_windows 패키지 — Windows WebView2 사용)
class WebViewTab extends ConsumerStatefulWidget {
  final TabItem tab;

  const WebViewTab({super.key, required this.tab});

  @override
  ConsumerState<WebViewTab> createState() => _WebViewTabState();
}

class _WebViewTabState extends ConsumerState<WebViewTab> {
  final _controller = WebviewController();
  bool _isLoading = true;
  bool _initialized = false;

  /// 한글 폰트 CSS 주입
  static const String _fontInjectionJs = r'''
    (function() {
      var style = document.createElement('style');
      style.innerHTML = "html,body,*{"
        + "font-family:-apple-system,'Noto Sans KR','Malgun Gothic','맑은 고딕',sans-serif!important;"
        + "-webkit-font-smoothing:antialiased;"
        + "letter-spacing:-0.02em;}";
      (document.head || document.body || document.documentElement).appendChild(style);
    })();
  ''';

  /// Ctrl+Tab / Ctrl+Shift+Tab 을 Flutter로 전달하는 JS
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
        await _controller.addScriptToExecuteOnDocumentCreated(_ctrlTabScript);
      } catch (_) {}

      _controller.webMessage.listen((message) {
        if (!mounted) return;
        if (message is String) _handleWebMessage(message);
      });

      _controller.loadingState.listen((state) {
        if (!mounted) return;
        setState(() => _isLoading = state == LoadingState.loading);
        if (state == LoadingState.navigationCompleted) {
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
      (m) => Map<String, WebviewController>.from(m)..remove(tabId),
    );
    _controller.dispose();
    super.dispose();
  }

  /// 커서 위치(x, y)에서 실제 스크롤 가능한 요소를 찾아 스크롤하는 JS
  /// Flutter Listener의 localPosition은 Webview 위젯 기준 좌표 → CSS elementFromPoint와 1:1 매핑
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

    return Stack(
      children: [
        Listener(
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
          child: Webview(_controller),
        ),
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
