import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

ServerSocket? _lockServer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 중복 실행 방지: 고정 포트 바인딩 시도
  try {
    _lockServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 47392);
  } catch (_) {
    // 이미 다른 인스턴스가 실행 중 → 조용히 종료
    exit(0);
  }

  // window_manager 초기화
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    size: const Size(1280, 820),
    minimumSize: const Size(900, 600),
    center: true,
    backgroundColor: const Color(0xFF1E1E1E),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    // macOS: 네이티브 신호등 버튼(닫기/최소화/전체화면) 표시
    // Windows: 커스텀 타이틀바 버튼 사용
    windowButtonVisibility: Platform.isMacOS,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // X 버튼이 앱을 종료하는 대신 onWindowClose 이벤트를 발생시키도록 설정
  await windowManager.setPreventClose(true);

  runApp(const _AppLifecycle());
}

/// 앱 최상위 생명주기 위젯
/// WindowListener를 구현해서 X 버튼 클릭 시 트레이로 숨김 처리한다.
class _AppLifecycle extends StatefulWidget {
  const _AppLifecycle();

  @override
  State<_AppLifecycle> createState() => _AppLifecycleState();
}

class _AppLifecycleState extends State<_AppLifecycle> with WindowListener {
  final SystemTray _systemTray = SystemTray();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initSystemTray();
    _initHotKey();
  }

  @override
  void dispose() {
    hotKeyManager.unregisterAll();
    windowManager.removeListener(this);
    _lockServer?.close();
    super.dispose();
  }

  /// X 버튼(또는 Alt+F4 / Cmd+W): 종료하지 않고 최소화/숨김
  @override
  void onWindowClose() async {
    if (Platform.isMacOS) {
      await windowManager.minimize();
    } else {
      await windowManager.hide();
    }
  }

  /// 트레이 아이콘 파일 경로를 반환한다.
  /// Windows: .ico 파일, macOS: .png 파일
  String _trayIconPath() {
    if (Platform.isMacOS) return _macOSTrayIconPath();
    return _windowsTrayIconPath();
  }

  /// macOS 트레이 아이콘 경로
  /// system_tray macOS 구현은 Flutter rootBundle을 사용하므로 에셋 키를 반환
  String _macOSTrayIconPath() {
    return 'assets/app_icon.png';
  }

  /// Windows 트레이 아이콘 경로 (.ico)
  ///
  /// - `flutter run` 실행 시: CWD = 프로젝트 루트 → 상대 경로 존재
  /// - EXE 직접 실행 시: CWD = EXE 디렉토리(build/.../Debug/) → 상대 경로 없음
  ///   EXE 위치에서 5단계 위로 올라가면 프로젝트 루트에 도달한다.
  ///   경로: build/windows/x64/runner/Debug/custom_flow.exe
  ///         ↑5  ↑4       ↑3  ↑2     ↑1
  String _windowsTrayIconPath() {
    // 1) EXE 옆에 있는 아이콘 (Release/설치 환경)
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      for (final name in ['custom_flow_icon.ico', 'app_icon.ico']) {
        final f = File('${exeDir.path}${Platform.pathSeparator}$name');
        if (f.existsSync()) return f.absolute.path;
      }
    } catch (_) {}
    // 2) CWD 기준 (flutter run)
    const devPath = 'windows/runner/resources/app_icon.ico';
    final cwdFile = File(devPath);
    if (cwdFile.existsSync()) return cwdFile.absolute.path;
    // 3) EXE에서 위로 탐색 (Debug 빌드 폴더 실행)
    try {
      var dir = File(Platform.resolvedExecutable).parent;
      for (int i = 0; i < 6; i++) {
        final candidate = File('${dir.path}${Platform.pathSeparator}$devPath');
        if (candidate.existsSync()) return candidate.absolute.path;
        dir = dir.parent;
      }
    } catch (_) {}
    // 4) fallback
    return File(devPath).absolute.path;
  }

  Future<void> _initHotKey() async {
    try {
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.f1,
        modifiers: [],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) async {
          try {
            if (Platform.isMacOS) {
              // macOS: minimize/restore 토글
              final isMinimized = await windowManager.isMinimized();
              if (isMinimized) {
                await windowManager.restore();
                await windowManager.focus();
              } else {
                await windowManager.minimize();
              }
            } else {
              // Windows: hide/show 토글
              final isVisible = await windowManager.isVisible();
              if (!isVisible) {
                await windowManager.show();
                await windowManager.focus();
              } else {
                await windowManager.hide();
              }
            }
          } catch (e) {
            debugPrint('[HotKey] 핸들러 오류: $e');
          }
        },
      );
    } catch (e) {
      debugPrint('[HotKey] 등록 실패: $e');
    }
  }

  Future<void> _initSystemTray() async {
    try {
      await _systemTray.initSystemTray(
        title: 'Custom-Flow',
        iconPath: _trayIconPath(),
        toolTip: 'Custom-Flow (F1) — 클릭해서 열기',
      );
    } catch (e) {
      debugPrint('[SystemTray] initSystemTray 실패: $e');
      return;
    }

    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: '열기',
        onClicked: (_) async {
          await windowManager.show();
          if (Platform.isMacOS) {
            await windowManager.setAlwaysOnTop(true);
            await windowManager.setAlwaysOnTop(false);
          }
          await windowManager.focus();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '종료',
        onClicked: (_) async {
          await windowManager.destroy();
        },
      ),
    ]);
    await _systemTray.setContextMenu(menu);

    _systemTray.registerSystemTrayEventHandler((eventName) async {
      if (eventName == kSystemTrayEventClick) {
        // 좌클릭: 창 표시
        await windowManager.show();
        if (Platform.isMacOS) {
          await windowManager.setAlwaysOnTop(true);
          await windowManager.setAlwaysOnTop(false);
        }
        await windowManager.focus();
      } else if (eventName == kSystemTrayEventRightClick) {
        // 우클릭: 컨텍스트 메뉴
        await _systemTray.popUpContextMenu();
      }
    });
  } // _initSystemTray

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: CustomFlowApp());
  }
}
