import 'package:flutter/foundation.dart';

enum TabType { webview }

@immutable
class TabItem {
  final String id;
  final String name;
  final String url;
  final TabType type;

  /// true이면 탭 클릭 시 앱 내 웹뷰 대신 외부 브라우저로 열린다.
  final bool openExternal;

  const TabItem({
    required this.id,
    required this.name,
    required this.url,
    this.type = TabType.webview,
    this.openExternal = false,
  });

  /// IndexedStack에 포함할지 여부 — 외부 브라우저 탭은 웹뷰 불필요
  bool get isWebview => !openExternal;

  /// 사이드바 아이콘 레이블 (이름 첫 글자 대문자)
  String get iconLabel => name.isNotEmpty ? name[0].toUpperCase() : '?';

  TabItem copyWith({
    String? id,
    String? name,
    String? url,
    TabType? type,
    bool? openExternal,
  }) {
    return TabItem(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      openExternal: openExternal ?? this.openExternal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'type': type.name,
        'openExternal': openExternal,
      };

  factory TabItem.fromJson(Map<String, dynamic> json) {
    TabType resolvedType;
    try {
      resolvedType = TabType.values.byName((json['type'] as String?) ?? 'webview');
    } catch (_) {
      resolvedType = TabType.webview;
    }
    return TabItem(
      id: json['id'] as String,
      name: json['name'] as String,
      url: (json['url'] as String?) ?? '',
      type: resolvedType,
      openExternal: (json['openExternal'] as bool?) ?? false,
    );
  }

  /// 기본 탭 목록
  static List<TabItem> get defaults => const [
        TabItem(id: 'gemini', name: 'Gemini', url: 'https://gemini.google.com'),
        TabItem(id: 'claude', name: 'Claude', url: 'https://claude.ai'),
        TabItem(id: 'notion', name: 'Notion', url: 'https://www.notion.so'),
      ];
}
