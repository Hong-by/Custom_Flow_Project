import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'desktop_shell.dart';
import 'mobile_shell.dart';

/// 반응형 레이아웃 루트
/// LayoutBuilder로 화면 폭을 감지하여 데스크톱/모바일 셸을 스위칭.
/// 두 셸 모두 동일한 Riverpod Provider를 사용하므로
/// 레이아웃 전환 시 탭 세션/상태가 유지된다.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > kBreakpoint) {
          return const DesktopShell();
        } else {
          return const MobileShell();
        }
      },
    );
  }
}
