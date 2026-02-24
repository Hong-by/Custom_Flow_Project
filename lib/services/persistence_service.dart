import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tab_item.dart';
import '../models/app_settings.dart';

/// SharedPreferences 기반 영속성 서비스
/// Electron의 electron-store를 대체한다.
class PersistenceService {
  static const _tabsKey = 'custom_flow_tabs';
  static const _settingsKey = 'custom_flow_settings';

  Future<List<TabItem>> loadTabs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tabsKey);
    if (raw == null) return TabItem.defaults;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => TabItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return TabItem.defaults;
    }
  }

  Future<void> saveTabs(List<TabItem> tabs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tabsKey, jsonEncode(tabs.map((t) => t.toJson()).toList()));
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
