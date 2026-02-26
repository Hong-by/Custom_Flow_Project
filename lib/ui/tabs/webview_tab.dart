import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../platform/platform_webview.dart';
import '../../models/tab_item.dart';
import '../../core/constants.dart';
import '../../providers/active_tab_provider.dart';
import '../../providers/focused_tab_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tabs_provider.dart';
import '../../providers/webview_registry_provider.dart';

/// 웹뷰 탭 패널 (플랫폼별 WebView 엔진 사용)
/// Windows: WebView2 / macOS: WKWebView
///
/// 성능 최적화:
/// 1. 지연 초기화 — 탭을 처음 선택할 때 WebView 엔진 생성
/// 2. 자동 일시 중단 — 비활성 탭의 WebView를 일정 시간 후 해제
/// 3. 스크롤 쓰로틀링 — Windows WebView2 스크롤 JS 호출을 60fps로 제한
class WebViewTab extends ConsumerStatefulWidget {
  final TabItem tab;

  const WebViewTab({super.key, required this.tab});

  @override
  ConsumerState<WebViewTab> createState() => _WebViewTabState();
}

class _WebViewTabState extends ConsumerState<WebViewTab> {
  PlatformWebViewController? _controller;
  bool _isLoading = true;
  bool _initialized = false;
  bool _everActivated = false;
  ProviderSubscription<String>? _tabSub;

  // 자동 일시 중단: 비활성 5분 후 WebView 해제
  Timer? _suspendTimer;
  static const _suspendDelay = Duration(minutes: 1);
  bool _suspended = false;

  // 스크롤 쓰로틀링 (Windows WebView2 전용)
  Timer? _scrollThrottle;
  double _accDx = 0;
  double _accDy = 0;
  double _lastX = 0;
  double _lastY = 0;

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

    // 활성 탭 변화를 지속적으로 감시하여 지연 초기화 + 자동 일시 중단 처리
    _tabSub = ref.listenManual(activeTabIdProvider, (prev, next) {
      final isNowActive = next == widget.tab.id;
      final wasActive = prev == widget.tab.id;

      if (isNowActive) {
        // 활성화됨: 중단 타이머 취소, 필요 시 재초기화 또는 resume
        _suspendTimer?.cancel();
        if (!_everActivated || _controller == null) {
          _activateAndInit();
        } else if (_suspended) {
          _resumeFromSuspend();
        }
      } else if (wasActive) {
        // 비활성화됨: 자동 일시 중단 예약
        _scheduleSuspend();
      }
    });

