import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

/// Глобальные настройки как ChangeNotifier — тумблер мм/м должен мгновенно
/// перерисовывать все экраны, где показаны отсчёты.
class AppSettings extends ChangeNotifier {
  String _units = 'mm';
  bool _skipPreflight = false;

  String get units => _units;
  bool get isMillimeters => _units == 'mm';
  bool get skipPreflight => _skipPreflight;

  String get unitLabel => isMillimeters ? 'мм' : 'м';

  Future<void> load() async {
    _units = await SettingsService.loadUnits();
    _skipPreflight = await SettingsService.loadSkipPreflight();
    notifyListeners();
  }

  Future<void> setUnits(String units) async {
    if (_units == units) return;
    _units = units;
    await SettingsService.saveUnits(units);
    notifyListeners();
  }

  Future<void> setSkipPreflight(bool value) async {
    if (_skipPreflight == value) return;
    _skipPreflight = value;
    await SettingsService.saveSkipPreflight(value);
    notifyListeners();
  }
}
