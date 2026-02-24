import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab 키 포커스 인덱스
/// null = 포커스 모드 비활성, int = 현재 포커스된 탭 인덱스
final focusedTabIndexProvider = StateProvider<int?>((ref) => null);
