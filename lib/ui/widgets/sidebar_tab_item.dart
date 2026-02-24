import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/tab_item.dart';

/// 사이드바 탭 행
/// 호버 효과, 활성 상태 강조, 파비콘 아이콘, 외부 브라우저 표시, 삭제 버튼 포함
/// isFocused: Tab 키 포커스 하이라이트
class SidebarTabItem extends StatefulWidget {
  final TabItem tab;
  final bool isActive;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const SidebarTabItem({
    super.key,
    required this.tab,
    required this.isActive,
    this.isFocused = false,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<SidebarTabItem> createState() => _SidebarTabItemState();
}

class _SidebarTabItemState extends State<SidebarTabItem> {
  bool _hovered = false;

  /// 파비콘 이미지. 로드 실패 시 텍스트 이니셜로 fallback.
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
            color: widget.isActive
                ? Colors.white
                : const Color(kColorTextMuted),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(kColorAccentPrimary)
                : widget.isFocused
                    ? Colors.white.withValues(alpha: 0.08)
                    : _hovered
                        ? const Color(kColorBgTertiary)
                        : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isFocused && !widget.isActive
                ? Border.all(color: Colors.white54, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              // 파비콘 (fallback: 이니셜 텍스트)
              _buildIcon(),
              const SizedBox(width: 8),

              // 탭 이름
              Expanded(
                child: Text(
                  widget.tab.name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: widget.isActive
                        ? Colors.white
                        : const Color(kColorTextPrimary),
                  ),
                ),
              ),

              // 외부 브라우저 탭 아이콘
              if (widget.tab.openExternal)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.open_in_new,
                    size: 11,
                    color: widget.isActive
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(kColorTextMuted),
                  ),
                ),

              // 삭제 버튼 (호버 시 표시)
              if (_hovered && widget.onDelete != null)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Color(kColorTextMuted),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
