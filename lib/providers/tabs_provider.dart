import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tab_item.dart';
import '../services/persistence_service.dart';

class TabsNotifier extends AsyncNotifier<List<TabItem>> {
  final _persistence = PersistenceService();

  @override
  Future<List<TabItem>> build() async {
    return _persistence.loadTabs();
  }

  /// 새 탭 추가
  Future<void> addTab(String name, String url, {bool openExternal = false}) async {
    final current = await future;
    final newTab = TabItem(
      id: 'tab_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      url: url,
      openExternal: openExternal,
    );
    final updated = [...current, newTab];
    state = AsyncData(updated);
    await _persistence.saveTabs(updated);
  }

  /// 탭 삭제
  Future<void> deleteTab(String tabId) async {
    final current = await future;
    final tab = current.where((t) => t.id == tabId).firstOrNull;
    if (tab == null) return;
    final updated = current.where((t) => t.id != tabId).toList();
    state = AsyncData(updated);
    await _persistence.saveTabs(updated);
  }

  /// 탭 이름 변경
  Future<void> renameTab(String tabId, String newName) async {
    final current = await future;
    final updated = current.map((t) {
      return t.id == tabId ? t.copyWith(name: newName) : t;
    }).toList();
    state = AsyncData(updated);
    await _persistence.saveTabs(updated);
  }
}

final tabsProvider =
    AsyncNotifierProvider<TabsNotifier, List<TabItem>>(TabsNotifier.new);
