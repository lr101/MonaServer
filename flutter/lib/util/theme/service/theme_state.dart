import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_state.g.dart';

@Riverpod(keepAlive: true)
class ThemeState extends _$ThemeState {
  @override
  ThemeMode build() {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    final isThemeLight = sharedPrefs.getBool(GlobalDataRepository.themeKey);
    return getThemeByBool(isThemeLight);
  }

  void setTheme(bool? isLightTheme) {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    if (isLightTheme == null) {
      sharedPrefs.remove(GlobalDataRepository.themeKey);
    } else {
      sharedPrefs.setBool(GlobalDataRepository.themeKey, isLightTheme);
    }
    state = getThemeByBool(isLightTheme);
  }

  ThemeMode getThemeByBool(bool? isLightTheme) {
    if (isLightTheme == null) {
      return ThemeMode.system;
    } else if (isLightTheme) {
      return ThemeMode.light;
    } else {
      return ThemeMode.dark;
    }
  }
}
