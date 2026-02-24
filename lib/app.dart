import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants.dart';
import 'ui/shell/app_shell.dart';

/// 앱 루트 위젯
/// 한글 표준 가이드 적용:
/// - locale: Locale('ko', 'KR')
/// - GoogleFonts.notoSansKrTextTheme() 전체 적용
/// - 다크 테마 색상 시스템
class CustomFlowApp extends StatelessWidget {
  const CustomFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom-Flow',
      debugShowCheckedModeBanner: false,

      // 한글 로케일 설정 (한글 표준 가이드: Locale('ko', 'KR'))
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // 다크 테마: Noto Sans KR 전체 적용
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(kColorBgPrimary),
        colorScheme: const ColorScheme.dark(
          surface: Color(kColorBgPrimary),
          primary: Color(kColorAccentPrimary),
          secondary: Color(kColorAccentLight),
        ),
        // Noto Sans KR을 앱 전체 텍스트 테마로 설정
        // — 모든 Text 위젯이 자동으로 Noto Sans KR을 사용한다
        textTheme: GoogleFonts.notoSansKrTextTheme(
          ThemeData.dark().textTheme,
        ),
        // 스위치 테마 (환경설정 모달)
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(kColorAccentPrimary);
            }
            return const Color(kColorTextMuted);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(kColorAccentPrimary).withValues(alpha: 0.4);
            }
            return const Color(kColorBorder);
          }),
        ),
      ),

      home: const AppShell(),
    );
  }
}