    // 현재 활성 탭이면 즉시 초기화
    final activeId = ref.read(activeTabIdProvider);
    if (activeId == widget.tab.id) {
      _activateAndInit();
    }
  }

  /// 탭이 활성화될 때 WebView 엔진을 생성하고 초기화한다.
  void _activateAndInit() {
    _everActivated = true;
    _suspended = false;
    _suspendTimer?.cancel();
    _controller = createPlatformWebView();
    _initWebview();
  }

  /// 비활성 탭의 자동 일시 중단을 예약한다.
  /// 환경설정의 '탭 자동 최적화'가 켜져 있을 때만 동작한다.
  void _scheduleSuspend() {
    _suspendTimer?.cancel();
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null || !settings.autoSuspendTabs) return;
    _suspendTimer = Timer(_suspendDelay, _suspendWebView);
  }

  /// WebView를 일시 중단하여 리소스를 확보한다.
  /// Windows: 네이티브 suspend → 상태·세션 유지, CPU만 절약
  /// macOS:   about:blank 탐색 → 페이지 메모리 해제, WebView·쿠키·세션 유지
  void _suspendWebView() {
    if (!mounted) return;

    // 안전 검사: 현재 활성 탭이면 중단하지 않음
    if (ref.read(activeTabIdProvider) == widget.tab.id) return;

    // 안전 검사: 설정이 여전히 켜져 있는지 확인
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings != null && !settings.autoSuspendTabs) return;

    final controller = _controller;
    if (controller == null) return;

    debugPrint('[WebView] 탭 일시 중단: ${widget.tab.name}');

    if (controller.supportsNativeSuspend) {
      // Windows: 네이티브 suspend (세션·스크롤 유지, CPU만 절약)
      controller.suspend();
    } else {
      // macOS: about:blank로 이동하여 페이지 DOM/JS 메모리 해제
      // WebView 인스턴스를 유지하므로 쿠키·세션·로그인 상태가 보존됨
      controller.loadUrl('about:blank');
    }
    _suspended = true;
  }

  /// 일시 중단된 탭을 복원한다.
  /// Windows: 네이티브 resume (즉시, 상태 완전 유지)
  /// macOS:   원래 URL로 재탐색 (로그인 유지, 페이지 리로드)
  void _resumeFromSuspend() {
    final controller = _controller;
    if (controller == null) return;

    debugPrint('[WebView] 탭 복원: ${widget.tab.name}');

    if (controller.supportsNativeSuspend) {
      // Windows: 즉시 복원 — 스크롤·입력·세션 모두 유지
      controller.resume();
    } else {
      // macOS: 원래 URL로 복귀 — 쿠키가 살아있으므로 로그인 유지
      controller.loadUrl(widget.tab.url);
    }
    _suspended = false;
  }

  Future<void> _initWebview() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.initialize();

      // 레지스트리에 컨트롤러 등록 (분할 모드 스크롤 핸들링용)
      if (mounted) {
        ref.read(webviewRegistryProvider.notifier).update(
          (m) => {...m, widget.tab.id: controller},
        );
      }

      try {
        await controller.addScriptOnDocumentCreated(_ctrlTabScript);
      } catch (_) {}

      controller.messageStream.listen((message) {
        if (!mounted) return;
        _handleWebMessage(message);
      });

      controller.loadingStateStream.listen((state) {
        if (!mounted) return;
        setState(() => _isLoading = state == WebViewLoadingState.loading);
        if (state == WebViewLoadingState.completed) {
          controller.executeScript(_fontInjectionJs).catchError((_) {});
        }
      });

      await controller.loadUrl(widget.tab.url);

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
    _tabSub?.close();
    _suspendTimer?.cancel();
    _scrollThrottle?.cancel();
    final tabId = widget.tab.id;
    final controller = _controller;
    if (controller != null) {
      ref.read(webviewRegistryProvider.notifier).update(
        (m) => Map<String, PlatformWebViewController>.from(m)..remove(tabId),
      );
      controller.dispose();
    }
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(kColorAccentPrimary),
              strokeWidth: 2,
            ),
            if (_suspended) ...[
              const SizedBox(height: 12),
              const Text(
                '일시 중단된 탭을 다시 로드하는 중...',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(kColorTextMuted),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final controller = _controller!;
    Widget webview = controller.buildWidget();

    // Windows: WebView2는 네이티브 스크롤 이벤트를 Flutter로 전달하지 않으므로 JS로 처리
    // macOS: WKWebView가 자체 스크롤 처리하므로 Listener 불필요
    // 쓰로틀링: 스크롤 델타를 누적하고 16ms(≈60fps) 간격으로 JS 실행
    if (controller.needsManualScrollHandling) {
      webview = Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _accDx += event.scrollDelta.dx;
            _accDy += event.scrollDelta.dy;
            _lastX = event.localPosition.dx;
            _lastY = event.localPosition.dy;
            if (_scrollThrottle?.isActive ?? false) return;
            _scrollThrottle = Timer(const Duration(milliseconds: 16), () {
              final dx = _accDx;
              final dy = _accDy;
              _accDx = 0;
              _accDy = 0;
              controller
                  .executeScript(_scrollScript(_lastX, _lastY, dx, dy))
                  .catchError((_) {});
            });
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
