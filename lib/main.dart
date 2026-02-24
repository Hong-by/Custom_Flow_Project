import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // window_manager 초기화
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 820),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Color(0xFF1E1E1E),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
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
    super.dispose();
  }

  /// X 버튼(또는 Alt+F4): 종료하지 않고 트레이로 숨김
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  /// ICO 파일의 절대 경로를 반환한다.
  ///
  /// - `flutter run` 실행 시: CWD = 프로젝트 루트 → 상대 경로 존재
  /// - EXE 직접 실행 시: CWD = EXE 디렉토리(build/.../Debug/) → 상대 경로 없음
  ///   EXE 위치에서 5단계 위로 올라가면 프로젝트 루트에 도달한다.
  ///   경로: build/windows/x64/runner/Debug/custom_flow.exe
  ///         ↑5  ↑4       ↑3  ↑2     ↑1
  String _trayIconPath() {
    const relPath = 'windows/runner/resources/app_icon.ico';
    // 1) CWD 기준 (flutter run)
    final cwdFile = File(relPath);
    if (cwdFile.existsSync()) return cwdFile.absolute.path;
    // 2) EXE 위치 기준 (EXE 직접 실행)
    // 경로: build/windows/x64/runner/Debug/custom_flow.exe
    //         ↑6  ↑5      ↑4  ↑3    ↑2   ↑1(parent)
    // parent에서 시작해서 6단계 위(프로젝트 루트)까지 탐색
    try {
      var dir = File(Platform.resolvedExecutable).parent;
      for (int i = 0; i < 6; i++) {
        final candidate = File('${dir.path}${Platform.pathSeparator}$relPath');
        if (candidate.existsSync()) return candidate.absolute.path;
        dir = dir.parent;
      }
    } catch (_) {}
    // 3) 최후 fallback (보통 도달하지 않음)
    return File(relPath).absolute.path;
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
          final isVisible = await windowManager.isVisible();
          if (!isVisible) {
            await windowManager.show();
            await windowManager.focus();
          } else {
            await windowManager.hide();
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
