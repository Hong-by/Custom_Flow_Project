import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../services/persistence_service.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  final _persistence = PersistenceService();

  @override
  Future<AppSettings> build() async {
    return _persistence.loadSettings();
  }

  Future<void> updateAutoSuspend(bool value) async {
    final current = await future;
    final updated = current.copyWith(autoSuspendTabs: value);
    state = AsyncData(updated);
    await _persistence.saveSettings(updated);
  }

}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
