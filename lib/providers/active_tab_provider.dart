import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 현재 활성화된 탭의 ID
/// DesktopShell과 MobileShell이 동일한 Provider를 공유하므로
/// 레이아웃 전환 시에도 탭 선택 상태가 유지된다.
final activeTabIdProvider = StateProvider<String>((ref) => 'record');
