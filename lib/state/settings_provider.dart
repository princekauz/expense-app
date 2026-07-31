import 'package:flutter/material.dart';

import '../data/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) {
    _themeIndex = _storage.getThemeIndex();
    _currency = _storage.getCurrency();
  }

  final StorageService _storage;
  int _themeIndex = 0;
  String _currency = 'USD';

  int get themeIndex => _themeIndex;
  String get currency => _currency;

  Future<void> setTheme(int i) async {
    _themeIndex = i;
    await _storage.setThemeIndex(i);
    notifyListeners();
  }

  Future<void> setCurrency(String c) async {
    _currency = c;
    await _storage.setCurrency(c);
    notifyListeners();
  }
}
