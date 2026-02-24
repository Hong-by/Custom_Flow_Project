import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/tab_item.dart';
import '../../providers/active_tab_provider.dart';
import '../../providers/focused_tab_provider.dart';
import '../../providers/split_view_provider.dart';
import '../../providers/tabs_provider.dart';
import '../../providers/webview_registry_provider.dart';

/// 분할 오른쪽 패널
/// - splitTabId == null → 탭 선택 UI
/// - splitTabId != null → 해당 탭의 독립 WebView
class SplitPanelContent extends ConsumerWidget {
  const SplitPanelContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitTabId = ref.watch(splitTabIdProvider);
    final tabsAsync = ref.watch(tabsProvider);

    return Container(
      color: const Color(kColorBgPrimary),
      child: tabsAsync.when(
        data: (tabs) {
          if (splitTabId == null) {
            return _SplitTabSelector(tabs: tabs);
          }
          final tabIndex = tabs.indexWhere((t) => t.id == splitTabId);
          if (tabIndex == -1) {
            // 탭이 삭제된 경우 다음 프레임에 리셋
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(splitTabIdProvider.notifier).state = null;
            });
            return const SizedBox.shrink();
          }
          final tab = tabs[tabIndex];
          return Column(
            children: [
              _SplitTopBar(tab: tab),
              const Divider(height: 1, color: Color(kColorBorder)),
              Expanded(
                // ValueKey로 탭 변경 시 WebView 위젯 재생성
                child: SplitWebViewPanel(key: ValueKey(splitTabId), tab: tab),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(kColorAccentPrimary),
            strokeWidth: 2,
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

// ── 탭 선택 UI ─────────────────────────────────────────────────────────

class _SplitTabSelector extends ConsumerWidget {
  final List<TabItem> tabs;

  const _SplitTabSelector({required this.tabs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(kColorBgSecondary),
          child: Row(
            children: [
              const Icon(
                Icons.vertical_split,
                size: 14,
                color: Color(kColorTextMuted),
              ),
              const SizedBox(width: 8),
              Text(
                '탭을 선택하세요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: const Color(kColorTextPrimary),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(kColorBorder)),

        // 탭 목록
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: tabs.length,
            itemBuilder: (context, index) {
              return _SplitTabCard(tab: tabs[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _SplitTabCard extends ConsumerStatefulWidget {
  final TabItem tab;

  const _SplitTabCard({required this.tab});

  @override
  ConsumerState<_SplitTabCard> createState() => _SplitTabCardState();
}

class _SplitTabCardState extends ConsumerState<_SplitTabCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isExternal = widget.tab.openExternal;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: isExternal ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isExternal
            ? () async {
                final uri = Uri.tryParse(widget.tab.url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            : () {
                ref.read(splitTabIdProvider.notifier).state = widget.tab.id;
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered && !isExternal
                ? const Color(kColorBgTertiary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(kColorBorder),
            ),
          ),
          child: Row(
            children: [
              _FaviconIcon(tab: widget.tab, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.tab.name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: isExternal
                        ? const Color(kColorTextMuted)
                        : const Color(kColorTextPrimary),
                  ),
                ),
              ),
              if (isExternal)
                const Icon(
                  Icons.open_in_new,
                  size: 11,
                  color: Color(kColorTextMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 오른쪽 패널 상단 바 ────────────────────────────────────────────────

class _SplitTopBar extends ConsumerWidget {
  final TabItem tab;

  const _SplitTopBar({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 32,
      color: const Color(kColorBgSecondary),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _FaviconIcon(tab: tab, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tab.name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: const Color(kColorTextPrimary),
              ),
            ),
          ),
          // 닫기 → 탭 선택 화면으로
          _CloseButton(
            onTap: () => ref.read(splitTabIdProvider.notifier).state = null,
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.close,
            size: 13,
            color: _hovered ? Colors.white : const Color(kColorTextMuted),
          ),
        ),
      ),
    );
  }
}

// ── 파비콘 아이콘 헬퍼 ─────────────────────────────────────────────────

class _FaviconIcon extends StatelessWidget {
  final TabItem tab;
  final double size;

  const _FaviconIcon({required this.tab, required this.size});

  @override
  Widget build(BuildContext context) {
    final faviconUrl = getFaviconUrl(tab.url);
    if (faviconUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.network(
          faviconUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(kColorBorder),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Text(
          tab.iconLabel,
          style: TextStyle(
            fontSize: size * 0.6,
            fontWeight: FontWeight.w700,
            color: const Color(kColorTextMuted),
          ),
        ),
      ),
    );
  }
}

// ── 오른쪽 패널 독립 WebView ───────────────────────────────────────────

/// 오른쪽 분할 패널의 독립 WebView
/// ValueKey(splitTabId)로 탭 변경 시 자동 재생성된다.
class SplitWebViewPanel extends ConsumerStatefulWidget {
  final TabItem tab;

  const SplitWebViewPanel({super.key, required this.tab});

  @override
  ConsumerState<SplitWebViewPanel> createState() => _SplitWebViewPanelState();
}

class _SplitWebViewPanelState extends ConsumerState<SplitWebViewPanel> {
  final _controller = WebviewController();
  bool _isLoading = true;
  bool _initialized = false;

  static const _fontInjectionJs = r'''
    (function() {
      var style = document.createElement('style');
      style.innerHTML = "html,body,*{"
        + "font-family:-apple-system,'Noto Sans KR','Malgun Gothic','맑은 고딕',sans-serif!important;"
        + "-webkit-font-smoothing:antialiased;"
        + "letter-spacing:-0.02em;}";
      (document.head || document.body || document.documentElement).appendChild(style);
    })();
  ''';

  static const _ctrlTabScript = r'''
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

      // 레지스트리에 분할 패널 컨트롤러 등록
      if (mounted) {
        ref.read(webviewRegistryProvider.notifier).update(
          (m) => {...m, 'split': _controller},
        );
      }

      try {
        await _controller.addScriptToExecuteOnDocumentCreated(_ctrlTabScript);
      } catch (_) {}

      _controller.webMessage.listen((message) {
        if (!mounted || message is! String) return;
        _handleWebMessage(message);
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
      debugPrint('[SplitWebView] 초기화 오류: $e');
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
  void dispose() {
    ref.read(webviewRegistryProvider.notifier).update(
      (m) => Map<String, WebviewController>.from(m)..remove('split'),
    );
    _controller.dispose();
    super.dispose();
  }

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
