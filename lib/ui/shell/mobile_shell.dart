import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import 'sidebar_content.dart';
import '../tabs/webview_tab_manager.dart';

/// 모바일 셸 (화면 폭 ≤ 600px)
/// AppBar + 햄버거 버튼 → Drawer(SidebarContent) + WebViewTabManager
class MobileShell extends ConsumerWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(kColorBgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(kColorBgSecondary),
        elevation: 0,
        title: Text(
          'Custom-Flow',
          style: GoogleFonts.notoSansKr(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(kColorAccentLight),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(kColorTextMuted)),
      ),
      drawer: const Drawer(
        backgroundColor: Color(kColorBgSecondary),
        child: SidebarContent(inDrawer: true),
      ),
      body: const WebViewTabManager(),
    );
  }
}
