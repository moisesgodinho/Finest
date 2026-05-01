import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  const SettingsState({
    this.notificationsEnabled = true,
    this.hideValues = false,
  });

  final bool notificationsEnabled;
  final bool hideValues;

  SettingsState copyWith({
    bool? notificationsEnabled,
    bool? hideValues,
  }) {
    return SettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      hideValues: hideValues ?? this.hideValues,
    );
  }
}

class SettingsViewModel extends StateNotifier<SettingsState> {
  SettingsViewModel() : super(const SettingsState());

  void toggleNotifications(bool value) {
    state = state.copyWith(notificationsEnabled: value);
  }

  void toggleHideValues(bool value) {
    state = state.copyWith(hideValues: value);
  }
}

final settingsViewModelProvider =
    StateNotifierProvider<SettingsViewModel, SettingsState>((ref) {
  return SettingsViewModel();
});
