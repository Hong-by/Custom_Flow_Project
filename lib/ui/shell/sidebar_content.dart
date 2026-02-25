import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/tab_item.dart';
import '../../providers/active_tab_provider.dart';
import '../../providers/focused_tab_provider.dart';
import '../../providers/tabs_provider.dart';
import '../widgets/sidebar_tab_item.dart';
import '../modals/add_tab_modal.dart';
import '../modals/settings_modal.dart';

/// 사이드바 콘텐츠
/// expanded=true : 탭 이름 + 아이콘 전체 표시 (기본)
/// expanded=false: 파비콘 아이콘 컬럼만 표시 (접힌 상태)
class SidebarContent extends ConsumerWidget {
  /// 모바일 Drawer 모드에서는 탭 클릭 후 Drawer를 닫는다.
  final bool inDrawer;

  /// false이면 파비콘 아이콘 컬럼만 표시
  final bool expanded;

  const SidebarContent({
    super.key,
    this.inDrawer = false,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsAsync = ref.watch(tabsProvider);
    final activeTabId = ref.watch(activeTabIdProvider);
    final focusedTabIndex = ref.watch(focusedTabIndexProvider);

    // ── 접힌 상태: 파비콘 아이콘 컬럼 ──────────────────────────────
    if (!expanded) {
      return Container(
        color: const Color(kColorBgSecondary),
        child: tabsAsync.when(
          data: (tabs) => ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: tabs.length,
            itemBuilder: (context, index) {
              final tab = tabs[index];
              return _CollapsedTabIcon(
                tab: tab,
                isActive: tab.id == activeTabId,
                onTap: () async {
                  ref.read(focusedTabIndexProvider.notifier).state = null;
                  if (tab.openExternal) {
                    final uri = Uri.tryParse(tab.url);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  } else {
                    ref.read(activeTabIdProvider.notifier).state = tab.id;
                  }
                },
              );
            },
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      );
    }

    // ── 펼친 상태: 전체 사이드바 ───────────────────────────────────
    return Container(
      color: const Color(kColorBgSecondary),
      child: Column(
        children: [
          // ── 상단 헤더 ──────────────────────────────────────────────
          _SidebarHeader(),

          const Divider(
            color: Color(kColorBorder),
            height: 1,
            indent: 12,
            endIndent: 12,
          ),
          const SizedBox(height: 4),

          // ── 탭 목록 ────────────────────────────────────────────────
          Expanded(
            child: tabsAsync.when(
              data: (tabs) => ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: tabs.length,
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  return SidebarTabItem(
                    tab: tab,
                    isActive: tab.id == activeTabId,
                    isFocused: index == focusedTabIndex,
                    onTap: () async {
                      ref.read(focusedTabIndexProvider.notifier).state = null;
                      if (tab.openExternal) {
                        final uri = Uri.tryParse(tab.url);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } else {
                        ref.read(activeTabIdProvider.notifier).state = tab.id;
                      }
                      if (inDrawer && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    onDelete: () => ref.read(tabsProvider.notifier).deleteTab(tab.id),
                  );
                },
              ),
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),
          ),

          // ── 하단 버튼들 ────────────────────────────────────────────
          const Divider(color: Color(kColorBorder), height: 1),
          _BottomActions(),
        ],
      ),
    );
  }
}

// ── 접힌 사이드바: 파비콘 아이콘 아이템 ──────────────────────────────

class _CollapsedTabIcon extends StatefulWidget {
  final TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  const _CollapsedTabIcon({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_CollapsedTabIcon> createState() => _CollapsedTabIconState();
}

class _CollapsedTabIconState extends State<_CollapsedTabIcon> {
  bool _hovered = false;

  Widget _buildIcon() {
    final faviconUrl = getFaviconUrl(widget.tab.url);
    if (faviconUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          faviconUrl,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackIcon(),
        ),
      );
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: widget.isActive
            ? Colors.white.withValues(alpha: 0.2)
            : const Color(kColorBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          widget.tab.iconLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: widget.isActive ? Colors.white : const Color(kColorTextMuted),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tab.name,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? const Color(kColorAccentPrimary)
                  : _hovered
                      ? const Color(kColorBgTertiary)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(child: _buildIcon()),
          ),
        ),
      ),
    );
  }
}

// ── 펼친 사이드바 전용 위젯들 ─────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/app_icon.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Custom-Flow',
              overflow: TextOverflow.clip,
              maxLines: 1,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _ActionButton(
            icon: Icons.add,
            label: '탭 추가',
            onTap: () => showDialog(
              context: context,
              builder: (_) => const AddTabModal(),
            ),
          ),
          const SizedBox(height: 4),
          _ActionButton(
            icon: Icons.settings_outlined,
            label: '환경설정',
            onTap: () => showDialog(
              context: context,
              builder: (_) => const SettingsModal(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _hovered
                  ? const Color(kColorAccentPrimary)
                  : const Color(kColorBorder),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: _hovered
                    ? const Color(kColorAccentLight)
                    : const Color(kColorTextMuted),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: _hovered
                      ? const Color(kColorAccentLight)
                      : const Color(kColorTextMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
