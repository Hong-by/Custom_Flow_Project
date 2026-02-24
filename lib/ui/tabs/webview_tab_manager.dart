import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../providers/tabs_provider.dart';
import '../../providers/active_tab_provider.dart';
import 'webview_tab.dart';

/// 웹뷰 탭 매니저
/// IndexedStack으로 모든 웹뷰를 메모리에 유지한다.
/// → 탭 전환 시 페이지 리로드 없이 세션이 유지된다 (Electron의 hidden panel 방식과 동일).
class WebViewTabManager extends ConsumerWidget {
  const WebViewTabManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsAsync = ref.watch(tabsProvider);
    final activeTabId = ref.watch(activeTabIdProvider);

    return tabsAsync.when(
      data: (tabs) {
        final webviewTabs = tabs.where((t) => t.isWebview).toList();

        if (webviewTabs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.tab_outlined, size: 48, color: Color(kColorTextMuted)),
                const SizedBox(height: 12),
                Text(
                  '탭이 없습니다',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 16,
                    color: const Color(kColorTextMuted),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '사이드바의 [탭 추가] 버튼으로 URL을 추가하세요',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    color: const Color(kColorTextMuted),
                  ),
                ),
              ],
            ),
          );
        }

        final activeIndex = webviewTabs.indexWhere((t) => t.id == activeTabId);
        final displayIndex = activeIndex >= 0 ? activeIndex : 0;

        // ValueKey(tab.id)로 WebViewTab 위젯을 탭별로 고유하게 식별
        // IndexedStack이 화면에서 숨겨도 WebViewController를 살아있게 유지
        return IndexedStack(
          index: displayIndex,
          children: webviewTabs
              .map((tab) => WebViewTab(key: ValueKey(tab.id), tab: tab))
              .toList(),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(kColorAccentPrimary)),
      ),
      error: (e, _) => Center(
        child: Text(
          '오류가 발생했습니다: $e',
          style: const TextStyle(color: Color(kColorDanger)),
        ),
      ),
    );
  }
}
