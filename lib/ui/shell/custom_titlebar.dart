import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/constants.dart';
import '../../providers/sidebar_provider.dart';
import '../../providers/split_view_provider.dart';
import '../modals/settings_modal.dart';

/// 커스텀 타이틀바 (데스크톱 전용)
/// 버튼 배치: [☰ 사이드바] [타이틀] [Spacer] [⫽ 분할] [ㅡ] [□] [⚙️] [X]
class CustomTitleBar extends ConsumerStatefulWidget {
  const CustomTitleBar({super.key});

  @override
  ConsumerState<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends ConsumerState<CustomTitleBar>
    with WindowListener {
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncFullScreenState();
  }

  Future<void> _syncFullScreenState() async {
    final fs = await windowManager.isFullScreen();
    if (mounted) setState(() => _isFullScreen = fs);
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullScreen = false);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sidebarExpanded = ref.watch(sidebarExpandedProvider);
    final splitEnabled = ref.watch(splitViewEnabledProvider);

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: kTitleBarHeight,
        color: const Color(kColorBgSecondary),
        child: Row(
          children: [
            // 햄버거 버튼 — 사이드바 토글 (Ctrl+B와 동일)
            _TitleBarButton(
              icon: sidebarExpanded ? Icons.menu_open : Icons.menu,
              tooltip: sidebarExpanded ? '사이드바 닫기' : '사이드바 열기',
              onTap: () => ref.read(sidebarExpandedProvider.notifier).toggle(),
            ),

            const Spacer(),

            // 분할 버튼 — 좌우 2분할 토글
            _TitleBarButton(
              icon: Icons.vertical_split,
              tooltip: splitEnabled ? '분할 해제' : '좌우 분할',
              isActive: splitEnabled,
              onTap: () {
                if (splitEnabled) {
                  // 분할 해제 시 오른쪽 패널 선택 탭도 리셋
                  ref.read(splitTabIdProvider.notifier).state = null;
                }
                ref.read(splitViewEnabledProvider.notifier).state = !splitEnabled;
              },
            ),

            // 최소화
            _TitleBarButton(
              icon: Icons.remove,
              tooltip: '최소화',
              onTap: () => windowManager.minimize(),
            ),

            // 전체화면 토글
            _TitleBarButton(
              icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              tooltip: _isFullScreen ? '전체화면 해제' : '전체화면',
              onTap: () async {
                await windowManager.setFullScreen(!_isFullScreen);
              },
            ),

            // 환경설정
            _TitleBarButton(
              icon: Icons.settings_outlined,
              tooltip: '환경설정',
              onTap: () => showDialog(
                context: context,
                builder: (_) => const SettingsModal(),
              ),
            ),

            // X — 트레이로 숨김
            _TitleBarButton(
              icon: Icons.close,
              tooltip: '트레이로 최소화',
              isClose: true,
              onTap: () => windowManager.hide(),
            ),

            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  /// true이면 아이콘을 활성 색상(보라)으로 표시
  final bool isActive;

  const _TitleBarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
    this.isActive = false,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: kTitleBarHeight,
            color: _hovered
                ? (widget.isClose
                    ? const Color(kColorDanger)
                    : const Color(kColorBgTertiary))
                : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered && widget.isClose
                  ? Colors.white
                  : widget.isActive
                      ? const Color(kColorAccentLight)
                      : const Color(kColorTextMuted),
            ),
          ),
        ),
      ),
    );
  }
}
