import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/constants.dart';
import '../../providers/active_tab_provider.dart';
import '../../providers/focused_tab_provider.dart';
import '../../providers/sidebar_provider.dart';
import '../../providers/split_view_provider.dart';
import '../../providers/tabs_provider.dart';
import 'custom_titlebar.dart';
import 'sidebar_content.dart';
import '../tabs/split_panel_content.dart';
import '../tabs/webview_tab_manager.dart';

/// 데스크톱 셸 (화면 폭 > 600px)
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> with WindowListener {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // ── Tab / Shift+Tab 순환 네비게이션 ──────────────────────────
    if (key == LogicalKeyboardKey.tab) {
      final tabs = ref.read(tabsProvider).value;
      if (tabs == null || tabs.isEmpty) return KeyEventResult.ignored;

      final currentIndex = ref.read(focusedTabIndexProvider);
      final isShift = HardwareKeyboard.instance.isShiftPressed;

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
      return KeyEventResult.handled;
    }

    // ── Enter: 포커스된 탭 활성화 ─────────────────────────────────
    if (key == LogicalKeyboardKey.enter) {
      final focusIdx = ref.read(focusedTabIndexProvider);
      if (focusIdx == null) return KeyEventResult.ignored;

      final tabs = ref.read(tabsProvider).value;
      if (tabs == null || focusIdx >= tabs.length) return KeyEventResult.ignored;

      final tab = tabs[focusIdx];
      if (tab.openExternal) {
        final uri = Uri.tryParse(tab.url);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ref.read(activeTabIdProvider.notifier).state = tab.id;
      }
      ref.read(focusedTabIndexProvider.notifier).state = null;
      return KeyEventResult.handled;
    }

    // ── Escape: 포커스 모드 해제 ──────────────────────────────────
    if (key == LogicalKeyboardKey.escape) {
      if (ref.read(focusedTabIndexProvider) != null) {
        ref.read(focusedTabIndexProvider.notifier).state = null;
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final sidebarExpanded = ref.watch(sidebarExpandedProvider);

    // 사이드바 토글: macOS → Cmd+B, Windows → Ctrl+B
    final sidebarShortcut = Platform.isMacOS
        ? const SingleActivator(LogicalKeyboardKey.keyB, meta: true)
        : const SingleActivator(LogicalKeyboardKey.keyB, control: true);

    return CallbackShortcuts(
      bindings: {
        sidebarShortcut: () {
          ref.read(sidebarExpandedProvider.notifier).toggle();
        },
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: const Color(kColorBgPrimary),
          body: Column(
            children: [
              const CustomTitleBar(),
              Expanded(
                child: Row(
                  children: [
                    // 사이드바
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      width: sidebarExpanded ? kSidebarWidth : kSidebarCollapsedWidth,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(),
                      child: SidebarContent(expanded: sidebarExpanded),
                    ),
                    Container(width: 1, color: const Color(kColorBorder)),

                    // 콘텐츠 영역 — 분할 ON/OFF에 따라 레이아웃 결정
                    const Expanded(child: _SplitContentArea()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 분할 레이아웃을 담당하는 내부 위젯
class _SplitContentArea extends ConsumerWidget {
  const _SplitContentArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitEnabled = ref.watch(splitViewEnabledProvider);

    if (!splitEnabled) {
      return const WebViewTabManager();
    }

    final splitRatio = ref.watch(splitRatioProvider);
    final splitFocused = ref.watch(splitFocusedSideProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final leftWidth = (available - 6) * splitRatio;
        final rightWidth = (available - 6) * (1 - splitRatio);

        return Row(
          children: [
            // 왼쪽 패널 — 마우스 진입 시 포커스 + 상단 accent 라인
            MouseRegion(
              onEnter: (_) =>
                  ref.read(splitFocusedSideProvider.notifier).state = 'left',
              child: SizedBox(
                width: leftWidth,
                child: Stack(
                  children: [
                    const WebViewTabManager(),
                    if (splitFocused == 'left')
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          color: const Color(kColorAccentPrimary),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 드래그 리사이저
            _SplitResizer(totalWidth: available),

            // 오른쪽 패널 — 마우스 진입 시 포커스 + 상단 accent 라인
            MouseRegion(
              onEnter: (_) =>
                  ref.read(splitFocusedSideProvider.notifier).state = 'right',
              child: SizedBox(
                width: rightWidth,
                child: Stack(
                  children: [
                    const SplitPanelContent(),
                    if (splitFocused == 'right')
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          color: const Color(kColorAccentPrimary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 좌우 패널 비율 조절 드래그 핸들
class _SplitResizer extends ConsumerWidget {
  final double totalWidth;

  const _SplitResizer({required this.totalWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final delta = details.delta.dx / totalWidth;
        final current = ref.read(splitRatioProvider);
        ref.read(splitRatioProvider.notifier).state =
            (current + delta).clamp(0.2, 0.8);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: const Color(kColorBgPrimary),
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
