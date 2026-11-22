import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locale state provider — Bengali is the default primary locale.
final localeProvider = StateProvider<Locale>((ref) => const Locale('bn'));

/// Convenience notifier to toggle between Bengali and English.
extension LocaleToggle on StateController<Locale> {
  void toggleLocale() {
    state = state.languageCode == 'bn' ? const Locale('en') : const Locale('bn');
  }

  bool get isBangla => state.languageCode == 'bn';
}
