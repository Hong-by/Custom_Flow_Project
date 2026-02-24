import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  /// 사용하지 않는 탭 자동 일시 중단
  final bool autoSuspendTabs;

  const AppSettings({
    this.autoSuspendTabs = true,
  });

  AppSettings copyWith({bool? autoSuspendTabs}) {
    return AppSettings(
      autoSuspendTabs: autoSuspendTabs ?? this.autoSuspendTabs,
    );
  }

  Map<String, dynamic> toJson() => {
        'autoSuspendTabs': autoSuspendTabs,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      autoSuspendTabs: json['autoSuspendTabs'] as bool? ?? true,
    );
  }
}
