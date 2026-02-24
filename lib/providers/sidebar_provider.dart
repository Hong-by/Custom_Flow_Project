import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSidebarKey = 'sidebar_expanded';

class SidebarNotifier extends StateNotifier<bool> {
  SidebarNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kSidebarKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSidebarKey, state);
  }
}

final sidebarExpandedProvider =
    StateNotifierProvider<SidebarNotifier, bool>((_) => SidebarNotifier());
