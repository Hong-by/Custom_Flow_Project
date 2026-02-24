import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 좌우 분할 모드 ON/OFF
final splitViewEnabledProvider = StateProvider<bool>((ref) => false);

/// 오른쪽 패널에 표시할 탭 ID (null = 탭 미선택 상태)
final splitTabIdProvider = StateProvider<String?>((ref) => null);

/// 분할 비율 — 왼쪽 패널의 비율 (0.0 ~ 1.0, 기본 50:50)
/// 분할 해제 후 재활성 시에도 이전 비율을 기억한다.
final splitRatioProvider = StateProvider<double>((ref) => 0.5);

/// 분할 뷰에서 마우스가 올라간 패널 ('left' | 'right' | null)
final splitFocusedSideProvider = StateProvider<String?>((ref) => null);
